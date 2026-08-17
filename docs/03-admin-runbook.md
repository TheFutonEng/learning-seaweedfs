# SeaweedFS Admin Runbook

Day-2 operations reference for the `weed shell` admin CLI. Task-oriented; every
command marked **[verified]** was run against the `seaweedfs-lab` cluster on
2026-08-17 and its real output is shown. Commands marked **[unverified]** are
documented from `help` output but have not been exercised here — treat them as
leads, not instructions.

The Garage equivalent of this document is `learning-garage/docs/03-admin-runbook.md`.
A side-by-side comparison lives at the end of this file.

---

## 0. Getting a shell — two gotchas first

```sh
just weed-shell     # convenience recipe
```

### Gotcha 1: always pass `-master=<advertised address>`

`weed shell` with no `-master` defaults to `localhost:9333`. It *connects* fine,
but any command that asks components to ping each other reports bogus failures,
because the components don't know the master by that name:

```
checking volume server ...:8080.18080 to master localhost:9333 ...
  rpc error: code = InvalidArgument desc = unknown ping target localhost:9333 of type master
```

Use the advertised address instead:

```sh
M=seaweedfs-master-0.seaweedfs-master.seaweedfs:9333
kubectl -n seaweedfs exec seaweedfs-master-0 -- sh -c \
  "echo 'cluster.check' | weed shell -master=$M"
```

> **Known defect:** the `just weed-shell` recipe currently execs bare
> `weed shell`, so it inherits the localhost default. Pass `-master=` manually
> until the recipe is fixed.

### Gotcha 2: heavy commands need a cluster-wide `lock`

`volume.fsck`, `volume.scrub`, `volume.deleteEmpty`, `volume.balance` and friends
refuse to run unlocked:

```
error: need to run "lock" first to continue
```

The lock is **per shell session**, so a one-shot `echo` won't work — the `lock`,
the command, and the `unlock` must be piped into the *same* invocation:

```sh
kubectl -n seaweedfs exec seaweedfs-master-0 -- sh -c \
  "printf 'lock\nvolume.fsck\nunlock\n' | weed shell -master=$M"
```

Garage has no equivalent concept — this is SeaweedFS-specific ceremony.

---

## 1. Health and topology

### Cluster overview **[verified]**

```
cluster.status
```
```
cluster:
	id:       topo
	status:   unlocked
	nodes:    1
	topology: 1 DC, 1 disk on 1 rack

volumes:
	total:    17 volumes, 2 collections
	regular:  17/293 volumes on 17 replicas, 17 writable (100%), 0 read-only (0%)
	EC:       0 EC volumes on 0 shards (0 shards/volume)
```

### Connectivity + clock skew between every component **[verified]**

```
cluster.check
```
```
checking master ...:9333 to volume server ...:8080.18080 ... ok round trip 0.318ms clock delta 0.034ms
checking volume server ...:8080.18080 to master ...:9333 ... ok round trip 1.053ms clock delta 0.435ms
checking filer 10.42.1.10:8888.18888 to master ...:9333 ... ok round trip 0.918ms clock delta 0.383ms
```

This checks **clock delta** as well as reachability — useful, since S3 SigV4 is
clock-sensitive. Run it first when diagnosing auth or replication weirdness.

### Volume / disk layout tree **[verified]**

```
volume.list
```
```
Topology volumeSizeLimit:1000 MB hdd(volume:17/293 active:17 free:276 remote:0)
  DataCenter DefaultDataCenter
    Rack DefaultRack
      DataNode seaweedfs-volume-0...:8080
        Disk hdd id:0
          volume Id:1, Size:8, ReplicaPlacement:000, Collection:, FileCount:0, ReadOnly:false
```

Read `ReplicaPlacement:000` carefully — **000 means a single copy, no
redundancy**. See §6 for what that implies during an outage.

### Other status commands **[unverified]**

- `cluster.ps` — process status per component
- `cluster.raft.ps` — raft membership (multi-master only)
- `volumeServer.state` — query/update a volume server's state

---

## 2. Identities, keys and IAM

**The single most important fact:** SeaweedFS has **two identity systems that run
simultaneously**, and the admin CLI only sees one of them.

| | Static config | Runtime IAM |
|---|---|---|
| Source | `s3.existingConfigSecret` → `-config=/etc/sw/seaweedfs_s3_config` | filer, under `/etc/iam/identities` |
| Managed by | editing the K8s Secret + Helm redeploy + S3 restart | `weed shell` `s3.user.*` |
| Visible to `s3.user.list` | **no** | yes |
| Needs a restart to take effect | **yes** | **no** |

Both are honoured by the running gateway at the same time. This was verified
directly: with 6 identities in the static secret and `s3.config.show` reporting
`Users: 0`, a user created at runtime authenticated immediately while the static
`seaweedadmin` kept working and a bogus key was still rejected.

**Implication:** the static secret is a *bootstrap*, not a straitjacket. Runtime
tenant provisioning and key rotation are available without a redeploy.

### Inspect current runtime IAM **[verified]**

```
s3.config.show          # summary: Users / Policies / Service Accounts / Groups
s3.user.list            # [] when only static-secret identities exist
fs.ls -l /etc/iam       # the backing store; empty until first runtime user
```

### Provision a bucket-scoped user in one step **[verified]**

```
s3.user.provision -name probeuser -bucket iamprobe -role readwrite
```
```
Created policy "iamprobe-probeuser-readwrite"
Created user "probeuser" with policy "iamprobe-probeuser-readwrite" attached

Access Key: VURWIMXW4GM39XNRPRIQ6
Secret Key: dRgSzlh0ZAvN9b9fosIIAVU6EgPtML6Y0eY6ogZIKB

Save these credentials - the secret key cannot be retrieved later.
```

Roles: `readonly` (GetObject, ListBucket), `readwrite` (+ PutObject,
DeleteObject), `admin` (`s3:*` on that bucket).

Verified behaviour: that user could list and write its own bucket, and got
`AccessDenied` on an unrelated one. **No gateway restart was needed.**

> **The secret is shown once and cannot be retrieved later.** Capture it at
> creation. (Garage differs — see the comparison table.)

### Lower-level user management **[verified]**

```
s3.user.create -name <u> [-access_key <k> -secret_key <s>]   # keys autogenerated if omitted
s3.user.delete -name <u>
s3.policy -delete -name=<policyname>
```

A user with **no policy attached** authenticates but is authorised for nothing —
expect `AccessDenied` on ListObjectsV2 and `403` on HeadObject. That is the
correct, expected split between authn and authz.

### Not yet exercised **[unverified]**

- `s3.accesskey.create` / `.rotate` / `.delete` / `.list` — the rotation path
  (add a new key, migrate clients, retire the old one). **Worth testing before
  relying on it in the package.**
- `s3.iam.export` / `s3.iam.import` — full IAM config as JSON; the obvious
  backup/GitOps hook.
- `s3.group.*`, `s3.user.enable` / `.disable`

---

## 3. Buckets and quotas

### Basic bucket ops **[verified]**

```
s3.bucket.list
s3.bucket.create -name capdrill
s3.bucket.delete -name capdrill
```

### Quotas — read this before relying on them **[verified]**

SeaweedFS quotas are **not enforced inline.** Setting a quota does not stop
writes:

```
s3.bucket.quota -name=capdrill -op=set -sizeMB=1
```

...then writing a 5 MB object into that 1 MB-quota bucket **succeeds completely**,
no error, no truncation.

Enforcement is a **separate sweep**, which defaults to a dry run:

```
s3.bucket.quota.enforce            # simulation
```
```
Running in simulation mode. Use "-apply" option to apply the changes.
  capdrill	size:5243096	quota:1048576	usage:500.02%
    changing bucket capdrill to read only!
```
```
s3.bucket.quota.enforce -apply     # actually flips the bucket read-only
```

After enforcement, writes are rejected — but with the **wrong status code**:

```
An error occurred (InternalError) when calling the PutObject operation
  (reached max retries: 2): We encountered an internal error, please try again.
```

> **Wart:** a quota rejection returns **`InternalError` (HTTP 500)**, so
> well-behaved S3 clients treat it as transient and **retry** (aws-cli retried
> twice above). A quota breach should be a 4xx. The practical consequence is that
> a full tenant generates retry load against an already-stressed gateway.
>
> **Operational takeaway:** run `s3.bucket.quota.enforce -apply` on a schedule
> (it is not automatic), and expect quota breaches to look like 500s to app teams.

`-op=remove` clears the quota. Other ops per help: `set`, `remove`, `enable`,
`disable`.

### Other bucket controls **[unverified]**

`s3.bucket.versioning`, `s3.bucket.lock` (object lock), `s3.bucket.owner`,
`s3.anonymous.set` / `.get` / `.list` (public buckets),
`s3.bucket.lifecycle.fastpath`, `s3.circuitBreaker`.

---

## 4. Capacity

SeaweedFS capacity = **volume count × `volumeSizeLimit`** (1000 MB in this lab).
There is no single "capacity" number to set, and **no staging or dry-run** for
capacity changes — contrast Garage's two-phase layout apply.

### Pre-allocate volumes for a collection **[verified]**

```
volume.grow -collection capdrill -count 3
```

Two non-obvious behaviours, both hit during the drill:

1. **The collection must already exist.** `volume.grow` on a freshly created
   bucket fails with `error: collection not found`. A collection only
   materialises once data has been written to it. Write one object first, then
   grow. (Writing that first object auto-allocated 7 volumes; the explicit grow
   then took it to 10.)
2. **`-collection` is mandatory.** Omitting it gives
   `error: collection option is required`.

Check the result with:

```
collection.list
```
```
collection:""	volumeCount:7	size:9048	fileCount:9	deletedBytes:0	deletion:0
collection:"capdrill"	volumeCount:10	size:144	fileCount:1	deletedBytes:0	deletion:0
```

### Reclaim empty volumes **[verified]**

Grown volumes **outlive the collection they were grown for** — deleting the
bucket left 17 volumes allocated with only the default collection remaining.
Reclaim them:

```
volume.deleteEmpty -quietFor 1s -apply
```
```
deleting empty volume 5 from seaweedfs-volume-0...:8080
```

Took the lab from 17 → 6 volumes. Note:

- `-force` is **deprecated**; use `-apply`. Without `-apply` it is a dry run.
- `-quietFor=24h` is the sensible production default (`1s` was for the drill).
- This can reclaim *pre-existing* empty volumes too, not just the ones you grew.
  Harmless — SeaweedFS re-allocates on demand — but the count may drop below
  where you started.
- Optional `-collectionPattern=important*` to scope it.

### Not yet exercised **[unverified]**

- `volume.vacuum` — compact volumes whose deleted-entry ratio exceeds a limit.
  This, not `deleteEmpty`, is the command that reclaims space **after object
  deletions**. `volume.vacuum.enable` / `.disable` gate the master's automatic
  vacuum requests.
- `volume.balance` — even out volumes across servers (multi-node).
- `volumeServer.evacuate` — drain a node before decommissioning.
- `volume.configure.replication`, `volume.fix.replication` — change/repair
  replica counts.
- `ec.encode` / `ec.balance` / `ec.rebuild` / `ec.scrub` — erasure coding.

---

## 5. Integrity and repair

All of these need the `lock` (see §0) and all are **manual** — SeaweedFS has no
automatic background scrub scheduler. Cron them, or they never run.

### Orphaned chunks: volumes vs filer **[verified]**

```
lock
volume.fsck
unlock
```
```
Total		entries:11	orphan:0	0.00%	0B
no orphan data
```

Compares file IDs in volumes (set A) against the filer (set B) and reports
A − B. `-findMissingChunksInFiler` reverses it to find B − A. Note the default
`-cutoffTimeAgo=5h`: chunks are uploaded before their metadata is committed, so
recent chunks would otherwise look like orphans. **Assumes a single filer.**

> Destructive variants exist (`-reallyDeleteFromVolume`). The bare command is
> report-only — keep it that way unless you have verified the orphan list.

### Verify stored content **[verified]**

```
lock
volume.scrub
unlock
```
```
using FULL mode
Scrubbing seaweedfs-volume-0...:8080 (1/1)...
Scrubbed 11 files and 17 volumes on 1 nodes
```

### Verify filer metadata resolves to real chunks **[verified]**

```
lock
fs.verify -v
unlock
```
```
file: /buckets/capdrill/big.bin needles:1 verified
...
verified 10 files, error 0 files
```

### Browsing stored data **[verified]**

`fs.ls`, `fs.tree`, `fs.cat`, `fs.du`, `fs.meta.cat` let you inspect the filer
namespace directly — useful for confirming where a bucket's objects actually
live. Buckets appear under `/buckets/<name>`.

`fs.meta.save` / `fs.meta.load` **[unverified]** are the metadata backup/restore
path and are worth evaluating for the package.

---

## 6. Failure and recovery

Drill: delete the volume server pod, watch the master's view.

**During the outage** the master reports a *completely empty* topology — not a
degraded one:

```
volumes:
	total:    0 volumes, 0 collections
	regular:  0/0 volumes on 0 replicas, 0 writable (0%), 0 read-only (0%)
```
```
cluster.check
error: no volume available for "" disk type
```

This is the direct consequence of `ReplicaPlacement:000` — a single copy. With
one volume server down there is no second replica to report, so the cluster
doesn't look "degraded", it looks *empty*. **Don't mistake this for data loss.**

**Recovery** was immediate once the pod was Ready — all 17 volumes and both
collections reappeared within ~1s of the heartbeat resuming:

```
Topology volumeSizeLimit:1000 MB hdd(volume:17/293 active:17 free:276 remote:0)
	total:    17 volumes, 2 collections
	regular volumes: 5.3 MB
```

The master and filer are unaffected by a volume-server outage — the admin plane
stays up, which is the practical difference from single-node Garage (where the
CLI lives inside the one node that just died).

Note the pods in this lab show `RESTARTS 1 (8d ago)` from a host reboot; the
master survived that with state intact.

---

## 7. Quick reference

| Task | Command |
|---|---|
| Health summary | `cluster.status` |
| Connectivity + clock skew | `cluster.check` |
| Topology tree | `volume.list` |
| Collections & sizes | `collection.list` |
| List buckets | `s3.bucket.list` |
| Provision scoped user | `s3.user.provision -name U -bucket B -role readwrite` |
| Runtime IAM summary | `s3.config.show` |
| Set quota | `s3.bucket.quota -name=B -op=set -sizeMB=N` |
| Enforce quotas (not automatic) | `s3.bucket.quota.enforce -apply` |
| Pre-allocate volumes | `volume.grow -collection C -count N` |
| Reclaim empty volumes | `lock` → `volume.deleteEmpty -quietFor=24h -apply` → `unlock` |
| Orphan check | `lock` → `volume.fsck` → `unlock` |
| Content scrub | `lock` → `volume.scrub` → `unlock` |
| Metadata verify | `lock` → `fs.verify -v` → `unlock` |

---

## 8. Where Garage differs

Operational contrasts found during the same drills (details in
`learning-garage/docs/03-admin-runbook.md`):

| Axis | SeaweedFS | Garage |
|---|---|---|
| CLI shape | REPL, ~120 namespaced commands | ~15 flat one-shot subcommands |
| Admin ceremony | cluster-wide `lock` for heavy ops | none |
| Capacity change | immediate, no preview | **2-phase**: stage → dry-run plan → `apply --version N` |
| Concurrent-admin safety | the `lock` | stale `--version` refused |
| Quota enforcement | **sweep only**, returns **500** | **inline**, returns proper `403` |
| Quota dimensions | size | size **and** object count |
| Scrub | manual | **automatic + self-scheduling** |
| Secret retrieval | **impossible after creation** | `key info --show-secret` |
| Key rotation | `s3.accesskey.rotate` exists **[unverified]** | **none** — delete & recreate |
| Authz model | policy documents, groups, `s3:*` actions | RW flags per (key, bucket) |
| Admin plane during node loss | survives (master/filer separate) | dies with the single node |

---

## Refs

- Live drills: 2026-08-17, `seaweedfs-lab` k3d cluster.
- IAM coexistence finding and quota/500 wart also recorded in `02-lessons.md`.
- Candidate comparison: `../../adr-replace-minio.md`.
