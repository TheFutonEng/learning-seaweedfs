# ref-garage-v1.0.1 — S3 Compatibility Details

**Score: 121/207 (58%)**
 · [← back to matrix](matrix.md)

**P0**: 73/79 &ensp;|  **P1**: 47/85 &ensp;|  **P2**: 1/34 &ensp;|  **P3**: 0/9

| Priority | Feature Area | Result |
|:---:|---|:---:|
| P0 | [Bucket CRUD](#bucket-crud) | ✅ 11/11 |
| P0 | [Object CRUD](#object-crud) | ⚠️ 24/28 |
| P0 | [Object Listing](#object-listing) | ✅ 14/14 |
| P0 | [Multipart Upload](#multipart-upload) | ✅ 9/9 |
| P0 | [Presigned URLs](#presigned-urls) | ✅ 5/5 |
| P0 | [Error Handling](#error-handling) | ⚠️ 10/12 |
| P1 | [Versioning](#versioning) | ⚠️ 1/14 |
| P1 | [Object Tagging](#object-tagging) | ❌ 0/8 |
| P1 | [Bucket Tagging](#bucket-tagging) | ❌ 0/4 |
| P1 | [Server-Side Encryption](#server-side-encryption) | ⚠️ 6/10 |
| P1 | [Lifecycle Config](#lifecycle-config) | ⚠️ 5/8 |
| P1 | [CORS](#cors) | ⚠️ 3/5 |
| P1 | [Content Type & Metadata](#content-type-metadata) | ⚠️ 9/10 |
| P1 | [Auth (Anonymous + STS)](#auth-anonymous-sts) | ⚠️ 1/3 |
| P1 | [Consistency](#consistency) | ✅ 9/9 |
| P1 | [Data Integrity](#data-integrity) | ✅ 8/8 |
| P1 | [Large Objects](#large-objects) | ⚠️ 5/6 |
| P2 | [ACLs](#acls) | ❌ 0/9 |
| P2 | [Bucket Policy](#bucket-policy) | ❌ 0/6 |
| P2 | [Object Lock (WORM)](#object-lock-worm) | ❌ 0/8 |
| P2 | [Website Hosting](#website-hosting) | ⚠️ 1/5 |
| P2 | [Notifications](#notifications) | ❌ 0/3 |
| P2 | [Logging](#logging) | ❌ 0/3 |
| P3 | [Replication](#replication) | ❌ 0/3 |
| P3 | [Inventory](#inventory) | ❌ 0/3 |
| P3 | [Intelligent Tiering](#intelligent-tiering) | ❌ 0/3 |

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
**24/28** tests passing

- ✅ `test_put_get_small_object`
- ✅ `test_put_get_empty_object`
- ✅ `test_put_get_binary_data`
- ✅ `test_put_overwrite`
- ✅ `test_get_nonexistent_key`
- ❌ `test_range_read_start` — botocore.exceptions.FlexibleChecksumError: Expected checksum poTHxg== did not match calculated checksum: 3aRwJA==
- ❌ `test_range_read_middle` — botocore.exceptions.FlexibleChecksumError: Expected checksum poTHxg== did not match calculated checksum: TOtJvA==
- ❌ `test_range_read_suffix` — botocore.exceptions.FlexibleChecksumError: Expected checksum poTHxg== did not match calculated checksum: lv8e9A==
- ❌ `test_range_read_to_end` — botocore.exceptions.FlexibleChecksumError: Expected checksum poTHxg== did not match calculated checksum: lv8e9A==
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
**10/12** tests passing

- ✅ `test_no_such_bucket`
- ✅ `test_no_such_key`
- ✅ `test_bucket_not_empty`
- ✅ `test_no_such_upload`
- ✅ `test_404_for_missing_object`
- ✅ `test_404_for_missing_bucket`
- ✅ `test_409_bucket_not_empty`
- ✅ `test_if_match_success`
- ❌ `test_if_match_failure` — Failed: DID NOT RAISE <class 'botocore.exceptions.ClientError'>
- ✅ `test_if_none_match_returns_304`
- ✅ `test_if_modified_since`
- ❌ `test_if_unmodified_since_failure` — Failed: DID NOT RAISE <class 'botocore.exceptions.ClientError'>

## Versioning
**1/14** tests passing

- ❌ `test_enable_versioning` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVersioning operation: Unim
- ❌ `test_suspend_versioning` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVersioning operation: Unim
- ✅ `test_versioning_initially_unset`
- 💥 `test_put_returns_version_id` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_multiple_versions` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_get_specific_version` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_get_latest_version` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_head_specific_version` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_delete_creates_marker` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_get_after_delete_marker_returns_404` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_delete_specific_version_permanent` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_list_versions` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_list_includes_delete_markers` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_list_versions_with_prefix` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers

## Object Tagging
**0/8** tests passing

- ❌ `test_put_and_get_tags` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectTagging operation: Unimple
- ❌ `test_delete_tags` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectTagging operation: Unimple
- ❌ `test_replace_tags` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectTagging operation: Unimple
- ❌ `test_max_10_tags` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectTagging operation: Unimple
- ❌ `test_get_tags_no_tags` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the GetObjectTagging operation: Unimple
- ❌ `test_tags_via_header` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the GetObjectTagging operation: Unimple
- ❌ `test_copy_preserves_tags_by_default` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectTagging operation: Unimple
- ❌ `test_copy_replace_tags` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectTagging operation: Unimple

## Bucket Tagging
**0/4** tests passing

- ❌ `test_put_and_get_tags` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketTagging operation: Unimple
- ❌ `test_delete_tags` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketTagging operation: Unimple
- ❌ `test_replace_tags` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketTagging operation: Unimple
- ❌ `test_no_tags_returns_error` — AssertionError: expected error code NoSuchTagSet, got 'NotImplemented'

## Server-Side Encryption
**6/10** tests passing

- ❌ `test_put_with_sse_s3` — assert None == 'AES256'
- ✅ `test_get_sse_s3_transparent`
- ❌ `test_copy_preserves_sse_s3` — assert None == 'AES256'
- ❌ `test_set_default_encryption_aes256` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketEncryption operation: Unim
- ❌ `test_delete_bucket_encryption` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketEncryption operation: Unim
- ✅ `test_put_get_with_sse_c`
- ✅ `test_get_sse_c_without_key_fails`
- ✅ `test_get_sse_c_with_wrong_key_fails`
- ✅ `test_head_sse_c_requires_key`
- ✅ `test_copy_sse_c`

## Lifecycle Config
**5/8** tests passing

- ✅ `test_put_and_get_lifecycle`
- ❌ `test_delete_lifecycle` — Failed: get_bucket_lifecycle_configuration succeeded after delete (expected NoSuchLifecycleConfiguration error)
- ❌ `test_no_lifecycle_returns_error` — Failed: DID NOT RAISE <class 'botocore.exceptions.ClientError'>
- ✅ `test_expiration_by_days`
- ✅ `test_abort_incomplete_multipart`
- ✅ `test_multiple_rules`
- ✅ `test_disabled_rule`
- ❌ `test_filter_by_tag` — AssertionError: expected 'Filter' key in rule, got keys: ['Expiration', 'ID', 'Status']

## CORS
**3/5** tests passing

- ✅ `test_put_and_get_cors`
- ❌ `test_delete_cors` — Failed: get_bucket_cors succeeded after delete (expected NoSuchCORSConfiguration error)
- ❌ `test_no_cors_returns_error` — Failed: get_bucket_cors on unconfigured bucket returned 0 rules (expected NoSuchCORSConfiguration error)
- ✅ `test_multiple_cors_rules`
- ✅ `test_options_preflight`

## Content Type & Metadata
**9/10** tests passing

- ✅ `test_set_and_retrieve_content_type`
- ❌ `test_default_content_type` — assert 'ContentType' in {'AcceptRanges': 'bytes', 'ContentLength': 4, 'ETag': '"8d777f385d3dfec8815d20f7496026dc"', 'Las
- ✅ `test_content_disposition`
- ✅ `test_content_encoding`
- ✅ `test_cache_control`
- ✅ `test_custom_metadata`
- ✅ `test_metadata_preserved_on_get`
- ✅ `test_empty_metadata_value`
- ✅ `test_copy_preserves_metadata`
- ✅ `test_copy_replace_metadata`

## Auth (Anonymous + STS)
**1/3** tests passing

- ❌ `test_anonymous_read_with_public_policy` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketPolicy operation: Unimplem
- ✅ `test_anonymous_access_denied_without_policy`
- ⬜ `test_assume_role_basic` — STS AssumeRole not supported: An error occurred (Unknown) when calling the AssumeRole operation: Unknown

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
**5/6** tests passing

- ✅ `test_put_10mb`
- ✅ `test_put_50mb`
- ✅ `test_put_50mb_integrity`
- ✅ `test_multipart_10_parts`
- ✅ `test_multipart_varying_part_sizes`
- ❌ `test_range_read_middle_of_large_object` — botocore.exceptions.FlexibleChecksumError: Expected checksum KxHXkQ== did not match calculated checksum: twtMJg==

## ACLs
**0/9** tests passing

- ❌ `test_get_default_bucket_acl` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the GetBucketAcl operation: Unimplement
- ❌ `test_put_bucket_acl_private` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketAcl operation: Unimplement
- ❌ `test_put_bucket_acl_public_read` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketAcl operation: Unimplement
- ❌ `test_get_default_object_acl` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the GetObjectAcl operation: Unimplement
- ❌ `test_put_object_acl_private` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectAcl operation: Unimplement
- ❌ `test_put_object_acl_public_read` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectAcl operation: Unimplement
- ❌ `test_private_on_upload` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the GetObjectAcl operation: Unimplement
- ❌ `test_public_read_on_upload` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the GetObjectAcl operation: Unimplement
- ❌ `test_bucket_owner_full_control_on_upload` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the GetObjectAcl operation: Unimplement

## Bucket Policy
**0/6** tests passing

- ❌ `test_put_and_get_policy` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketPolicy operation: Unimplem
- ❌ `test_delete_policy` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketPolicy operation: Unimplem
- ❌ `test_no_policy_returns_error` — AssertionError: expected error code NoSuchBucketPolicy or NoSuchPolicy, got 'NotImplemented'
- ❌ `test_replace_policy` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketPolicy operation: Unimplem
- ❌ `test_public_read_policy` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketPolicy operation: Unimplem
- ❌ `test_deny_policy` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketPolicy operation: Unimplem

## Object Lock (WORM)
**0/8** tests passing

- ❌ `test_get_lock_config` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the GetObjectLockConfiguration operatio
- ❌ `test_set_default_retention` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectLockConfiguration operatio
- ❌ `test_set_and_get_retention` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectRetention operation: Unimp
- ❌ `test_cannot_delete_retained_object` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectRetention operation: Unimp
- ❌ `test_governance_bypass` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectRetention operation: Unimp
- ❌ `test_set_and_get_legal_hold` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectLegalHold operation: Unimp
- ❌ `test_remove_legal_hold` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectLegalHold operation: Unimp
- ❌ `test_cannot_delete_with_legal_hold` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutObjectLegalHold operation: Unimp

## Website Hosting
**1/5** tests passing

- ✅ `test_put_and_get_website_config`
- ❌ `test_delete_website_config` — Failed: get_bucket_website succeeded after delete (expected NoSuchWebsiteConfiguration error)
- ❌ `test_no_website_config_returns_error` — Failed: get_bucket_website on unconfigured bucket succeeded (expected NoSuchWebsiteConfiguration error)
- ❌ `test_website_with_redirect_rules` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketWebsite operation: Unimple
- ❌ `test_website_redirect_all` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketWebsite operation: Unimple

## Notifications
**0/3** tests passing

- ❌ `test_get_empty_notification_config` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the GetBucketNotificationConfiguration 
- ❌ `test_put_and_get_notification_config` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketNotificationConfiguration 
- ❌ `test_clear_notification_config` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketNotificationConfiguration 

## Logging
**0/3** tests passing

- ❌ `test_get_logging_default_empty` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the GetBucketLogging operation: Unimple
- ❌ `test_put_and_get_logging` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketLogging operation: Unimple
- ❌ `test_disable_logging` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketLogging operation: Unimple

## Replication
**0/3** tests passing

- 💥 `test_put_and_get_replication` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- 💥 `test_delete_replication` — failed on setup with "botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketVers
- ❌ `test_no_replication_returns_error` — AssertionError: expected error code ReplicationConfigurationNotFoundError, got 'NotImplemented'

## Inventory
**0/3** tests passing

- ❌ `test_put_and_get_inventory` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketInventoryConfiguration ope
- ❌ `test_list_inventory_configs` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketInventoryConfiguration ope
- ❌ `test_delete_inventory` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketInventoryConfiguration ope

## Intelligent Tiering
**0/3** tests passing

- ❌ `test_put_and_get_tiering` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketIntelligentTieringConfigur
- ❌ `test_list_tiering_configs` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketIntelligentTieringConfigur
- ❌ `test_delete_tiering` — botocore.exceptions.ClientError: An error occurred (NotImplemented) when calling the PutBucketIntelligentTieringConfigur

