# SeaweedFS Test Plan

Living document. Each item has an **ID**, what we're validating, how, the
**expected** result, and a **Status** / **Notes** column we fill in as we go.

Status legend: ⬜ not started · 🟡 in progress · ✅ pass · ❌ fail · ⏭️ skipped

The `How` column references `just` recipes (see the `justfile`) where possible so
tests are repeatable.

---

## Phase 1 — Bare upstream deploy & S3 basics

Goal: get a working S3 endpoint and prove basic object operations. Learn the
component model.

| ID    | What we're validating | How | Expected | Status | Notes |
|-------|-----------------------|-----|----------|--------|-------|
| P1-01 | Cluster comes up | `just cluster-up` | k3d cluster `seaweedfs-lab` ready, context switched | ✅ | 1 server + 2 agents, context switched. |
| P1-02 | Chart installs from published repo | `just deploy` | Helm release `seaweedfs` deployed, `--wait` succeeds | ✅ | Needed Helm ≥ 3.17 (`fromToml`). Chart pinned 4.39.0. |
| P1-03 | All components healthy | `just status` | master/filer/volume/s3 pods `Running`, PVCs `Bound` | ✅ | Fixed volume storage → PVC (`dataDirs`), see lessons. |
| P1-04 | S3 endpoint reachable | `just port-forward-s3` + curl | TCP connect on :8333, HTTP response | ✅ | Verified via port-forward inside `s3-smoke`. |
| P1-05 | S3 CRUD round-trip | `just s3-smoke` | Create bucket, put/list/get/delete object, content matches | ✅ | Passes. Transient InternalError right after a filer roll (see lessons). |
| P1-06 | Auth is enforced | `just s3-auth-check` | Good creds allowed; wrong creds + anonymous denied | ✅ | Correct→allowed, wrong-key→denied, `--no-sign-request`→denied. |
| P1-07 | Master reflects topology | `just topology` | Volume(s) and topology visible | ✅ | Master API `/cluster/status` + `/dir/status`: 1 volume node, 7 volumes. |
| P1-08 | Tenant isolation (bucket-scoped identities) | `just tenant-isolation-test` | tenant-a can use bucket-a but is denied on bucket-b (and vice-versa) | ✅ | SeaweedFS has no MinIO-style tenants; emulated via `Action:bucket` scoped identities. See lessons + `k3d/s3-identities-secret.yaml`. |

## Phase 2 — Storage, scale & durability

Goal: understand how data/metadata are stored and what survives restarts.

| ID    | What we're validating | How | Expected | Status | Notes |
|-------|-----------------------|-----|----------|--------|-------|
| P2-01 | New volumes created on demand | write objects / create collections | master shows additional volume(s) | ✅ | Volume-0 grew 7→14 volumes (`22-28`→`+64-70`) over our bucket ops; allocation is on demand. |
| P2-02 | Data survives S3 gateway restart | `just restart-survives s3` | objects still readable | ✅ | Recovered in ~16s (port-forward re-established to new pod). |
| P2-03 | Data survives filer restart | `just restart-survives filer` | metadata + objects intact | ✅ | Recovered in ~27s on a clean rollout. (Pathological ~5min seen once when old filer IP went unroutable — see lessons.) |
| P2-04 | Data survives volume restart | `just restart-survives volume` | objects still readable after recovery | ✅ | Recovered in ~26s. |
| P2-05 | Data survives `uninstall`+redeploy (PVCs retained) | `just redeploy-persists` | pre-existing objects still present | ✅ | filer-metadata + volume-data PVCs retained on `helm uninstall`. |
| P2-06 | Multipart upload works | `just multipart-test` | completes; round-trip matches | ✅ | 20MB random file, sha256 match (aws-cli auto-multiparts >8MB). |
| P2-07 | Scale volume replicas | `--set volume.replicas=2` | new volume server joins topology | ✅ | 2nd volume pod scheduled on agent-1; topology showed 2 data nodes (Max 562). Reverted to 1. |

## Phase 3 — S3 compatibility & app fit

Goal: how closely does the S3 API match what real apps (e.g. GitLab, Loki,
registries) expect?

| ID    | What we're validating | How | Expected | Status | Notes |
|-------|-----------------------|-----|----------|--------|-------|
| P3-01 | Bucket versioning | `just s3-versioning-test` | previous versions retrievable | ✅ | Status→Enabled; 2 distinct version-ids; fetch by version-id returns correct content. |
| P3-02 | Presigned URLs | `just s3-presign-test` | object downloads without creds | ✅ | `AWS4-HMAC-SHA256` presigned GET fetched with plain curl. |
| P3-03 | Per-app scoped credentials | (covered by `just tenant-isolation-test`) | can access own bucket, denied elsewhere | ✅ | Same mechanism as P1-08 — bucket-scoped identities. |
| P3-04 | Object metadata / content-type | `just s3-metadata-test` | metadata preserved | ✅ | ContentType + user metadata (team/env) preserved through head-object. |
| P3-05 | SigV4 compatibility | `just s3-mc-test` | requests authenticate correctly | ✅ | MinIO `mc` (Go SDK, SigV4) full CRUD interop; presign also uses SigV4. |
| P3-06 | Broad conformance (MinIO Mint) | `just mint-test "..."` | pass rate across SDK suites | ✅* | Core ops broadly pass (awscli 9/10, s3cmd clean). 3 edge gaps: storage classes, presigned POST policy, presigned-GET response-header overrides. See lessons. |

## Phase 4 — Toward the UDS package

Goal: connect what we learned to `seaweedfs-package/`. Map each UDS addition
(Istio ambient mesh, network policies, SSO, 3-chart bucket provisioning) back to
the bare behavior above.

| ID    | What we're validating | How | Expected | Status | Notes |
|-------|-----------------------|-----|----------|--------|-------|
| P4-01 | Deploy the UDS package into K3d | `uds` bundle deploy | package + UDS Core up | ⬜ | |
| P4-02 | Declarative bucket/credential provisioning | `apps` values | buckets + secrets created | ⬜ | |
| P4-03 | Compare to MinIO operator package UX | side-by-side | parity noted | ⬜ | |

---

## Open questions / to investigate

- Filer metadata backend options (embedded vs. external DB) and trade-offs.
- Backup/restore story for metadata vs. data.
- Behavior under node loss with replication enabled.
- Resource footprint vs. MinIO for equivalent workloads.
