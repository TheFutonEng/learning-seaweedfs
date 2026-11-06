# Lessons Learned

Running log of findings, surprises, and gotchas. Newest at the top. Keep entries
short; link to test-plan IDs where relevant.

## Template

```
### YYYY-MM-DD — short title
- Context: what we were doing
- Finding: what we learned / what surprised us
- Impact: why it matters (esp. for the UDS package / MinIO replacement goal)
- Refs: test-plan IDs, links
```

---

### 2026-11-05 — Hands-on: the `weed admin` console handles tenants and key rotation; quotas enforce after ~1 min
- Context: Guided exercise 3. Enabled `admin.enabled`, `worker.enabled` and
  `jwtSigning.filerWrite` (password `admin.secret.adminPassword`), then drove
  tenant tasks from the UI on port 23646.
- Finding: a user created in the UI with `Read:test-bucket` is enforced exactly
  by S3. `ListBuckets` shows only that bucket, PUT is `AccessDenied`, and other
  buckets are `AccessDenied`. Console users land in the runtime IAM
  (`s3.configure`, `isStatic: false`).
- Finding: **key rotation works** as add-then-delete. A second key is created
  alongside the first (both valid, an overlap window), and deleting the old key
  revokes it **immediately** (`InvalidAccessKeyId`).
- Finding: **quotas are enforced automatically on 4.48, after a lag** (corrects
  the 4.39 "sweep only" finding). 12 MiB uploaded into a 10 MiB-quota bucket
  succeeded. About a minute later the S3 gateway logged `bucket test-bucket
  quota enforcement: readOnly=true` and set `readOnly: true` for the bucket in
  `filer.conf`; the console then labelled it read-only. The gateway runs this
  every minute (`bucket_size_metrics.go`, one gateway via the `s3.leader` lock),
  flips the bucket back when under quota, and ignores un-vacuumed garbage.
  Overshoot is possible, and the console has no enforce button.
- Finding: an admin write to the read-only bucket returns **`500 InternalError`**
  (aws-cli tried 3 times). The gateway logs `assign volume: read only:
  /buckets/test-bucket/ (e.g. bucket over quota)`. This is the same as 4.39;
  only the sweep became automatic.
- Finding: **it unlocks by itself.** After deleting the 12 MiB object, the next
  sweep logged `readOnly=false (size=316 ...)` and the write succeeded.
- Finding: **vacuum ran by itself.** About 6 minutes after the delete, the worker
  vacuumed the affected volumes (100% garbage → 0%) with nobody triggering it.
  The admin's own maintenance scanner still logs `0 workers` and `MinAge=24h`,
  while the worker uses `MinAge=0s`. Two maintenance systems seem to coexist;
  the worker's is the one that acted.
- Finding: the bucket-create 500 in the admin log didn't surface in the UI (the
  quota was set afterwards, not in the create form). Login is username and
  password only. Cluster/volume views show capacity and free space; the worker
  is listed; there's no obvious way to start a vacuum by hand.
- Finding: bucket creation in the UI logged `500 POST /api/s3/buckets` although
  the bucket exists. The worker gRPC port 33646 accepts unauthenticated workers
  without gRPC mTLS (admin logs a warning). The console takes the cluster
  `lock shell`, so it contends with `weed shell` sessions. It runs vacuum/EC
  detection every 30 min.
- Impact: closes the `s3.accesskey.rotate` open question (via the console). For
  UDS: login is a single built-in password, so SSO needs a fronting proxy;
  port 33646 needs mTLS or a NetworkPolicy.
- Refs: ADR Day-2 operations, `docs/03-admin-runbook.md`

### 2026-11-05 — Hands-on: SSE-S3 works once a key is set; the key is now critical data
- Context: Guided exercise 2. Set `s3.extraEnvironmentVars.WEED_S3_SSE_KEY` (any
  string; HKDF-derived 256-bit KEK) via Helm; `WEED_S3_SSE_KEK` takes a 64-hex key.
- Finding: with the key set, the gateway logs `Derived KEK from s3.sse.key config`.
  `--server-side-encryption AES256` PUTs return `ServerSideEncryption: AES256`,
  `head-object` reports it, and GET returns the plaintext.
  `PutBucketEncryption` (AES256 default) is honoured: an upload with no SSE header
  comes back encrypted.
- Finding: **changing the key makes existing objects unreadable**. GET returns
  `500 InternalError`, which aws-cli retries ("reached max retries: 2") before
  failing. Restoring the original key recovers the object fully. So the key is
  as critical as the data: losing it loses every SSE-S3 object, and the error
  looks transient rather than "wrong key".
- Finding: the same key also signs **STS**. With no key the gateway logs
  `Failed to load IAM configuration: no signing key found for STS service`; with
  one it logs `Using SSE-S3 Master Key (KEK) for STS service`. Rotating the SSE
  key therefore also rotates STS signing.
- Finding: **data really is encrypted at rest.** `fs.cat` on the filer returns
  ciphertext. `fs.meta.cat` shows envelope encryption: each chunk carries
  `sseType: SSE_S3` and a JSON blob (`algorithm`, `encryptedDEK`, `iv`, `nonce`,
  `keyCommitment`, `keyId`). So the per-object data key lives in filer metadata,
  wrapped by the KEK. The plaintext MD5 (ETag) is also stored there, as on AWS.
- Finding: **with no key at all**, an SSE-S3 PUT returns `500 InternalError`
  (aws-cli retries, then fails, ~1s), and GETs of existing encrypted objects
  also 500. The gateway log does say why: `failed to decrypt DEK: SSE-S3
  decryption is not configured`. The client error doesn't.
- Finding: **a routine `just deploy` (values without the key) made every
  encrypted object unreadable.** Dropping the key from Helm values is enough.
- Impact: the UDS package should supply the key from a Secret that is part of
  the package's own values (so redeploys can't drop it), back it up with the
  data, and treat key rotation as a migration, not a config change. Alerting on
  `failed to decrypt DEK` in gateway logs would catch a missing or wrong key
  that clients see only as retried 500s.
- Finding (chart 4.48.0): the standalone S3 gateway can't take env vars from a
  Secret. It has `extraEnvironmentVars` only; `secretExtraEnvironmentVars` exists
  for filer, admin and allInOne. `security.toml` has no SSE fields either, so
  the key ends up in plain Helm values and the Deployment spec.
- Refs: P3-10, `s3-testsuite/RESULTS.md` finding 2

### 2026-11-05 — Hands-on: non-empty bucket delete wipes data by default; the flag fixes it cleanly
- Context: Guided exercise 1 on the 4.48 lab via port-forward and aws-cli. Put
  three objects in `ex1`, then ran a plain `s3api delete-bucket` (no `--force`).
- Finding: with chart defaults the delete **returned exit 0 and removed the
  bucket and all three objects**. Recreating `ex1` gave an empty bucket, and the
  filer (`weed shell` → `fs.ls /buckets`) showed only the new, empty directory.
  Nothing to recover.
- Finding: with `s3.extraArgs: ["-allowDeleteBucketNotEmpty=false"]` the same call
  returns **HTTP 409 `BucketNotEmpty`**, AWS-shaped XML, and the objects remain.
  That settles the 4.13 concern: 4.48 does not answer with a 500.
- Impact: the fix is one values entry with correct S3 semantics. It must be in
  the UDS package defaults, because the unsafe default is invisible: nothing
  in the response or logs says data was deleted.
- Refs: P3-10, `s3-testsuite/RESULTS.md` finding 1

### 2026-10-22 — Second-opinion suite: 88% on the common path; two risky chart defaults
- Context: Ran the third-party [s3-testsuite](https://github.com/michalszynkiewicz/s3-testsuite)
  (standard 207 + extended 63 tests) in-cluster via `just s3-testsuite`, and
  compared against its authors' published AWS / MinIO / SeaweedFS-4.13 runs.
- Finding: **standard 183/207 (88%), extended 62/63** — ahead of the MinIO
  reference (176 / 60). 12 tests fixed since 4.13, including **Content-MD5
  validation** (wrong digests used to be accepted). All P0 areas and all
  concurrency/atomicity/listing-consistency tests pass. Gateway peaked at 389Mi,
  no restarts.
- Finding: **object lock works** — 8/8 here and 39/39 in Ceph s3-tests. The ADR
  had listed it as a gap; corrected.
- Finding (config): `weed s3` defaults to `-allowDeleteBucketNotEmpty=true` and
  the chart doesn't override it — **DeleteBucket on a non-empty bucket deletes
  every object in it**. AWS/MinIO return `409 BucketNotEmpty`.
- Finding (config): SSE-S3 is **disabled unless a KEK is configured**
  (`s3.sse.kek` in `security.toml`); without it an SSE-S3 PUT returns `500
  InternalError` — retried by clients — instead of a 4xx. 4.13 didn't need this.
- Finding: `dir` and `dir/` can't coexist (`ExistingObjectIsFile` — the filer is
  a real file system); empty metadata values are dropped; unimplemented bucket
  APIs answer `BucketAlreadyOwnedByYou` instead of `NotImplemented`.
- Impact: the UDS package must set `allowDeleteBucketNotEmpty=false` and either
  configure an SSE-S3 KEK or document that SSE-S3 is unavailable. The 88% vs
  ~51% gap with Ceph s3-tests is depth, not disagreement: this suite checks the
  common path (its ACL tests never check enforcement), Ceph checks edge
  semantics.
- Refs: P3-10, `s3-testsuite/RESULTS.md`

### 2026-10-15 — 4.48: the 48 s3-tests errors were harness artifacts; multipart memory retention persists
- Context: Bumped chart 4.39.0 → 4.48.0, re-ran the full s3-tests suite and the
  P3-08 memory drill.
- Finding (harness): `kubectl port-forward` resets connections on multipart/copy
  traffic even when the gateway is healthy — `test_multipart_copy_small` errored
  after 2 min through the tunnel with the gateway at 157Mi, and passed in 2.5s
  from a pod inside the cluster. Added `just s3-tests-chunked` (in-cluster test
  pod, fresh gateway per chunk). Result: **376 pass / 368 fail / 0 error**; the
  48 old errors became 34 pass / 14 fail.
- Finding (conformance): vs 4.39, 3 checksum tests now pass; 5 `*_get_part`
  tests now fail because SeaweedFS returns AWS's `416 InvalidPartNumber` where
  the test expects RGW's `400 InvalidPart` — vendor-specific, not a regression.
  Advanced-feature gaps are unchanged.
- Finding (memory, P3-08): single-part 16 MB PUT+copy is now bounded
  (~220–240Mi plateau, survives a 256Mi limit). **Multipart is not**: one pass of
  the 48 multipart/copy/SSE tests leaves a fresh gateway at ~416Mi *idle*; the
  next pass hits 512Mi and is `OOMKilled` (exit 137). At 256Mi a single pass
  OOMs. Checked with cgroup `memory.stat`: it is anon (process) memory, not page
  cache.
- Impact: the memory blocker stands, narrowed to multipart workloads — which is
  what Velero/Loki/GitLab do for large objects. Size the S3 memory limit to the
  multipart working set and alert on gateway restarts. Any lab number taken
  through `kubectl port-forward` on multipart/copy traffic is suspect — that
  includes the Garage s3-tests run.
- Refs: P3-07, P3-08, `just s3-tests-chunked`, `s3-tests/curated-results.md`

### 2026-07-17 — Curated s3-tests full run: SeaweedFS is strong on core S3, weak on advanced features
- Context: Ran all 838 `test_s3.py` tests in curated chunks of 50 (fresh gateway
  + fresh port-forward per chunk, `--forked`, memory-limited gateway) to avoid the
  cumulative-memory crash and the cascade.
- Result: **345 passed / 353 failed / 48 errored** (746 clean outcomes).
- The 353 failures are genuine, cleanly-returned gaps concentrated in **advanced
  S3 features SeaweedFS doesn't implement**: bucket lifecycle, SSE/encryption,
  bucket policies, CORS, bucket/object ACLs, browser POST-object uploads, object
  lock/retention, bucket logging. Core + intermediate S3 (bucket/object CRUD,
  listing, multipart basics, versioning basics, metadata, copy) largely passes.
- The 48 errors are the **large-object instability** (copy/multipart/SSE
  connection resets, P3-08) — NOT harness cascade. Contained to the chunks holding
  those tests.
- Orchestration lesson: a large-object test's connection reset also kills a
  `kubectl port-forward` tunnel. The chunk runner MUST re-establish the
  port-forward (and verify reachability) before every chunk, or all later chunks
  error out (first attempt lost chunks 7+ to a dead tunnel — gateway was healthy
  the whole time). Full results: `s3-tests/curated-results.md`.
- Are failures just "wrong-vendor noise"? No. s3-tests targets Ceph RGW, so a few
  failures ARE Ceph-specific — but only **13 of 353** (RGW usage stats, Ceph
  `tenant$user` syntax, one explicit RGW bug). The other **340 are genuine gaps in
  standard AWS S3 features** SeaweedFS doesn't implement. `s3-tests/curated-results.md`
  tags every failure: vendor-specific vs. gap, and groups gaps by feature area
  (SSE 64, ACLs 39, copy edge cases 36, bucket logging 35, bucket policy 31,
  lifecycle 23, conditional writes/100-continue 23, POST uploads 20, ownership 8,
  CORS 9, multipart 9, versioning 6, public-access-block 3, other-standard 34).
- Verdict for the MinIO-replacement goal: SeaweedFS S3 is a good fit for apps
  needing core/intermediate S3; apps depending on lifecycle, SSE, bucket policies,
  CORS, full ACLs, POST uploads, or object lock need those gaps evaluated per-app.
- Refs: P3-07, `s3-tests/curated-results.md`

### 2026-07-16 — s3-tests: a signal-timeout poisons boto's connection pool → cascade; fix is per-test process isolation
- Context: Full `s3tests/functional/test_s3.py` run (839 tests) took 4h01m and
  reported 180 passed / 88 failed / **570 errors** / 1 skipped.
- Finding: The 570 "errors" were NOT real — they were a **cascade**. One slow test
  (`test_object_copy_16m`) hit the 25s `pytest-timeout`; the `--timeout-method=signal`
  (SIGALRM) interrupted boto **mid-request**, leaving a broken connection in
  urllib3's shared pool (`ConnectionResetError`/`ConnectionClosedError`). Every
  subsequent test reused the poisoned pool → hung → timed out → 572 timeout events.
  The SeaweedFS gateway was healthy throughout (0 restarts, responsive).
- Trustworthy signal from that run (healthy-connection region, ~first third):
  **180 passed, 87 genuine failures** (~67% pass on the 267 tests that actually
  ran). Real failures cluster on browser **POST-object** uploads (matches Mint's
  presigned-POST gap), **Ceph-RGW-specific usage stats** (`KeyError: 'Summary'` /
  `x-rgw-*` headers — not real S3), metadata edge cases, list encoding,
  `x-amz-expected-bucket-owner`.
- Deeper root cause (corrected): It is NOT (only) a client connection-pool issue.
  `test_object_copy_16m` (a 16 MB server-side copy) makes the SeaweedFS **s3
  gateway reset connections** (`ConnectionResetError: reset by peer`), and during
  the long run the **s3 gateway crashed and restarted once** (`RESTARTS 1`,
  `exit=255`, no resource limits set → not a K8s OOM-kill). After that, requests
  get reset for a window.
- What did NOT fix it: `pytest-timeout` (signal) poisoned the pool; `--forked +
  pytest-timeout` crashed pytest (`INTERNALERROR`, SIGALRM in the parent's
  waitpid); `--forked` alone still cascaded — because the resets are **server-side**,
  so per-test client isolation can't prevent them. Lowering botocore socket
  timeouts (conftest) bounds hangs but not resets.
- Current harness state: `--forked` + `s3-tests/conftest.py` (botocore
  connect 10s/read 30s, no retries). This is the right hang-protection, but the
  full `test_s3.py` still can't complete cleanly because large-object copy tests
  destabilize the gateway.
- **Root cause (confirmed by investigation) — s3 gateway memory retention:**
  A *single* 16 MB PUT+copy+get is fine (even repeated, even with boto3
  keep-alive reuse — reproduced cleanly, no reset). The real issue is that the
  **s3 gateway accumulates memory during large-object operations and does not
  release it**: measured it climb 40Mi → 117Mi → 379Mi → **450Mi and holding
  while idle** (CPU 1m) across test rounds. With **no resource limits** (chart
  default `s3.resources: {}`), a large-object-heavy workload grows memory until
  the gateway is killed. That is exactly what happened in the full s3-tests run:
  it crashed once (~34% in, `exit 255`, no K8s limit → node-level OOM), and the
  crash's connection reset poisoned the (non-forked) client pool → 570 cascading
  timeouts. The cascade was a *symptom*; the memory behavior is the cause.
- Mitigation PROVEN (P3-08): Set a 256Mi `s3.resources.limits.memory`, restarted
  to a fresh gateway (31Mi), and drove sequential 16MB PUT+copy ops. At ~iter 17
  the container was killed with **`reason=OOMKilled`, `exitCode=137`**, then
  **auto-restarted and recovered** (HTTP 403 in 3ms). This is the clean, visible,
  attributable signal — vs. the unbounded default's node-level `exit 255`. The lab
  value is set to 512Mi (usable default); the demo used 256Mi to trigger it fast.
- Mitigations:
  1. Set `s3.resources` requests/limits (the chart supports it) — bounds memory
     and makes kills predictable/visible (`OOMKilled` + restart) instead of a
     mysterious `exit 255`. Does NOT fix the growth, but contains it. PROVEN above.
  2. Treat the **memory retention as a SeaweedFS concern to report/track** — the
     s3 gateway appears to buffer/retain large-object memory aggressively.
  3. For the UDS package: set s3 memory limits + monitor gateway memory under
     realistic large-object workloads before trusting it as a MinIO replacement.
- Practical path for granular conformance: run s3-tests in **curated slices**
  (small groups, fresh gateway memory) so growth never reaches the crash point.
- Refs: P3-07, P3-08, `s3-tests/*`, `just s3-tests`

### 2026-07-16 — Editing the S3 identity config requires an explicit s3 restart
- Context: Added `s3test-main/alt/tenant` identities to
  `k3d/s3-identities-secret.yaml` (needed by Ceph s3-tests) and ran `just deploy`.
  New keys returned `InvalidAccessKeyId`.
- Finding: Two things combine — (1) Helm won't roll the s3 **Deployment** when its
  pod spec is unchanged (only the mounted Secret's *content* changed), and (2) the
  SeaweedFS s3 process reads `-config=/etc/sw/seaweedfs_s3_config` **only at
  startup** (no hot reload). So the running pod kept serving the old identities.
- Fix: `kubectl rollout restart deploy/seaweedfs-s3`. Made `just deploy` always
  restart s3 after applying the secret so identity edits reliably take effect.
- Impact: Same "config read once at startup" theme as the filer identity behavior.
  For the UDS package, any change to S3 identities must force an s3 restart — a
  plain secret update is silently ignored by the running gateway.
- Refs: `k3d/s3-identities-secret.yaml`, `just deploy`

### 2026-07-15 — Phase 3b: MinIO Mint shows broad core compatibility with 3 edge gaps
- Context: Ran MinIO Mint (awscli, mc, minio-go, s3cmd) against the S3 gateway,
  with `RUN_ON_FAIL=1` to see full results. Note Mint targets MinIO, so some
  MinIO-specific behavior is expected not to match.
- Findings:
  - **awscli: 9/10 pass.** Core CRUD, copy, multipart, listing all pass.
  - **s3cmd: clean pass.**
  - The failures are **edge features, not core object I/O**:
    1. **Storage classes** — `copy-object` with `--storage-class REDUCED_REDUNDANCY`
       (awscli). SeaweedFS has no storage-class concept; a self-copy "without
       change" is rejected. Not relevant to most apps.
    2. **Presigned POST policy** — browser form-POST uploads (`mc`
       test_presigned_post_policy_error). Used by some browser-direct-upload flows.
    3. **Presigned GET with response-header overrides** — minio-go
       `PresignedGetObject` with `response-content-disposition`. **Verified
       directly:** SeaweedFS DOES honor `response-content-disposition` and
       `response-content-type` overrides on a normal signed `get-object` (it
       returned both correctly). So the underlying feature works — the Mint
       failure is the narrower *presigned-URL* variant (a signature/validation
       edge in the presigned form), not a missing capability. Lower concern than
       it first looked.
- Caveats about Mint accounting: its per-suite `error.log` files only capture
  stderr; the consolidated `mint-logs/log.json` is the real per-test record but
  only reliably captured awscli here. Treat mc/minio-go signals as "first failure
  seen" rather than full counts. Notably **minio-go reports `done in 0s`** (so it
  shows as PASS) even though a fail-fast run failed it on `PresignedGetObject` —
  Mint's exit accounting is inconsistent, so don't over-trust the 0s "PASS".
- **Viewing it:** `just mint-report` renders a persistent report (per-suite
  status, the failure JSON, awscli counts) from `./mint-logs/last-run.log`, which
  `mint-test` now always writes. Earlier the full output was only in ephemeral
  scratchpad + a thin log.json — the conformance results were effectively hidden.
- Impact: Basic + intermediate S3 usage (what GitLab, registries, Loki, backups
  mostly need) is well covered. Of the 3 gaps, only presigned POST policy is a
  clear missing feature; storage classes are N/A for SeaweedFS; and response-header
  overrides actually work on signed GETs (only the presigned-URL variant flagged).
- Refs: P3-06

### 2026-07-15 — Phase 3a: core S3 features (versioning, presign, metadata, SigV4) all work
- Context: Ran targeted S3-compatibility recipes with containerized aws-cli + mc.
- Findings — all passed:
  - **Versioning** (`s3-versioning-test`): `put-bucket-versioning Status=Enabled`
    works; overwrites keep distinct version-ids; fetch by `--version-id` returns
    the right content. (Cleanup needs per-version deletes — `s3 rb` alone won't
    remove versions.)
  - **Presigned URLs** (`s3-presign-test`): `aws s3 presign` yields an
    `AWS4-HMAC-SHA256` URL that a plain `curl` (no creds) can GET.
  - **Content-type + user metadata** (`s3-metadata-test`): preserved through
    put→head-object.
  - **SigV4 / cross-SDK** (`s3-mc-test`): MinIO's own `mc` (Go SDK, SigV4) does
    full CRUD against SeaweedFS — a second, independent client stack confirms
    SigV4 interop (the presigned URL uses SigV4 too).
- Impact: These are the S3 features real apps (GitLab, registries, Loki, backups)
  actually depend on. All present → strong signal SeaweedFS can stand in for MinIO.
  Broad conformance (Mint) is P3-06, running separately for breadth.
- Refs: P3-01, P3-02, P3-04, P3-05 (P3-03 ≙ P1-08 tenant isolation)

### 2026-07-15 — Phase 2: data is durable across restarts/redeploy; filer recovery is fast on a *clean* restart
- Context: Ran the Phase 2 durability suite (P2-01…P2-07).
- Findings:
  - **Durability holds.** Objects survived restarts of every component (s3,
    filer, volume, master) and a full `helm uninstall` + redeploy — because the
    filer-metadata and volume-data PVCs are retained by default. This is the
    end-to-end payoff of putting the volume tier on a PVC (see storage gotcha).
  - **Recovery is quick on a clean rollout:** s3 ~16s, volume ~26s, filer ~27s
    (measured from restart to first successful read). This **refines** the
    earlier alarming "~5 min" filer observation — that pathological case only
    happened when the old filer IP became fully *unroutable* and the s3 gateway
    burned minutes on cached-gRPC "no route to host" timeouts. A graceful
    `rollout restart` does not trigger it.
  - **Horizontal scale works:** `volume.replicas=2` placed the 2nd volume pod on
    the other k3d agent and it joined the topology as a second data node
    (combined Max 562). Confirms the volume tier scales out across nodes.
  - **Volumes are allocated on demand:** volume-0 grew from 7 to 14 volumes as we
    created/used buckets over the session.
- Impact: SeaweedFS is durable enough to trust for the MinIO-replacement goal,
  provided PVCs are used for filer + volume. The filer-restart error window is
  small in normal operation but can spike if the filer's identity/IP changes
  abruptly — worth keeping in mind for the UDS package's rollout strategy.
- Gotcha (tooling): `just` recipe args are **positional**, not `name=value`.
  Use `just restart-survives filer`, NOT `just restart-survives component=filer`
  (the latter is parsed as a variable assignment and the recipe sees the default).
- Refs: P2-01…P2-07

### 2026-07-15 — No MinIO-style tenants, but bucket-scoped identities give the same isolation
- Context: Asked whether SeaweedFS has "tenants" like MinIO. Added P1-08.
- Finding: SeaweedFS has **no isolated-instance tenants** (MinIO Operator spins
  up a separate cluster per tenant). Instead the S3 gateway uses an IAM-like
  identity list where each identity's `actions` can be **scoped to a bucket**
  via `Action:bucketName`. Scoping `tenant-a` to `bucket-a` lets it use bucket-a
  and get `AccessDenied` on bucket-b — verified both directions.
- How: The upstream chart's built-in `s3.credentials` only supports admin+read.
  For arbitrary scoped identities you must supply your own `seaweedfs_s3_config`
  JSON via `s3.existingConfigSecret`. We switched the lab to a checked-in secret
  (`k3d/s3-identities-secret.yaml`) applied by `just deploy` before the Helm
  install (the secret must exist before the s3 pod starts).
- Impact: This is exactly how the DU UDS package provisions per-app scoped
  credentials — good validation of that approach. "Multi-tenancy" in SeaweedFS =
  bucket-scoped identities, not isolated clusters. Worth noting for anyone
  expecting MinIO tenant semantics (quotas, separate storage, etc. are NOT here).
- Refs: P1-08, `k3d/s3-identities-secret.yaml`, `seaweedfs-package/chart/templates/config-secret.yaml`

### 2026-07-15 — Phase 1 complete: auth enforced cleanly; topology best inspected via master JSON API
- Context: Finished P1-06 (auth) and P1-07 (topology).
- Finding (auth): With `s3.enableAuth: true` and an admin identity, auth is
  enforced as expected — correct creds allowed, wrong creds → `AccessDenied`,
  and anonymous/unsigned requests → denied. No surprises.
- Finding (topology): The master's **JSON API** is the automatable way to see
  the cluster (vs. eyeballing the HTML UI): `/cluster/status` for leader +
  `MaxVolumeId`, `/dir/status` for the DataCenter→Rack→DataNode→volume tree.
  `just topology` wraps this with `jq`.
- Observation: A fresh volume server pre-creates several volumes eagerly (saw 7
  volumes, `Max` 281 auto-derived from the 2Gi PVC). Worth understanding how
  `Max`/volume sizing is derived in Phase 2.
- Impact: Auth model is solid enough to build on for the UDS phase. For any
  scripted health/topology checks, prefer the master JSON API.
- Refs: P1-06, P1-07

### 2026-07-15 — s3 gateway caches filer connections; slow to recover from filer IP change
- Context: After deleting/recreating the volume StatefulSet, the filer pod also
  rolled and came back with a **new pod IP**. The s3 gateway (a long-lived
  Deployment pod) kept a **cached gRPC connection to the old filer IP** and
  returned `CreateBucket ... InternalError` / `no route to host` for several
  minutes before rediscovering the new filer.
- Finding: The s3 gateway does not immediately react to a filer restart; it
  self-heals only after its cached connection is invalidated and it re-queries
  the master for the current filer set (took ~5 min in our run).
- Impact: This is the same "filer restart" sensitivity the UDS package warns
  about (`seaweedfs-package/CLAUDE.md`). Any change that rolls the filer (config
  change, node move) can cause a window of S3 errors. Worth testing deliberately
  in P2-03 and understanding mitigations before the UDS phase.
- Refs: P1-05, P2-03

### 2026-07-15 — Volume storage defaults to ephemeral hostPath, configured via `dataDirs` (a list)
- Context: After first deploy, master and filer had PVCs but the **volume server
  had none** — its object data was on a `hostPath` (`/ssd/object_store/`).
- Finding: The volume server uses `volume.dataDirs` (a **list**), not the `data`
  **map** that master/filer use. My initial `volume.data` was silently ignored,
  leaving the chart default (ephemeral hostPath). Fixed by switching to
  `volume.dataDirs[].type: persistentVolumeClaim`.
- Finding (bonus): You can't add a `volumeClaimTemplate` to an existing
  StatefulSet — `helm upgrade` fails ("updates to statefulset spec ... are
  forbidden"). Had to delete + recreate the volume StatefulSet.
- Impact: For a durable MinIO replacement, the volume tier MUST be on a PVC.
  This is the single most important storage setting to get right.
- Refs: P1-03, `k3d/seaweedfs-values.yaml`

### 2026-07-15 — Chart 4.39.0 needs Helm ≥ 3.17
- Context: `helm install` failed on Helm 3.16.1 with `function "fromToml" not
  defined` while rendering `shared/security-configmap.yaml`.
- Finding: `fromToml` was added in Helm v3.17.0. Chart 4.39.0 requires it.
- Impact: Documented Helm ≥ 3.17 as a prerequisite. (Alternative would have been
  pinning an older chart version.)
- Refs: P1-02, README prerequisites

### 2026-07-15 — Repo scaffolded
- Context: First session. Set up `learning-seaweedfs` to explore SeaweedFS as an
  open-source S3 replacement for MinIO.
- Finding: `s3.enabled` defaults to **false** in the upstream Helm chart — easy
  to miss and you'd get no S3 endpoint at all.
- Impact: Any deployment aiming to replace MinIO must explicitly enable the S3
  gateway (and decide on auth).
- Refs: P1-02, `k3d/seaweedfs-values.yaml`
