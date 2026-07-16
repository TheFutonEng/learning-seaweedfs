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
