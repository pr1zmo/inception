User: I need you to explain some docker concepts for me: use schemas and simple language but go as low as possible on explaining:
I need the low level of docker? How it works, how it manages images, networks, volumes, how it runs commands how it handles signals, the os abstraction, the lowest of the low, bear in mind That I am a software engenieer. And want to become an expert in docker and be more knowledgable than almost everyone who thinks they know docker.

GitHub Copilot: # Docker Internals: The Deep Dive

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Client                            │
│                    (docker CLI, API calls)                      │
└─────────────────────────┬───────────────────────────────────────┘
                          │ REST API (unix socket /var/run/docker.sock)
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Docker Daemon (dockerd)                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │
│  │   Image     │ │   Network   │ │   Volume    │ │ Container │ │
│  │   Service   │ │   Driver    │ │   Driver    │ │  Runtime  │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘│
└─────────────────────────┬───────────────────────────────────────┘
                          │ gRPC
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                        containerd                               │
│            (container lifecycle, image management)              │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                      containerd-shim                            │
│        (per-container process, survives containerd restart)     │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                          runc                                   │
│              (OCI runtime, spawns the container)                │
└─────────────────────────┬───────────────────────────────────────┘
                          │ clone() syscalls
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Linux Kernel Primitives                      │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌─────────────────┐ │
│  │Namespaces │ │  cgroups  │ │ seccomp   │ │CapabilitiesLSM │ │
│  └───────────┘ └───────────┘ └───────────┘ └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. Linux Kernel Primitives (The Real Foundation)

### Namespaces: Process Isolation

Namespaces create isolated views of system resources. Each container gets its own set.

```
┌────────────────────────────────────────────────────────────────────┐
│                         HOST KERNEL                                │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌─────────────────────┐      ┌─────────────────────┐             │
│  │   Container A       │      │   Container B       │             │
│  │                     │      │                     │             │
│  │ PID NS: 1,2,3...    │      │ PID NS: 1,2,3...    │  ◄── Same   │
│  │ NET NS: eth0,lo     │      │ NET NS: eth0,lo     │      PIDs!  │
│  │ MNT NS: /,/proc...  │      │ MNT NS: /,/proc...  │             │
│  │ UTS NS: hostname    │      │ UTS NS: hostname    │             │
│  │ IPC NS: shm,sem,mq  │      │ IPC NS: shm,sem,mq  │             │
│  │ USER NS: uid/gid    │      │ USER NS: uid/gid    │             │
│  │ CGROUP NS           │      │ CGROUP NS           │             │
│  └─────────────────────┘      └─────────────────────┘             │
│                                                                    │
│  Host sees: Container A PID 1 = Host PID 4523                     │
│             Container B PID 1 = Host PID 4891                     │
└────────────────────────────────────────────────────────────────────┘
```

**The 8 Namespaces:**

| Namespace | Flag | Isolates |
|-----------|------|----------|
| **PID** | `CLONE_NEWPID` | Process IDs - container sees PID 1, host sees real PID |
| **NET** | `CLONE_NEWNET` | Network stack - interfaces, routes, iptables, ports |
| **MNT** | `CLONE_NEWNS` | Mount points - filesystem view |
| **UTS** | `CLONE_NEWUTS` | Hostname and domain name |
| **IPC** | `CLONE_NEWIPC` | System V IPC, POSIX message queues |
| **USER** | `CLONE_NEWUSER` | UID/GID mappings (root in container ≠ root on host) |
| **CGROUP** | `CLONE_NEWCGROUP` | Cgroup root directory view |
| **TIME** | `CLONE_NEWTIME` | Boot and monotonic clocks (Linux 5.6+) |

**How runc creates namespaces:**

```c
// Simplified - what runc does internally
pid_t pid = clone(container_main, stack,
    CLONE_NEWPID | CLONE_NEWNET | CLONE_NEWNS | 
    CLONE_NEWUTS | CLONE_NEWIPC | CLONE_NEWUSER |
    SIGCHLD, args);
```

### Control Groups (cgroups): Resource Limits

```
/sys/fs/cgroup/
├── cpu/
│   └── docker/
│       └── <container-id>/
│           ├── cpu.cfs_period_us    # 100000 (100ms)
│           ├── cpu.cfs_quota_us     # 50000 (50% of 1 CPU)
│           ├── cpu.shares           # relative weight
│           └── tasks                # PIDs in this cgroup
├── memory/
│   └── docker/
│       └── <container-id>/
│           ├── memory.limit_in_bytes
│           ├── memory.soft_limit_in_bytes
│           ├── memory.oom_control
│           └── memory.usage_in_bytes
├── blkio/
│   └── docker/
│       └── <container-id>/
│           ├── blkio.throttle.read_bps_device
│           └── blkio.throttle.write_bps_device
└── pids/
    └── docker/
        └── <container-id>/
            └── pids.max            # max processes
```

**cgroups v1 vs v2:**

```
┌─────────────────────────────────────────────────────────────────┐
│                      cgroups v1 (legacy)                        │
│  Multiple hierarchies - one per controller                      │
│                                                                 │
│  /sys/fs/cgroup/cpu/docker/abc123/                             │
│  /sys/fs/cgroup/memory/docker/abc123/                          │
│  /sys/fs/cgroup/blkio/docker/abc123/                           │
│                 ▲                                               │
│                 │ Different trees!                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      cgroups v2 (unified)                       │
│  Single hierarchy - all controllers in one tree                 │
│                                                                 │
│  /sys/fs/cgroup/docker/abc123/                                 │
│  ├── cpu.max                                                   │
│  ├── memory.max                                                │
│  ├── io.max                                                    │
│  └── pids.max                                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Seccomp: System Call Filtering

```
┌─────────────────────────────────────────────────────────────────┐
│                    Container Process                            │
│                          │                                      │
│                    syscall()                                    │
│                          ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Seccomp BPF Filter                             ││
│  │                                                             ││
│  │  if syscall == clone && flags & CLONE_NEWUSER:             ││
│  │      return EPERM                                           ││
│  │  if syscall in [reboot, kexec_load, mount...]:             ││
│  │      return EPERM                                           ││
│  │  else:                                                      ││
│  │      return ALLOW                                           ││
│  └─────────────────────────────────────────────────────────────┘│
│                          │                                      │
│                          ▼                                      │
│                    Kernel executes or blocks                    │
└─────────────────────────────────────────────────────────────────┘
```

Docker's default seccomp profile blocks ~44 syscalls including:
- `reboot`, `kexec_load` - system control
- `mount`, `umount2` - filesystem manipulation
- `ptrace` - process debugging
- `init_module`, `delete_module` - kernel modules

### Linux Capabilities: Granular Root

```
Full root = ALL 40+ capabilities

Docker default drops dangerous ones:
┌────────────────────────────────────────────────────┐
│  KEPT (14)              │  DROPPED               │
├────────────────────────────────────────────────────┤
│  CAP_CHOWN              │  CAP_SYS_ADMIN ✗       │
│  CAP_DAC_OVERRIDE       │  CAP_NET_ADMIN ✗       │
│  CAP_FOWNER             │  CAP_SYS_PTRACE ✗      │
│  CAP_FSETID             │  CAP_SYS_MODULE ✗      │
│  CAP_KILL               │  CAP_SYS_RAWIO ✗       │
│  CAP_SETGID             │  CAP_SYS_BOOT ✗        │
│  CAP_SETUID             │  CAP_SYS_TIME ✗        │
│  CAP_SETPCAP            │  CAP_MAC_ADMIN ✗       │
│  CAP_NET_BIND_SERVICE   │  CAP_SYSLOG ✗          │
│  CAP_NET_RAW            │  ... many more         │
│  CAP_SYS_CHROOT         │                        │
│  CAP_MKNOD              │                        │
│  CAP_AUDIT_WRITE        │                        │
│  CAP_SETFCAP            │                        │
└────────────────────────────────────────────────────┘
```

---

## 2. Image Storage: The Overlay Filesystem

### Image Layer Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                     Container (Running)                         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │            Container Layer (R/W) - thin                 │   │
│  │   Copy-on-Write: modifications stored here              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │          Image Layer 3 (R/O) - COPY app.py             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │          Image Layer 2 (R/O) - RUN pip install         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │          Image Layer 1 (R/O) - FROM python:3.9         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### OverlayFS: How Union Mounts Work

```
/var/lib/docker/overlay2/
├── l/                          # Shortened symlinks for mount options
│   ├── ABC123 -> ../abc123.../diff
│   └── DEF456 -> ../def456.../diff
│
├── abc123def456.../            # Layer 1 (base)
│   ├── diff/                   # Actual layer contents
│   │   ├── bin/
│   │   ├── etc/
│   │   └── usr/
│   └── link                    # Short ID reference
│
├── 789xyz.../                  # Layer 2
│   ├── diff/                   # Only changes from layer 1
│   │   └── usr/local/lib/python3.9/
│   ├── lower                   # Points to: l/ABC123
│   ├── merged/                 # (only for top layer)
│   └── work/                   # OverlayFS work directory
│
└── container-xyz.../           # Container layer (R/W)
    ├── diff/                   # Container modifications
    ├── lower                   # Points to: l/DEF456:l/ABC123
    ├── merged/                 # FINAL UNIFIED VIEW
    ├── work/
    └── upper -> diff           # Symlink for clarity
```

**The actual mount:**

```bash
mount -t overlay overlay \
  -o lowerdir=/var/lib/docker/overlay2/l/ABC123:/var/lib/docker/overlay2/l/DEF456,\
     upperdir=/var/lib/docker/overlay2/container-xyz/diff,\
     workdir=/var/lib/docker/overlay2/container-xyz/work \
  /var/lib/docker/overlay2/container-xyz/merged
```

### Copy-on-Write Mechanics

```
┌─────────────────────────────────────────────────────────────────┐
│                    Read Operation                               │
│                                                                 │
│   Process reads /etc/passwd                                     │
│           │                                                     │
│           ▼                                                     │
│   Check upperdir (container layer)                              │
│           │                                                     │
│       Not found                                                 │
│           │                                                     │
│           ▼                                                     │
│   Check lowerdir[0] (top image layer)                          │
│           │                                                     │
│       Not found                                                 │
│           │                                                     │
│           ▼                                                     │
│   Check lowerdir[1] (base layer)                               │
│           │                                                     │
│       FOUND! Return file                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Write Operation                              │
│                                                                 │
│   Process writes to /etc/passwd                                 │
│           │                                                     │
│           ▼                                                     │
│   Copy ENTIRE file from lowerdir to upperdir                   │
│   (even for 1-byte change - this is the "copy" in CoW)         │
│           │                                                     │
│           ▼                                                     │
│   Modify the copy in upperdir                                  │
│           │                                                     │
│           ▼                                                     │
│   Future reads see upperdir version                             │
│   Original in lowerdir untouched                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Delete Operation                             │
│                                                                 │
│   Process deletes /etc/passwd                                   │
│           │                                                     │
│           ▼                                                     │
│   Create "whiteout" file in upperdir                           │
│   Character device: mknod upperdir/etc/passwd c 0 0            │
│           │                                                     │
│           ▼                                                     │
│   Overlay hides the lowerdir file                              │
│   File appears deleted in merged view                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Image Content Addressing

```
Image ID = SHA256 of configuration JSON

Layer ID = SHA256 of layer tar content (diffID)
         ≠ SHA256 of compressed blob (digest)

┌─────────────────────────────────────────────────────────────────┐
│  Registry stores:     Compressed blobs with digest             │
│  Docker stores:       Uncompressed layers with diffID          │
│                                                                 │
│  Manifest:                                                      │
│  {                                                              │
│    "config": {                                                  │
│      "digest": "sha256:abc123...",    ◄── Image config         │
│    },                                                           │
│    "layers": [                                                  │
│      {"digest": "sha256:def456..."},  ◄── Compressed blob      │
│      {"digest": "sha256:789xyz..."}                            │
│    ]                                                            │
│  }                                                              │
│                                                                 │
│  Config JSON contains:                                          │
│  {                                                              │
│    "rootfs": {                                                  │
│      "diff_ids": [                                              │
│        "sha256:aaa...",               ◄── Uncompressed SHA256  │
│        "sha256:bbb..."                                          │
│      ]                                                          │
│    }                                                            │
│  }                                                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Networking Internals

### Default Bridge Network

```
┌──────────────────────────────────────────────────────────────────┐
│                           HOST                                   │
│                                                                  │
│  ┌─────────────────┐          ┌─────────────────┐               │
│  │   Container A   │          │   Container B   │               │
│  │                 │          │                 │               │
│  │   eth0          │          │   eth0          │               │
│  │   172.17.0.2    │          │   172.17.0.3    │               │
│  └────────┬────────┘          └────────┬────────┘               │
│           │                            │                         │
│           │ veth pair                  │ veth pair               │
│           │                            │                         │
│    vethXXX│                     vethYYY│                         │
│           │                            │                         │
│           └──────────┬─────────────────┘                         │
│                      │                                           │
│              ┌───────┴───────┐                                   │
│              │   docker0     │  (Linux bridge)                   │
│              │   172.17.0.1  │                                   │
│              └───────┬───────┘                                   │
│                      │                                           │
│              ┌───────┴───────┐                                   │
│              │   iptables    │  NAT + forwarding rules           │
│              │   MASQUERADE  │                                   │
│              └───────┬───────┘                                   │
│                      │                                           │
│              ┌───────┴───────┐                                   │
│              │    eth0       │  (host physical interface)        │
│              │  192.168.1.10 │                                   │
│              └───────────────┘                                   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### veth Pairs: The Plumbing

```
veth = virtual ethernet pair (like a network cable with 2 ends)

┌────────────────────────────────────────────────────────────────┐
│                                                                │
│  Container Network Namespace          Host Network Namespace   │
│  ┌──────────────────────┐            ┌───────────────────────┐│
│  │                      │            │                       ││
│  │   eth0 ◄─────────────────────────► veth123abc            ││
│  │   (inside container)  │  veth pair │  (on docker0 bridge) ││
│  │                      │            │                       ││
│  └──────────────────────┘            └───────────────────────┘│
│                                                                │
│  Created by:                                                   │
│  ip link add veth123abc type veth peer name eth0              │
│  ip link set eth0 netns <container-pid>                       │
│  ip link set veth123abc master docker0                        │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### iptables Rules Docker Creates

```bash
# NAT table - POSTROUTING chain (outbound traffic)
-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE

# Filter table - FORWARD chain
-A FORWARD -i docker0 -o docker0 -j ACCEPT    # inter-container
-A FORWARD -i docker0 ! -o docker0 -j ACCEPT  # outbound
-A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Port publishing (-p 8080:80)
-A DOCKER -p tcp -m tcp --dport 8080 -j DNAT --to-destination 172.17.0.2:80
```

### Network Modes Comparison

```
┌──────────────────────────────────────────────────────────────────┐
│                       --network=bridge (default)                 │
│                                                                  │
│   Container ──► veth ──► docker0 bridge ──► NAT ──► Host NIC    │
│   Own IP, isolated, NAT for outbound                            │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       --network=host                             │
│                                                                  │
│   Container shares host network namespace entirely               │
│   No isolation, no NAT overhead, sees host's eth0               │
│   Port conflicts with host services                              │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       --network=none                             │
│                                                                  │
│   Only loopback interface                                        │
│   Complete network isolation                                     │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       --network=container:X                      │
│                                                                  │
│   Share network namespace with container X                       │
│   Same IP, same ports, like localhost between them              │
│   Used by Kubernetes pods (pause container pattern)              │
└──────────────────────────────────────────────────────────────────┘
```

### User-Defined Bridge: DNS Resolution

```
┌─────────────────────────────────────────────────────────────────┐
│                  User-defined bridge network                    │
│                                                                 │
│   Container A           Container B                             │
│   name: web             name: db                                │
│   ┌─────────────┐       ┌─────────────┐                        │
│   │             │       │             │                        │
│   │ /etc/resolv.conf:   │             │                        │
│   │ nameserver          │             │                        │
│   │ 127.0.0.11 ◄────────────────────────────┐                  │
│   │             │       │             │     │                  │
│   └─────────────┘       └─────────────┘     │                  │
│                                             │                  │
│   ┌─────────────────────────────────────────┴───────────────┐  │
│   │              Docker Embedded DNS Server                 │  │
│   │              (127.0.0.11:53)                           │  │
│   │                                                         │  │
│   │   "web" resolves to 172.18.0.2                         │  │
│   │   "db" resolves to 172.18.0.3                          │  │
│   │                                                         │  │
│   │   Unknown names → forwarded to host's resolv.conf      │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Volume Management

### Volume Types Deep Dive

```
┌─────────────────────────────────────────────────────────────────┐
│                     Named Volumes                               │
│                                                                 │
│   docker volume create mydata                                   │
│                                                                 │
│   /var/lib/docker/volumes/mydata/_data/                        │
│           │                                                     │
│           │ bind mount                                          │
│           ▼                                                     │
│   Container: /app/data                                         │
│                                                                 │
│   • Managed by Docker                                          │
│   • Portable, named reference                                  │
│   • Metadata in /var/lib/docker/volumes/metadata.db            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Bind Mounts                                 │
│                                                                 │
│   docker run -v /host/path:/container/path                     │
│                                                                 │
│   /host/path (any host location)                               │
│           │                                                     │
│           │ bind mount (mount --bind)                          │
│           ▼                                                     │
│   Container: /container/path                                   │
│                                                                 │
│   • Direct host filesystem access                              │
│   • Not managed by Docker                                      │
│   • Host path must exist                                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     tmpfs Mounts                                │
│                                                                 │
│   docker run --tmpfs /app/cache                                │
│                                                                 │
│   RAM (host memory)                                            │
│           │                                                     │
│           │ tmpfs mount                                         │
│           ▼                                                     │
│   Container: /app/cache                                        │
│                                                                 │
│   • In-memory only                                             │
│   • Never written to disk                                      │
│   • Lost on container stop                                     │
│   • Good for secrets, caches                                   │
└─────────────────────────────────────────────────────────────────┘
```

### How Volumes Survive Container Deletion

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   Container Lifecycle              Volume Lifecycle             │
│   ─────────────────────            ─────────────────           │
│                                                                 │
│   create ─────┐                    create ─────┐               │
│               ▼                                ▼               │
│   start ──────┤                    (no state)  │               │
│               │                                │               │
│   running ◄───┤ ◄──── mount ────► exists ◄────┤               │
│               │                                │               │
│   stop ───────┤                                │               │
│               │                                │               │
│   rm ─────────┘                    continues   │               │
│               ▼                    existing    │               │
│          (deleted)                             │               │
│                                                │               │
│   new container ──── mount ────► still exists ─┤               │
│                                                │               │
│                    docker volume rm ──────────►│               │
│                                                ▼               │
│                                           (deleted)            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Container Runtime: Process Lifecycle

### Container Start Sequence

```
docker run nginx
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│ Docker CLI                                                      │
│ POST /containers/create                                         │
│ POST /containers/{id}/start                                     │
└───────────────────────────────┬─────────────────────────────────┘
                                │ REST API
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ dockerd                                                         │
│ 1. Validate image exists (pull if needed)                       │
│ 2. Create container config                                      │
│ 3. Set up networking (veth, IP allocation)                      │
│ 4. Prepare storage (overlay mount)                              │
│ 5. Call containerd via gRPC                                     │
└───────────────────────────────┬─────────────────────────────────┘
                                │ gRPC
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ containerd                                                      │
│ 1. Create container metadata                                    │
│ 2. Prepare rootfs snapshot                                      │
│ 3. Spawn containerd-shim                                        │
└───────────────────────────────┬─────────────────────────────────┘
                                │ exec
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ containerd-shim (per container, long-lived)                     │
│ 1. Holds container stdio                                        │
│ 2. Reports exit status                                          │
│ 3. Allows containerd restart without killing containers         │
│ 4. Calls runc                                                   │
└───────────────────────────────┬─────────────────────────────────┘
                                │ exec
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ runc                                                            │
│ 1. Parse OCI runtime spec (config.json)                         │
│ 2. Set up namespaces (clone())                                  │
│ 3. Configure cgroups                                            │
│ 4. Set up rootfs (pivot_root or chroot)                        │
│ 5. Drop capabilities                                            │
│ 6. Apply seccomp filter                                         │
│ 7. execve() into container entrypoint                           │
│ 8. runc process EXITS (container is now standalone)             │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ Container Process (PID 1 inside namespace)                      │
│ nginx: master process                                           │
│ └── nginx: worker process                                       │
│ └── nginx: worker process                                       │
└─────────────────────────────────────────────────────────────────┘
```

### The OCI Runtime Spec (config.json)

```json
{
  "ociVersion": "1.0.2",
  "process": {
    "terminal": false,
    "user": {"uid": 0, "gid": 0},
    "args": ["nginx", "-g", "daemon off;"],
    "env": ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"],
    "cwd": "/",
    "capabilities": {
      "bounding": ["CAP_CHOWN", "CAP_NET_BIND_SERVICE", "..."],
      "effective": ["CAP_CHOWN", "..."],
      "permitted": ["CAP_CHOWN", "..."]
    },
    "rlimits": [
      {"type": "RLIMIT_NOFILE", "hard": 1024, "soft": 1024}
    ]
  },
  "root": {
    "path": "rootfs",
    "readonly": false
  },
  "hostname": "abc123def",
  "mounts": [
    {"destination": "/proc", "type": "proc", "source": "proc"},
    {"destination": "/dev", "type": "tmpfs", "source": "tmpfs"},
    {"destination": "/sys", "type": "sysfs", "source": "sysfs", "options": ["ro"]}
  ],
  "linux": {
    "namespaces": [
      {"type": "pid"},
      {"type": "network"},
      {"type": "ipc"},
      {"type": "uts"},
      {"type": "mount"}
    ],
    "cgroupsPath": "/docker/abc123def456",
    "resources": {
      "memory": {"limit": 536870912},
      "cpu": {"shares": 1024, "quota": 50000, "period": 100000}
    },
    "seccomp": {
      "defaultAction": "SCMP_ACT_ERRNO",
      "architectures": ["SCMP_ARCH_X86_64"],
      "syscalls": [
        {"names": ["read", "write", "..."], "action": "SCMP_ACT_ALLOW"}
      ]
    }
  }
}
```

---

## 6. Signal Handling & PID 1 Problem

### The PID 1 Problem

```
┌─────────────────────────────────────────────────────────────────┐
│                Normal Linux System                              │
│                                                                 │
│   PID 1: /sbin/init (systemd/sysvinit)                         │
│   │                                                             │
│   ├── Reaps zombie processes (wait() on orphans)               │
│   ├── Forwards signals to children                              │
│   └── Has special signal handling                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                Container (naive)                                │
│                                                                 │
│   PID 1: nginx (or your app)                                   │
│   │                                                             │
│   ├── NOT designed to be PID 1                                 │
│   ├── Doesn't reap zombies → process table fills up            │
│   ├── May ignore SIGTERM (PID 1 special handling)              │
│   └── Child processes orphaned incorrectly                      │
│                                                                 │
│   SIGTERM behavior for PID 1:                                  │
│   • Normal process: default handler = terminate                 │
│   • PID 1: default handler = IGNORE (for init safety)          │
│   • Your app must explicitly handle SIGTERM!                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### docker stop Sequence

```
docker stop <container>
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│   1. Send SIGTERM to PID 1                                      │
│        │                                                        │
│        ▼                                                        │
│   2. Wait for graceful shutdown (default: 10 seconds)          │
│        │                                                        │
│        ├── Process exits? → done                                │
│        │                                                        │
│        └── Timeout expires?                                     │
│                 │                                               │
│                 ▼                                               │
│   3. Send SIGKILL (cannot be caught or ignored)                │
│        │                                                        │
│        ▼                                                        │
│   4. Process forcefully terminated                              │
└─────────────────────────────────────────────────────────────────┘
```

### Solutions for PID 1

```dockerfile
# Solution 1: Use --init flag
docker run --init myapp
# Runs tini as PID 1, your app as PID 2

# Solution 2: Install tini in image
FROM ubuntu
RUN apt-get install tini
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["myapp"]

# Solution 3: Use dumb-init
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Solution 4: exec form ensures shell doesn't wrap
# BAD:
CMD myapp          # Runs as: /bin/sh -c myapp (shell is PID 1!)

# GOOD:
CMD ["myapp"]      # Runs as: myapp (app is PID 1)
```

### Signal Propagation

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   Shell Form: CMD myapp                                         │
│                                                                 │
│   PID 1: /bin/sh -c "myapp"                                    │
│   └── PID 2: myapp                                              │
│                                                                 │
│   SIGTERM sent to PID 1 (shell)                                │
│   Shell exits, myapp becomes orphan                             │
│   myapp doesn't receive SIGTERM!                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   Exec Form: CMD ["myapp"]                                      │
│                                                                 │
│   PID 1: myapp                                                  │
│                                                                 │
│   SIGTERM sent directly to myapp                                │
│   myapp receives signal, can handle gracefully                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   With tini: --init                                             │
│                                                                 │
│   PID 1: tini                                                   │
│   └── PID 2: myapp                                              │
│       └── PID 3: child_process                                  │
│                                                                 │
│   SIGTERM → tini → forwards to myapp                           │
│   Zombie processes reaped by tini                               │
│   Orphaned children adopted by tini                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Container Lifecycle States

```
                                         ┌─────────────┐
                         create          │             │
               ┌─────────────────────────│   created   │
               │                         │             │
               │                         └──────┬──────┘
               │                                │ start
               │                                ▼
               │                         ┌─────────────┐
               │         ┌───────────────│             │◄──────────────┐
               │         │    unpause    │   running   │    restart    │
               │         │               │             │───────────────┘
               │         │               └──────┬──────┘
               │         │                      │
               │    ┌────┴────┐                 │ pause/stop/kill/die
               │    │         │                 │
               │    │ paused  │◄────────────────┤ pause
               │    │         │                 │
               │    └─────────┘                 │
               │                                │ stop/kill
               │                                ▼
               │                         ┌─────────────┐
               │                         │             │
               │                         │   exited    │
               │                         │             │
               │                         └──────┬──────┘
               │                                │ rm
               │                                ▼
               │                         ┌─────────────┐
               └────────────────────────►│             │
                          rm             │  (deleted)  │
                                         │             │
                                         └─────────────┘

State data stored in: /var/lib/docker/containers/<id>/
├── config.v2.json    # Container configuration
├── hostconfig.json   # Host-specific configuration
├── hostname          # Container hostname
├── hosts             # /etc/hosts content
├── resolv.conf       # DNS configuration
├── <id>-json.log     # Container logs (json-file driver)
└── checkpoints/      # Experimental checkpoint data
```

---

## 8. Docker Build Internals

### BuildKit Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       docker build                              │
│                           │                                     │
│                           ▼                                     │
│                    ┌──────────────┐                             │
│                    │   BuildKit   │ (buildkitd daemon)          │
│                    │   Frontend   │                             │
│                    └──────┬───────┘                             │
│                           │                                     │
│            Parse Dockerfile into LLB                            │
│            (Low-Level Build)                                    │
│                           │                                     │
│                           ▼                                     │
│         ┌─────────────────────────────────────┐                │
│         │            LLB DAG                   │                │
│         │    (Directed Acyclic Graph)          │                │
│         │                                      │                │
│         │   ┌─────┐     ┌─────┐               │                │
│         │   │FROM │────►│ RUN │               │                │
│         │   └─────┘     └──┬──┘               │                │
│         │                  │                   │                │
│         │            ┌─────┴─────┐            │                │
│         │            ▼           ▼            │                │
│         │         ┌─────┐     ┌─────┐         │                │
│         │         │COPY │     │ RUN │         │                │
│         │         └──┬──┘     └──┬──┘         │                │
│         │            │           │            │                │
│         │            └─────┬─────┘            │                │
│         │                  ▼                  │                │
│         │              ┌─────┐                │                │
│         │              │FINAL│                │                │
│         │              └─────┘                │                │
│         └─────────────────────────────────────┘                │
│                           │                                     │
│              Parallel execution of                              │
│              independent vertices                               │
│                           │                                     │
│                           ▼                                     │
│                   ┌───────────────┐                            │
│                   │  Cache Check  │                            │
│                   └───────────────┘                            │
│                           │                                     │
│         Cache hit?        │        Cache miss?                  │
│              │            │              │                      │
│              ▼            │              ▼                      │
│         Use cached        │       Execute vertex                │
│           layer           │       (run container)               │
│                           │                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Build Cache Algorithm

```
┌─────────────────────────────────────────────────────────────────┐
│                     Cache Key Computation                       │
│                                                                 │
│   For each instruction:                                         │
│                                                                 │
│   Cache Key = hash(                                             │
│       parent_layer_hash,                                        │
│       instruction_string,                                       │
│       instruction_specific_data                                 │
│   )                                                             │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐ │
│   │ RUN apt-get update                                        │ │
│   │                                                           │ │
│   │ Cache key = hash(parent, "RUN apt-get update")           │ │
│   │ No file context considered!                               │ │
│   │ ⚠️  Will use stale cache even if repos changed           │ │
│   └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐ │
│   │ COPY . /app                                               │ │
│   │                                                           │ │
│   │ Cache key = hash(                                         │ │
│   │     parent,                                               │ │
│   │     "COPY . /app",                                        │ │
│   │     content_hash_of_all_copied_files                      │ │
│   │ )                                                         │ │
│   │ ✓ Cache invalidated when any file changes                │ │
│   └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐ │
│   │ ARG VERSION=1.0                                           │ │
│   │ RUN echo $VERSION                                         │ │
│   │                                                           │ │
│   │ Cache key = hash(parent, "RUN echo $VERSION", "1.0")     │ │
│   │ Different ARG value = different cache key                 │ │
│   └──────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Multi-stage Build Internals

```dockerfile
# Stage 0: builder
FROM golang:1.21 AS builder      # Index 0
WORKDIR /app
COPY . .
RUN go build -o myapp

# Stage 1: runtime
FROM alpine:3.18                  # Index 1
COPY --from=builder /app/myapp /usr/local/bin/
CMD ["myapp"]
```

```
┌─────────────────────────────────────────────────────────────────┐
│                    Multi-stage Internal                         │
│                                                                 │
│   Stage 0 (builder)          Stage 1 (final)                   │
│   ┌─────────────────┐       ┌─────────────────┐                │
│   │ golang:1.21     │       │ alpine:3.18     │                │
│   │ base layer      │       │ base layer      │                │
│   ├─────────────────┤       ├─────────────────┤                │
│   │ WORKDIR /app    │       │                 │                │
│   ├─────────────────┤       │                 │                │
│   │ COPY . .        │       │                 │                │
│   ├─────────────────┤       │                 │                │
│   │ go build        │       │                 │                │
│   │ (800MB image)   │──────►│ COPY myapp      │                │
│   └─────────────────┘       │ (12MB binary)   │                │
│          │                  ├─────────────────┤                │
│          │                  │ (15MB image)    │                │
│          ▼                  └─────────────────┘                │
│   Not included in                   │                          │
│   final image!                      ▼                          │
│   (but cached for                Final output                  │
│   rebuilds)                                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. Security Layers Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                    Defense in Depth                             │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Layer 1: Namespaces                                      │  │
│   │ • Process isolation (can't see host processes)          │  │
│   │ • Network isolation (separate network stack)            │  │
│   │ • Filesystem isolation (can't see host filesystem)      │  │
│   └─────────────────────────────────────────────────────────┘  │
│                              │                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Layer 2: cgroups                                         │  │
│   │ • Resource limits (can't DOS the host)                  │  │
│   │ • Memory limits, CPU limits, PID limits                 │  │
│   └─────────────────────────────────────────────────────────┘  │
│                              │                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Layer 3: Capabilities                                    │  │
│   │ • Dropped dangerous caps (can't load kernel modules)    │  │
│   │ • Minimal privilege set                                 │  │
│   └─────────────────────────────────────────────────────────┘  │
│                              │                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Layer 4: seccomp                                         │  │
│   │ • Syscall filtering (can't call dangerous syscalls)     │  │
│   │ • ~44 syscalls blocked by default                       │  │
│   └─────────────────────────────────────────────────────────┘  │
│                              │                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Layer 5: AppArmor/SELinux                               │  │
│   │ • Mandatory Access Control                              │  │
│   │ • File access restrictions                              │  │
│   └─────────────────────────────────────────────────────────┘  │
│                              │                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Layer 6: Read-only rootfs + tmpfs                       │  │
│   │ • Immutable container filesystem                        │  │
│   │ • Writes only to explicit volumes                       │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10. Key Files & Inspection Commands

```bash
# See what namespaces a container uses
ls -la /proc/<container-pid>/ns/

# View cgroup limits
cat /sys/fs/cgroup/memory/docker/<container-id>/memory.limit_in_bytes

# See overlay mount
cat /proc/mounts | grep overlay

# Inspect container's OCI config
cat /var/lib/docker/containers/<id>/config.v2.json | jq

# View seccomp profile
docker inspect <container> --format '{{.HostConfig.SecurityOpt}}'

# See network namespace
nsenter -t <container-pid> -n ip addr

# View capabilities
cat /proc/<container-pid>/status | grep Cap

# Decode capabilities
capsh --decode=<hex-value>

# See all iptables rules Docker created
iptables -t nat -L -n -v
iptables -L DOCKER -n -v

# Trace syscalls in container
strace -f -p <container-pid>

# View containerd state
ctr -n moby containers list
ctr -n moby tasks list
```

---

This gives you the mental model to understand Docker at the kernel level. Each component has been designed to provide a specific isolation or management capability, and together they create what we perceive as "containers."