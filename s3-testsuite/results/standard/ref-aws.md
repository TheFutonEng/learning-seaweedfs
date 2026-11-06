# ref-aws — S3 Compatibility Details

**Score: 203/207 (98%)**
 · [← back to matrix](matrix.md)

**P0**: 79/79 &ensp;|  **P1**: 84/85 &ensp;|  **P2**: 33/34 &ensp;|  **P3**: 7/9

| Priority | Feature Area | Result |
|:---:|---|:---:|
| P0 | [Bucket CRUD](#bucket-crud) | ✅ 11/11 |
| P0 | [Object CRUD](#object-crud) | ✅ 28/28 |
| P0 | [Object Listing](#object-listing) | ✅ 14/14 |
| P0 | [Multipart Upload](#multipart-upload) | ✅ 9/9 |
| P0 | [Presigned URLs](#presigned-urls) | ✅ 5/5 |
| P0 | [Error Handling](#error-handling) | ✅ 12/12 |
| P1 | [Versioning](#versioning) | ✅ 14/14 |
| P1 | [Object Tagging](#object-tagging) | ✅ 8/8 |
| P1 | [Bucket Tagging](#bucket-tagging) | ✅ 4/4 |
| P1 | [Server-Side Encryption](#server-side-encryption) | ✅ 10/10 |
| P1 | [Lifecycle Config](#lifecycle-config) | ✅ 8/8 |
| P1 | [CORS](#cors) | ✅ 5/5 |
| P1 | [Content Type & Metadata](#content-type-metadata) | ✅ 10/10 |
| P1 | [Auth (Anonymous + STS)](#auth-anonymous-sts) | ✅ 2/3 |
| P1 | [Consistency](#consistency) | ✅ 9/9 |
| P1 | [Data Integrity](#data-integrity) | ✅ 8/8 |
| P1 | [Large Objects](#large-objects) | ✅ 6/6 |
| P2 | [ACLs](#acls) | ✅ 9/9 |
| P2 | [Bucket Policy](#bucket-policy) | ✅ 6/6 |
| P2 | [Object Lock (WORM)](#object-lock-worm) | ✅ 8/8 |
| P2 | [Website Hosting](#website-hosting) | ✅ 5/5 |
| P2 | [Notifications](#notifications) | ✅ 2/3 |
| P2 | [Logging](#logging) | ✅ 3/3 |
| P3 | [Replication](#replication) | ✅ 1/3 |
| P3 | [Inventory](#inventory) | ✅ 3/3 |
| P3 | [Intelligent Tiering](#intelligent-tiering) | ✅ 3/3 |

---

## Bucket CRUD
**11/11** tests passing

- ✅ `test_create_and_delete`
- ✅ `test_create_bucket_already_exists`
- ✅ `test_create_bucket_invalid_name_too_short`
- ✅ `test_create_bucket_invalid_name_uppercase`
- ✅ `test_delete_nonexistent_bucket`
- ✅ `test_delete_nonempty_bucket`
- ✅ `test_head_existing`
- ✅ `test_head_nonexistent`
- ✅ `test_list_includes_created_bucket`
- ✅ `test_list_buckets_has_creation_date`
- ✅ `test_get_location`

## Object CRUD
**28/28** tests passing

- ✅ `test_put_get_small_object`
- ✅ `test_put_get_empty_object`
- ✅ `test_put_get_binary_data`
- ✅ `test_put_overwrite`
- ✅ `test_get_nonexistent_key`
- ✅ `test_range_read_start`
- ✅ `test_range_read_middle`
- ✅ `test_range_read_suffix`
- ✅ `test_range_read_to_end`
- ✅ `test_head_returns_metadata`
- ✅ `test_head_nonexistent`
- ✅ `test_delete_existing`
- ✅ `test_delete_nonexistent_is_idempotent`
- ✅ `test_bulk_delete`
- ✅ `test_bulk_delete_partial_nonexistent`
- ✅ `test_copy_same_bucket`
- ✅ `test_copy_cross_bucket`
- ✅ `test_copy_preserves_content_type`
- ✅ `test_put_with_correct_md5`
- ✅ `test_put_with_wrong_md5_is_rejected`
- ✅ `test_special_key_roundtrip[simple]`
- ✅ `test_special_key_roundtrip[with spaces]`
- ✅ `test_special_key_roundtrip[with/slashes/nested]`
- ✅ `test_special_key_roundtrip[with.dots.ext]`
- ✅ `test_special_key_roundtrip[with-dashes]`
- ✅ `test_special_key_roundtrip[with_underscores]`
- ✅ `test_special_key_roundtrip[unicode-\xe9\xe8\xea]`
- ✅ `test_special_key_roundtrip[deep/nested/path/to/object.txt]`

## Object Listing
**14/14** tests passing

- ✅ `test_list_empty_bucket`
- ✅ `test_list_returns_all_objects`
- ✅ `test_list_with_prefix`
- ✅ `test_list_with_prefix_no_match`
- ✅ `test_list_with_delimiter`
- ✅ `test_list_with_prefix_and_delimiter`
- ✅ `test_list_returns_sorted_keys`
- ✅ `test_max_keys`
- ✅ `test_pagination_complete`
- ✅ `test_pagination_over_1000_objects`
- ✅ `test_list_v1_basic`
- ✅ `test_list_v1_with_marker_pagination`
- ✅ `test_list_v1_with_delimiter`
- ✅ `test_list_includes_etag_and_size`

## Multipart Upload
**9/9** tests passing

- ✅ `test_create_complete_multipart`
- ✅ `test_create_multipart_with_content_type`
- ✅ `test_complete_multipart_data_integrity`
- ✅ `test_last_part_smaller_than_5mb`
- ✅ `test_abort_multipart`
- ✅ `test_list_in_progress_uploads`
- ✅ `test_list_empty_after_abort`
- ✅ `test_list_uploaded_parts`
- ✅ `test_upload_part_copy`

## Presigned URLs
**5/5** tests passing

- ✅ `test_presigned_get`
- ✅ `test_presigned_get_with_content_type`
- ✅ `test_presigned_put`
- ✅ `test_presigned_delete`
- ✅ `test_expired_url_rejected`

## Error Handling
**12/12** tests passing

- ✅ `test_no_such_bucket`
- ✅ `test_no_such_key`
- ✅ `test_bucket_not_empty`
- ✅ `test_no_such_upload`
- ✅ `test_404_for_missing_object`
- ✅ `test_404_for_missing_bucket`
- ✅ `test_409_bucket_not_empty`
- ✅ `test_if_match_success`
- ✅ `test_if_match_failure`
- ✅ `test_if_none_match_returns_304`
- ✅ `test_if_modified_since`
- ✅ `test_if_unmodified_since_failure`

## Versioning
**14/14** tests passing

- ✅ `test_enable_versioning`
- ✅ `test_suspend_versioning`
- ✅ `test_versioning_initially_unset`
- ✅ `test_put_returns_version_id`
- ✅ `test_multiple_versions`
- ✅ `test_get_specific_version`
- ✅ `test_get_latest_version`
- ✅ `test_head_specific_version`
- ✅ `test_delete_creates_marker`
- ✅ `test_get_after_delete_marker_returns_404`
- ✅ `test_delete_specific_version_permanent`
- ✅ `test_list_versions`
- ✅ `test_list_includes_delete_markers`
- ✅ `test_list_versions_with_prefix`

## Object Tagging
**8/8** tests passing

- ✅ `test_put_and_get_tags`
- ✅ `test_delete_tags`
- ✅ `test_replace_tags`
- ✅ `test_max_10_tags`
- ✅ `test_get_tags_no_tags`
- ✅ `test_tags_via_header`
- ✅ `test_copy_preserves_tags_by_default`
- ✅ `test_copy_replace_tags`

## Bucket Tagging
**4/4** tests passing

- ✅ `test_put_and_get_tags`
- ✅ `test_delete_tags`
- ✅ `test_replace_tags`
- ✅ `test_no_tags_returns_error`

## Server-Side Encryption
**10/10** tests passing

- ✅ `test_put_with_sse_s3`
- ✅ `test_get_sse_s3_transparent`
- ✅ `test_copy_preserves_sse_s3`
- ✅ `test_set_default_encryption_aes256`
- ✅ `test_delete_bucket_encryption`
- ✅ `test_put_get_with_sse_c`
- ✅ `test_get_sse_c_without_key_fails`
- ✅ `test_get_sse_c_with_wrong_key_fails`
- ✅ `test_head_sse_c_requires_key`
- ✅ `test_copy_sse_c`

## Lifecycle Config
**8/8** tests passing

- ✅ `test_put_and_get_lifecycle`
- ✅ `test_delete_lifecycle`
- ✅ `test_no_lifecycle_returns_error`
- ✅ `test_expiration_by_days`
- ✅ `test_abort_incomplete_multipart`
- ✅ `test_multiple_rules`
- ✅ `test_disabled_rule`
- ✅ `test_filter_by_tag`

## CORS
**5/5** tests passing

- ✅ `test_put_and_get_cors`
- ✅ `test_delete_cors`
- ✅ `test_no_cors_returns_error`
- ✅ `test_multiple_cors_rules`
- ✅ `test_options_preflight`

## Content Type & Metadata
**10/10** tests passing

- ✅ `test_set_and_retrieve_content_type`
- ✅ `test_default_content_type`
- ✅ `test_content_disposition`
- ✅ `test_content_encoding`
- ✅ `test_cache_control`
- ✅ `test_custom_metadata`
- ✅ `test_metadata_preserved_on_get`
- ✅ `test_empty_metadata_value`
- ✅ `test_copy_preserves_metadata`
- ✅ `test_copy_replace_metadata`

## Auth (Anonymous + STS)
**2/3** tests passing

- ✅ `test_anonymous_read_with_public_policy`
- ✅ `test_anonymous_access_denied_without_policy`
- ⬜ `test_assume_role_basic` — STS AssumeRole not supported: An error occurred (AccessDenied) when calling the AssumeRole operation: User: arn:aws:iam:

## Consistency
**9/9** tests passing

- ✅ `test_immediate_read_after_put`
- ✅ `test_immediate_head_after_put`
- ✅ `test_immediate_list_after_put`
- ✅ `test_immediate_get_after_delete`
- ✅ `test_immediate_head_after_delete`
- ✅ `test_immediate_list_after_delete`
- ✅ `test_immediate_read_after_overwrite`
- ✅ `test_concurrent_puts_all_succeed`
- ✅ `test_concurrent_puts_to_different_keys`

## Data Integrity
**8/8** tests passing

- ✅ `test_etag_is_md5_for_simple_put`
- ✅ `test_etag_consistent_across_get_and_head`
- ✅ `test_etag_changes_on_overwrite`
- ✅ `test_multipart_etag_format`
- ✅ `test_correct_md5_accepted`
- ✅ `test_wrong_md5_rejected`
- ✅ `test_copy_produces_new_etag`
- ✅ `test_etag_in_list_matches_head`

## Large Objects
**6/6** tests passing

- ✅ `test_put_10mb`
- ✅ `test_put_50mb`
- ✅ `test_put_50mb_integrity`
- ✅ `test_multipart_10_parts`
- ✅ `test_multipart_varying_part_sizes`
- ✅ `test_range_read_middle_of_large_object`

## ACLs
**9/9** tests passing

- ✅ `test_get_default_bucket_acl`
- ✅ `test_put_bucket_acl_private`
- ✅ `test_put_bucket_acl_public_read`
- ✅ `test_get_default_object_acl`
- ✅ `test_put_object_acl_private`
- ✅ `test_put_object_acl_public_read`
- ✅ `test_private_on_upload`
- ✅ `test_public_read_on_upload`
- ✅ `test_bucket_owner_full_control_on_upload`

## Bucket Policy
**6/6** tests passing

- ✅ `test_put_and_get_policy`
- ✅ `test_delete_policy`
- ✅ `test_no_policy_returns_error`
- ✅ `test_replace_policy`
- ✅ `test_public_read_policy`
- ✅ `test_deny_policy`

## Object Lock (WORM)
**8/8** tests passing

- ✅ `test_get_lock_config`
- ✅ `test_set_default_retention`
- ✅ `test_set_and_get_retention`
- ✅ `test_cannot_delete_retained_object`
- ✅ `test_governance_bypass`
- ✅ `test_set_and_get_legal_hold`
- ✅ `test_remove_legal_hold`
- ✅ `test_cannot_delete_with_legal_hold`

## Website Hosting
**5/5** tests passing

- ✅ `test_put_and_get_website_config`
- ✅ `test_delete_website_config`
- ✅ `test_no_website_config_returns_error`
- ✅ `test_website_with_redirect_rules`
- ✅ `test_website_redirect_all`

## Notifications
**2/3** tests passing

- ✅ `test_get_empty_notification_config`
- ⬜ `test_put_and_get_notification_config` — Provider validates notification destination ARNs exist
- ✅ `test_clear_notification_config`

## Logging
**3/3** tests passing

- ✅ `test_get_logging_default_empty`
- ✅ `test_put_and_get_logging`
- ✅ `test_disable_logging`

## Replication
**1/3** tests passing

- ⬜ `test_put_and_get_replication` — Provider requires valid replication infrastructure (AccessDenied)
- ⬜ `test_delete_replication` — Provider requires valid replication infrastructure (AccessDenied)
- ✅ `test_no_replication_returns_error`

## Inventory
**3/3** tests passing

- ✅ `test_put_and_get_inventory`
- ✅ `test_list_inventory_configs`
- ✅ `test_delete_inventory`

## Intelligent Tiering
**3/3** tests passing

- ✅ `test_put_and_get_tiering`
- ✅ `test_list_tiering_configs`
- ✅ `test_delete_tiering`

