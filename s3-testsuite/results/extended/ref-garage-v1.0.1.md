# ref-garage-v1.0.1 — S3 Extended Compatibility Details

**Score: 48/63 (76%)**
 · [← back to matrix](matrix.md)

**P0**: 19/19 &ensp;|  **P1**: 24/34 &ensp;|  **P2**: 5/10

| Priority | Feature Area | Result |
|:---:|---|:---:|
| P0 | [Concurrent Read/Write/Delete](#concurrent-read/write/delete) | ✅ 7/7 |
| P0 | [Overwrite Atomicity](#overwrite-atomicity) | ✅ 6/6 |
| P0 | [Listing Consistency](#listing-consistency) | ✅ 6/6 |
| P1 | [Concurrent Versioning](#concurrent-versioning) | ❌ 0/7 |
| P1 | [Multipart Edge Cases](#multipart-edge-cases) | ⚠️ 7/8 |
| P1 | [Namespace Isolation](#namespace-isolation) | ✅ 6/6 |
| P1 | [Large-Scale Listing](#large-scale-listing) | ✅ 6/6 |
| P1 | [Conditional Operations](#conditional-operations) | ⚠️ 5/7 |
| P2 | [Object Lock Contention](#object-lock-contention) | ❌ 0/5 |
| P2 | [Bulk Throughput](#bulk-throughput) | ✅ 5/5 |

---

## Concurrent Read/Write/Delete
**7/7** tests passing

- ✅ `test_read_during_overwrite_returns_complete_version`
- ✅ `test_concurrent_put_delete_same_key`
- ✅ `test_concurrent_writes_to_different_keys_no_interference`
- ✅ `test_concurrent_deletes_same_key`
- ✅ `test_concurrent_put_during_bulk_delete`
- ✅ `test_concurrent_reads_return_same_content`
- ✅ `test_concurrent_head_returns_consistent_metadata`

## Overwrite Atomicity
**6/6** tests passing

- ✅ `test_overwrite_never_returns_partial_data`
- ✅ `test_overwrite_content_length_matches_body`
- ✅ `test_overwrite_etag_matches_body`
- ✅ `test_overwrite_larger_with_smaller`
- ✅ `test_overwrite_smaller_with_larger`
- ✅ `test_rapid_size_alternation`

## Listing Consistency
**6/6** tests passing

- ✅ `test_list_sees_all_objects_after_concurrent_puts`
- ✅ `test_list_after_rapid_delete_shows_no_phantoms`
- ✅ `test_paginated_list_during_inserts`
- ✅ `test_list_always_lexicographic_after_concurrent_puts`
- ✅ `test_prefix_filter_correctness_after_concurrent_writes`
- ✅ `test_delimiter_correctness_after_concurrent_writes`

## Concurrent Versioning
**0/7** tests passing

- 💥 `test_concurrent_puts_create_distinct_versions` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_version_ordering_matches_write_order` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_all_versions_readable_after_concurrent_writes` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_delete_one_version_leaves_others_intact` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_concurrent_version_deletes` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_concurrent_delete_markers` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_write_after_delete_marker` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers

## Multipart Edge Cases
**7/8** tests passing

- ✅ `test_complete_with_subset_of_uploaded_parts`
- ✅ `test_overwrite_part_number`
- ✅ `test_complete_with_parts_in_ascending_order`
- ✅ `test_concurrent_part_uploads`
- ✅ `test_multiple_concurrent_multipart_uploads_same_key`
- ✅ `test_abandoned_upload_not_visible_as_object`
- ❌ `test_abort_idempotent` — botocore.errorfactory.NoSuchUpload: An error occurred (NoSuchUpload) when calling the AbortMultipartUpload operation: Up
- ✅ `test_complete_with_invalid_upload_id`

## Namespace Isolation
**6/6** tests passing

- ✅ `test_write_to_bucket_a_not_visible_in_bucket_b`
- ✅ `test_same_key_different_content_in_two_buckets`
- ✅ `test_delete_in_bucket_a_does_not_affect_bucket_b`
- ✅ `test_prefix_substring_keys_are_distinct`
- ✅ `test_keys_differing_only_by_trailing_slash`
- ✅ `test_keys_with_special_chars_are_distinct`

## Large-Scale Listing
**6/6** tests passing

- ✅ `test_paginate_10k_objects_returns_all`
- ✅ `test_paginate_10k_objects_in_order`
- ✅ `test_max_keys_boundary_at_1000`
- ✅ `test_prefix_filter_on_large_bucket`
- ✅ `test_start_after_on_large_bucket`
- ✅ `test_large_list_key_count_accuracy`

## Conditional Operations
**5/7** tests passing

- ✅ `test_get_with_matching_etag_succeeds`
- ❌ `test_get_with_non_matching_etag_fails` — Failed: IfMatch with wrong ETag should return 412
- ✅ `test_copy_if_match`
- ✅ `test_get_if_none_match_returns_304`
- ✅ `test_get_if_none_match_with_old_etag_succeeds`
- ✅ `test_get_if_modified_since_future_returns_304`
- ❌ `test_get_if_unmodified_since_past_returns_412` — Failed: IfUnmodifiedSince with past date should return 412

## Object Lock Contention
**0/5** tests passing

- ❌ `test_concurrent_retention_set_on_same_object` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectRetention operation: Unimp
- ❌ `test_concurrent_delete_of_retained_object` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectRetention operation: Unimp
- ❌ `test_concurrent_legal_hold_toggle` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectLegalHold operation: Unimp
- ❌ `test_lock_specific_version_while_creating_new_versions` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectRetention operation: Unimp
- ❌ `test_governance_bypass_under_contention` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectRetention operation: Unimp

## Bulk Throughput
**5/5** tests passing

- ✅ `test_100_parallel_puts_all_succeed`
- ✅ `test_100_parallel_gets_all_succeed`
- ✅ `test_50_parallel_copies`
- ✅ `test_10_concurrent_multipart_uploads`
- ✅ `test_parallel_put_and_list`

