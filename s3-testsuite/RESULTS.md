# Third-party S3 suite — SeaweedFS 4.48 results

Suite: [michalszynkiewicz/s3-testsuite](https://github.com/michalszynkiewicz/s3-testsuite)
pinned at `ec150b9` (2026-03-02). Run 2026-10-22 with `just s3-testsuite`.

## How it was run

- **Where**: a test pod **inside** the `seaweedfs-lab` K3d cluster, talking to
  `seaweedfs-s3.seaweedfs.svc:8333` — no `kubectl port-forward` (see P3-07).
- **What**: chart `seaweedfs-4.48.0` with this lab's values — 512Mi S3 memory
  limit, chart defaults otherwise. The S3 gateway is restarted before each suite
  and its cgroup memory sampled every 2s.
- **Reference columns** (`ref-*`) are the suite authors' published results:
  Docker Compose, early 2026 — AWS S3, MinIO `latest`, SeaweedFS **4.13** as a
  single `weed server` process, Garage **v1.0.1**. They are not re-runs.
- Full matrices: [`results/standard/matrix.md`](results/standard/matrix.md),
  [`results/extended/matrix.md`](results/extended/matrix.md). Per-test detail in
  `results/<suite>/seaweedfs-4.48-k8s.md`; raw JUnit XML alongside.

## Scores

| Suite | SeaweedFS 4.48 (ours, K8s) | SeaweedFS 4.13 (ref) | MinIO (ref) | AWS (ref) |
|---|:---:|:---:|:---:|:---:|
| Standard (207) | **183 (88%)** | 174 (84%) | 176 (85%) | 203 (98%) |
| Extended (63) | **62 (98%)** | 62 (98%) | 60 (95%) | 63 (100%) |

| Suite | Duration | Gateway memory peak | Gateway restarts |
|---|---:|---:|---:|
| Standard | 61s | 383Mi | 0 |
| Extended | 51s | 389Mi | 0 |

Every P0 area passes except Bucket CRUD (10/11) and Error Handling (10/12),
both from the bucket-delete default below. Versioning, tagging, ACLs, bucket
policy, **object lock** and lifecycle config all pass in full. All P0 extended
areas — concurrent read/write/delete, overwrite atomicity, listing consistency —
pass, as do 10K-object listing and bulk parallel throughput.

## What changed since 4.13 (per test)

**Fixed (12):** Content-MD5 validation (2 tests — wrong digests are now
rejected, closing the data-integrity gap the suite authors reported), lifecycle
config (6 — rule IDs, tag filters, disabled rules, abort-incomplete-multipart,
delete), CopyObject with `MetadataDirective=REPLACE`, SSE-C CopyObject, and two
"not configured" error responses (website, replication).

**Newly failing (3):** the SSE-S3 tests — caused by configuration, see below.

## Findings

1. **Deleting a non-empty bucket deletes everything in it (default config).**
   `weed s3` defaults to `-allowDeleteBucketNotEmpty=true` and the Helm chart
   does not override it, so `DeleteBucket` on a bucket with objects succeeds and
   removes them all. AWS and MinIO refuse with `409 BucketNotEmpty`. A UDS
   package must set this to `false`. **Verified by hand 2026-11-05:** with
   `s3.extraArgs: ["-allowDeleteBucketNotEmpty=false"]`, 4.48 returns
   `409 BucketNotEmpty` and keeps the objects (4.13 returned a 500).
   (3 tests: bucket CRUD + 2 error-handling.)
2. **SSE-S3 is off unless a key is configured — and then fails with a 500.** On
   4.48 the gateway logs `No KEK configured. SSE-S3 encryption is disabled` at
   startup; an SSE-S3 `PutObject` then returns `500 InternalError`, which clients
   retry, instead of a clear 4xx. Enabling it needs `s3.sse.kek` (or
   `s3.sse.key`) in `security.toml`, or the env vars `WEED_S3_SSE_KEK` /
   `WEED_S3_SSE_KEY` (chart: `s3.extraEnvironmentVars`). SSE-C works. (3 tests.)
   **Verified by hand 2026-11-05:** with `WEED_S3_SSE_KEY` set, SSE-S3 PUT/GET and
   bucket-default encryption work. With a *different* key, existing objects
   return `500 InternalError` (retried); restoring the key recovers them. With
   no key, SSE-S3 PUTs and GETs of existing encrypted objects both return 500.
   The filer stores ciphertext; the wrapped per-object key is in filer metadata.
3. **Unimplemented bucket APIs answer with a misleading error.** Website,
   logging, notifications, replication, inventory and intelligent-tiering
   `Put*` calls return `BucketAlreadyOwnedByYou` (4.13: `BucketAlreadyExists`)
   instead of `NotImplemented`. Harmless for UDS consumers, but confusing when
   debugging. (16 tests.)
4. **`dir` and `dir/` cannot both exist.** Writing key `dir/` after `dir` fails
   with `ExistingObjectIsFile` — the filer is a real file system, so a key can't
   be both a file and a directory. AWS treats them as unrelated keys. Unchanged
   since 4.13. (1 extended test.)
5. **Empty user-metadata values are dropped.** `x-amz-meta-empty: ""` is
   silently removed. Unchanged since 4.13. (1 test.)
6. STS `AssumeRole` is not available (skipped, as for AWS in the reference).

## How this squares with Ceph s3-tests

This suite reports 88%; Ceph s3-tests reports ~51% for the same build. Both are
right — they measure different things:

- This suite checks the **common path** of each feature, often at the level of
  "the API accepts it and reads it back". Its ACL tests, for example, set and
  read ACLs but never check that they are enforced against another user.
- Ceph s3-tests checks **edge semantics and enforcement** across 838 cases
  (conditional writes, CopyObject conditions, ACL grants against other users,
  lifecycle expiry behaviour), written against Ceph RGW.

Where both suites cover a feature they agree: **object lock passes in both**
(8/8 here, 39/39 in Ceph s3-tests) — the ADR previously listed it as a gap,
which was wrong.
