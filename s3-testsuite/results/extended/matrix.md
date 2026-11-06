# S3 Extended Compatibility Matrix — 2026-10-22

[**ref-aws**](ref-aws.md) 63/63 (100%) &ensp;|  [**ref-garage-v1.0.1**](ref-garage-v1.0.1.md) 48/63 (76%) &ensp;|  [**ref-minio**](ref-minio.md) 60/63 (95%) &ensp;|  [**ref-seaweedfs-4.13**](ref-seaweedfs-4.13.md) 62/63 (98%) &ensp;|  [**seaweedfs-4.48-k8s**](seaweedfs-4.48-k8s.md) 62/63 (98%)

| Priority | Feature Area | [ref-aws](ref-aws.md) | [ref-garage-v1.0.1](ref-garage-v1.0.1.md) | [ref-minio](ref-minio.md) | [ref-seaweedfs-4.13](ref-seaweedfs-4.13.md) | [seaweedfs-4.48-k8s](seaweedfs-4.48-k8s.md) |
|:---:|---|:---:|:---:|:---:|:---:|:---:|
| P0 | Concurrent Read/Write/Delete | ✅ [7/7](ref-aws.md#concurrent-read/write/delete) | ✅ [7/7](ref-garage-v1.0.1.md#concurrent-read/write/delete) | ⚠️ [6/7](ref-minio.md#concurrent-read/write/delete) | ✅ [7/7](ref-seaweedfs-4.13.md#concurrent-read/write/delete) | ✅ [7/7](seaweedfs-4.48-k8s.md#concurrent-read/write/delete) |
| P0 | Overwrite Atomicity | ✅ [6/6](ref-aws.md#overwrite-atomicity) | ✅ [6/6](ref-garage-v1.0.1.md#overwrite-atomicity) | ✅ [6/6](ref-minio.md#overwrite-atomicity) | ✅ [6/6](ref-seaweedfs-4.13.md#overwrite-atomicity) | ✅ [6/6](seaweedfs-4.48-k8s.md#overwrite-atomicity) |
| P0 | Listing Consistency | ✅ [6/6](ref-aws.md#listing-consistency) | ✅ [6/6](ref-garage-v1.0.1.md#listing-consistency) | ✅ [6/6](ref-minio.md#listing-consistency) | ✅ [6/6](ref-seaweedfs-4.13.md#listing-consistency) | ✅ [6/6](seaweedfs-4.48-k8s.md#listing-consistency) |
| P1 | Concurrent Versioning | ✅ [7/7](ref-aws.md#concurrent-versioning) | ❌ [0/7](ref-garage-v1.0.1.md#concurrent-versioning) | ✅ [7/7](ref-minio.md#concurrent-versioning) | ✅ [7/7](ref-seaweedfs-4.13.md#concurrent-versioning) | ✅ [7/7](seaweedfs-4.48-k8s.md#concurrent-versioning) |
| P1 | Multipart Edge Cases | ✅ [8/8](ref-aws.md#multipart-edge-cases) | ⚠️ [7/8](ref-garage-v1.0.1.md#multipart-edge-cases) | ✅ [8/8](ref-minio.md#multipart-edge-cases) | ✅ [8/8](ref-seaweedfs-4.13.md#multipart-edge-cases) | ✅ [8/8](seaweedfs-4.48-k8s.md#multipart-edge-cases) |
| P1 | Namespace Isolation | ✅ [6/6](ref-aws.md#namespace-isolation) | ✅ [6/6](ref-garage-v1.0.1.md#namespace-isolation) | ✅ [6/6](ref-minio.md#namespace-isolation) | ⚠️ [5/6](ref-seaweedfs-4.13.md#namespace-isolation) | ⚠️ [5/6](seaweedfs-4.48-k8s.md#namespace-isolation) |
| P1 | Large-Scale Listing | ✅ [6/6](ref-aws.md#large-scale-listing) | ✅ [6/6](ref-garage-v1.0.1.md#large-scale-listing) | ✅ [6/6](ref-minio.md#large-scale-listing) | ✅ [6/6](ref-seaweedfs-4.13.md#large-scale-listing) | ✅ [6/6](seaweedfs-4.48-k8s.md#large-scale-listing) |
| P1 | Conditional Operations | ✅ [7/7](ref-aws.md#conditional-operations) | ⚠️ [5/7](ref-garage-v1.0.1.md#conditional-operations) | ✅ [7/7](ref-minio.md#conditional-operations) | ✅ [7/7](ref-seaweedfs-4.13.md#conditional-operations) | ✅ [7/7](seaweedfs-4.48-k8s.md#conditional-operations) |
| P2 | Object Lock Contention | ✅ [5/5](ref-aws.md#object-lock-contention) | ❌ [0/5](ref-garage-v1.0.1.md#object-lock-contention) | ⚠️ [3/5](ref-minio.md#object-lock-contention) | ✅ [5/5](ref-seaweedfs-4.13.md#object-lock-contention) | ✅ [5/5](seaweedfs-4.48-k8s.md#object-lock-contention) |
| P2 | Bulk Throughput | ✅ [5/5](ref-aws.md#bulk-throughput) | ✅ [5/5](ref-garage-v1.0.1.md#bulk-throughput) | ✅ [5/5](ref-minio.md#bulk-throughput) | ✅ [5/5](ref-seaweedfs-4.13.md#bulk-throughput) | ✅ [5/5](seaweedfs-4.48-k8s.md#bulk-throughput) |

✅ = all tests pass &emsp; ⚠️ = partial (some pass) &emsp; ❌ = all tests fail &emsp; ⬜ = not tested

*Generated 2026-10-22*
