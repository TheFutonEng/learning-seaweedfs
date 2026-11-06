# S3 Compatibility Matrix — 2026-10-22

[**ref-aws**](ref-aws.md) 203/207 (98%) &ensp;|  [**ref-garage-v1.0.1**](ref-garage-v1.0.1.md) 121/207 (58%) &ensp;|  [**ref-minio**](ref-minio.md) 176/207 (85%) &ensp;|  [**ref-seaweedfs-4.13**](ref-seaweedfs-4.13.md) 174/207 (84%) &ensp;|  [**seaweedfs-4.48-k8s**](seaweedfs-4.48-k8s.md) 183/207 (88%)

| Priority | Feature Area | [ref-aws](ref-aws.md) | [ref-garage-v1.0.1](ref-garage-v1.0.1.md) | [ref-minio](ref-minio.md) | [ref-seaweedfs-4.13](ref-seaweedfs-4.13.md) | [seaweedfs-4.48-k8s](seaweedfs-4.48-k8s.md) |
|:---:|---|:---:|:---:|:---:|:---:|:---:|
| P0 | Bucket CRUD | ✅ [11/11](ref-aws.md#bucket-crud) | ✅ [11/11](ref-garage-v1.0.1.md#bucket-crud) | ✅ [11/11](ref-minio.md#bucket-crud) | ⚠️ [10/11](ref-seaweedfs-4.13.md#bucket-crud) | ⚠️ [10/11](seaweedfs-4.48-k8s.md#bucket-crud) |
| P0 | Object CRUD | ✅ [28/28](ref-aws.md#object-crud) | ⚠️ [24/28](ref-garage-v1.0.1.md#object-crud) | ✅ [28/28](ref-minio.md#object-crud) | ⚠️ [27/28](ref-seaweedfs-4.13.md#object-crud) | ✅ [28/28](seaweedfs-4.48-k8s.md#object-crud) |
| P0 | Object Listing | ✅ [14/14](ref-aws.md#object-listing) | ✅ [14/14](ref-garage-v1.0.1.md#object-listing) | ✅ [14/14](ref-minio.md#object-listing) | ✅ [14/14](ref-seaweedfs-4.13.md#object-listing) | ✅ [14/14](seaweedfs-4.48-k8s.md#object-listing) |
| P0 | Multipart Upload | ✅ [9/9](ref-aws.md#multipart-upload) | ✅ [9/9](ref-garage-v1.0.1.md#multipart-upload) | ✅ [9/9](ref-minio.md#multipart-upload) | ✅ [9/9](ref-seaweedfs-4.13.md#multipart-upload) | ✅ [9/9](seaweedfs-4.48-k8s.md#multipart-upload) |
| P0 | Presigned URLs | ✅ [5/5](ref-aws.md#presigned-urls) | ✅ [5/5](ref-garage-v1.0.1.md#presigned-urls) | ✅ [5/5](ref-minio.md#presigned-urls) | ✅ [5/5](ref-seaweedfs-4.13.md#presigned-urls) | ✅ [5/5](seaweedfs-4.48-k8s.md#presigned-urls) |
| P0 | Error Handling | ✅ [12/12](ref-aws.md#error-handling) | ⚠️ [10/12](ref-garage-v1.0.1.md#error-handling) | ✅ [12/12](ref-minio.md#error-handling) | ⚠️ [10/12](ref-seaweedfs-4.13.md#error-handling) | ⚠️ [10/12](seaweedfs-4.48-k8s.md#error-handling) |
| P1 | Versioning | ✅ [14/14](ref-aws.md#versioning) | ⚠️ [1/14](ref-garage-v1.0.1.md#versioning) | ✅ [14/14](ref-minio.md#versioning) | ✅ [14/14](ref-seaweedfs-4.13.md#versioning) | ✅ [14/14](seaweedfs-4.48-k8s.md#versioning) |
| P1 | Object Tagging | ✅ [8/8](ref-aws.md#object-tagging) | ❌ [0/8](ref-garage-v1.0.1.md#object-tagging) | ✅ [8/8](ref-minio.md#object-tagging) | ✅ [8/8](ref-seaweedfs-4.13.md#object-tagging) | ✅ [8/8](seaweedfs-4.48-k8s.md#object-tagging) |
| P1 | Bucket Tagging | ✅ [4/4](ref-aws.md#bucket-tagging) | ❌ [0/4](ref-garage-v1.0.1.md#bucket-tagging) | ✅ [4/4](ref-minio.md#bucket-tagging) | ✅ [4/4](ref-seaweedfs-4.13.md#bucket-tagging) | ✅ [4/4](seaweedfs-4.48-k8s.md#bucket-tagging) |
| P1 | Server-Side Encryption | ✅ [10/10](ref-aws.md#server-side-encryption) | ⚠️ [6/10](ref-garage-v1.0.1.md#server-side-encryption) | ✅ [10/10](ref-minio.md#server-side-encryption) | ⚠️ [9/10](ref-seaweedfs-4.13.md#server-side-encryption) | ⚠️ [7/10](seaweedfs-4.48-k8s.md#server-side-encryption) |
| P1 | Lifecycle Config | ✅ [8/8](ref-aws.md#lifecycle-config) | ⚠️ [5/8](ref-garage-v1.0.1.md#lifecycle-config) | ⚠️ [7/8](ref-minio.md#lifecycle-config) | ⚠️ [2/8](ref-seaweedfs-4.13.md#lifecycle-config) | ✅ [8/8](seaweedfs-4.48-k8s.md#lifecycle-config) |
| P1 | CORS | ✅ [5/5](ref-aws.md#cors) | ⚠️ [3/5](ref-garage-v1.0.1.md#cors) | ⚠️ [1/5](ref-minio.md#cors) | ✅ [5/5](ref-seaweedfs-4.13.md#cors) | ✅ [5/5](seaweedfs-4.48-k8s.md#cors) |
| P1 | Content Type & Metadata | ✅ [10/10](ref-aws.md#content-type-metadata) | ⚠️ [9/10](ref-garage-v1.0.1.md#content-type-metadata) | ✅ [10/10](ref-minio.md#content-type-metadata) | ⚠️ [8/10](ref-seaweedfs-4.13.md#content-type-metadata) | ⚠️ [9/10](seaweedfs-4.48-k8s.md#content-type-metadata) |
| P1 | Auth (Anonymous + STS) | ✅ [2/3](ref-aws.md#auth-anonymous-sts) | ⚠️ [1/3](ref-garage-v1.0.1.md#auth-anonymous-sts) | ⚠️ [2/3](ref-minio.md#auth-anonymous-sts) | ✅ [2/3](ref-seaweedfs-4.13.md#auth-anonymous-sts) | ✅ [2/3](seaweedfs-4.48-k8s.md#auth-anonymous-sts) |
| P1 | Consistency | ✅ [9/9](ref-aws.md#consistency) | ✅ [9/9](ref-garage-v1.0.1.md#consistency) | ✅ [9/9](ref-minio.md#consistency) | ✅ [9/9](ref-seaweedfs-4.13.md#consistency) | ✅ [9/9](seaweedfs-4.48-k8s.md#consistency) |
| P1 | Data Integrity | ✅ [8/8](ref-aws.md#data-integrity) | ✅ [8/8](ref-garage-v1.0.1.md#data-integrity) | ✅ [8/8](ref-minio.md#data-integrity) | ⚠️ [7/8](ref-seaweedfs-4.13.md#data-integrity) | ✅ [8/8](seaweedfs-4.48-k8s.md#data-integrity) |
| P1 | Large Objects | ✅ [6/6](ref-aws.md#large-objects) | ⚠️ [5/6](ref-garage-v1.0.1.md#large-objects) | ✅ [6/6](ref-minio.md#large-objects) | ✅ [6/6](ref-seaweedfs-4.13.md#large-objects) | ✅ [6/6](seaweedfs-4.48-k8s.md#large-objects) |
| P2 | ACLs | ✅ [9/9](ref-aws.md#acls) | ❌ [0/9](ref-garage-v1.0.1.md#acls) | ⚠️ [4/9](ref-minio.md#acls) | ✅ [9/9](ref-seaweedfs-4.13.md#acls) | ✅ [9/9](seaweedfs-4.48-k8s.md#acls) |
| P2 | Bucket Policy | ✅ [6/6](ref-aws.md#bucket-policy) | ❌ [0/6](ref-garage-v1.0.1.md#bucket-policy) | ⚠️ [1/6](ref-minio.md#bucket-policy) | ✅ [6/6](ref-seaweedfs-4.13.md#bucket-policy) | ✅ [6/6](seaweedfs-4.48-k8s.md#bucket-policy) |
| P2 | Object Lock (WORM) | ✅ [8/8](ref-aws.md#object-lock-worm) | ❌ [0/8](ref-garage-v1.0.1.md#object-lock-worm) | ✅ [8/8](ref-minio.md#object-lock-worm) | ✅ [8/8](ref-seaweedfs-4.13.md#object-lock-worm) | ✅ [8/8](seaweedfs-4.48-k8s.md#object-lock-worm) |
| P2 | Website Hosting | ✅ [5/5](ref-aws.md#website-hosting) | ⚠️ [1/5](ref-garage-v1.0.1.md#website-hosting) | ⚠️ [1/5](ref-minio.md#website-hosting) | ❌ [0/5](ref-seaweedfs-4.13.md#website-hosting) | ⚠️ [1/5](seaweedfs-4.48-k8s.md#website-hosting) |
| P2 | Notifications | ✅ [2/3](ref-aws.md#notifications) | ❌ [0/3](ref-garage-v1.0.1.md#notifications) | ⚠️ [2/3](ref-minio.md#notifications) | ⚠️ [1/3](ref-seaweedfs-4.13.md#notifications) | ⚠️ [1/3](seaweedfs-4.48-k8s.md#notifications) |
| P2 | Logging | ✅ [3/3](ref-aws.md#logging) | ❌ [0/3](ref-garage-v1.0.1.md#logging) | ⚠️ [1/3](ref-minio.md#logging) | ⚠️ [1/3](ref-seaweedfs-4.13.md#logging) | ⚠️ [1/3](seaweedfs-4.48-k8s.md#logging) |
| P3 | Replication | ✅ [1/3](ref-aws.md#replication) | ❌ [0/3](ref-garage-v1.0.1.md#replication) | ✅ [1/3](ref-minio.md#replication) | ❌ [0/3](ref-seaweedfs-4.13.md#replication) | ⚠️ [1/3](seaweedfs-4.48-k8s.md#replication) |
| P3 | Inventory | ✅ [3/3](ref-aws.md#inventory) | ❌ [0/3](ref-garage-v1.0.1.md#inventory) | ❌ [0/3](ref-minio.md#inventory) | ❌ [0/3](ref-seaweedfs-4.13.md#inventory) | ❌ [0/3](seaweedfs-4.48-k8s.md#inventory) |
| P3 | Intelligent Tiering | ✅ [3/3](ref-aws.md#intelligent-tiering) | ❌ [0/3](ref-garage-v1.0.1.md#intelligent-tiering) | ❌ [0/3](ref-minio.md#intelligent-tiering) | ❌ [0/3](ref-seaweedfs-4.13.md#intelligent-tiering) | ❌ [0/3](seaweedfs-4.48-k8s.md#intelligent-tiering) |

✅ = all tests pass &emsp; ⚠️ = partial (some pass) &emsp; ❌ = all tests fail &emsp; ⬜ = not tested

See also: [Extended Compatibility Matrix](../results_extended/matrix.md) (concurrency, atomicity, edge cases)

*Generated 2026-10-22*
