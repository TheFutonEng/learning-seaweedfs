# SeaweedFS Architecture (learning notes)

A quick mental model of the pieces we deploy, so the rest of the docs make sense.
This describes the **bare upstream** deployment (Phase 1) — not the UDS package yet.

## Components

SeaweedFS splits responsibilities across a few processes. In this chart,
master/filer/volume run as **StatefulSets**, while the **s3 gateway runs as a
Deployment** (it's stateless — it just proxies to the filer).

| Component  | Default port(s)      | Role |
|------------|----------------------|------|
| **master** | 9333 (HTTP), 19333 (gRPC) | Cluster brain. Tracks volumes, assigns file IDs, coordinates the topology. Lightweight metadata, not data. |
| **volume** | 8080 (HTTP), 18080 (gRPC) | Stores the actual bytes. Data lives in a handful of large "volume" files; individual objects are needles inside them. Scales out horizontally. |
| **filer**  | 8888 (HTTP), 18888 (gRPC) | Adds a real filesystem + metadata store (directories, filenames, attributes) on top of the flat volume layer. Backs higher-level gateways. |
| **s3**     | 8333 (HTTP)          | S3-compatible gateway. Translates S3 API calls into filer operations. **This is the interface we care about for a MinIO replacement.** |

There are more optional pieces (SFTP, admin UI, worker, COSI, Iceberg catalog)
we're ignoring for now.

## How a write flows (roughly)

```
S3 client ──PUT──> s3 gateway ──> filer ──> master (where should this go?)
                                    │
                                    └──> volume server (store the bytes)
```

1. The **s3 gateway** receives an S3 `PutObject`.
2. It talks to the **filer** to record the object as a file with a path/key.
3. The filer asks the **master** for a place to store the data (a volume + file ID).
4. The bytes land on a **volume** server; the filer stores the metadata mapping.

## Key facts to remember

- `s3.enabled` defaults to **false** in the upstream chart — no S3 endpoint
  unless you turn it on (we do, in `k3d/seaweedfs-values.yaml`).
- Metadata (filer) and data (volume) are **separate** — a lesson that matters
  for backup, scaling, and restart behavior.
- The master holds cluster topology in memory + a small store; the volumes hold
  the heavy data. Losing a volume ≠ losing metadata and vice-versa.
- Everything is single-replica in our lab. Replication/HA is a later phase.

## Identities & "tenants"

SeaweedFS has **no MinIO-Operator-style tenants** (MinIO provisions a separate
cluster per tenant). Instead the S3 gateway uses an **IAM-like identity list**
(`seaweedfs_s3_config` JSON). Each identity has credentials + `actions`:

- **Global** actions: `Admin`, `Read`, `Write`, `List`, `Tagging`.
- **Bucket-scoped** actions: `Action:bucketName` (e.g. `Read:bucket-a`), optionally
  with a prefix `Action:bucket/prefix`.

You emulate tenants by scoping each identity to its own bucket(s). We do this in
`k3d/s3-identities-secret.yaml` (admin + `tenant-a`→bucket-a + `tenant-b`→bucket-b)
and feed it via the chart's `s3.existingConfigSecret`. This is the same pattern
the DU UDS package uses to provision per-app scoped credentials.

Note: the upstream chart's built-in `s3.credentials` only supports `admin` +
`read` identities — for arbitrary scoped identities you must supply your own
config via `existingConfigSecret`.

## Storage config gotcha

The three data tiers configure storage **differently**:

- `master.data` and `filer.data` — a **map** (`type`, `size`, `storageClass`).
- `volume.dataDirs` — a **list** of dirs, each with `type`/`size`/etc. The chart
  default is an ephemeral **`hostPath`** (`/ssd`), *not* a PVC. If you only set
  `volume.data` (map), it's silently ignored and your object bytes land on an
  ephemeral hostPath. Use `volume.dataDirs` with `type: persistentVolumeClaim`.

Also: you can't add a PVC template to a StatefulSet that already exists
(`volumeClaimTemplates` is immutable) — the volume StatefulSet must be
deleted/recreated to change its storage.

## Chart / version pinning

Requires **Helm ≥ 3.17** (chart 4.39.0 uses the `fromToml` template function).

- Helm repo: `https://seaweedfs.github.io/seaweedfs/helm`
- Chart: `seaweedfs/seaweedfs`, pinned to `4.39.0` (appVersion 4.39) in the justfile.

## References

- Upstream repo: https://github.com/seaweedfs/seaweedfs
- Wiki: https://github.com/seaweedfs/seaweedfs/wiki
