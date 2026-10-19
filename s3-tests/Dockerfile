# Containerized Ceph s3-tests (https://github.com/ceph/s3-tests).
# Built + run by `just s3-tests` — no host Python install needed.
#
# s3-tests is a large granular S3 API conformance suite (boto3-based). We run it
# against the SeaweedFS S3 gateway to get per-test pass/fail (unlike Mint's
# stop-at-first-failure summary).
FROM python:3.11-slim

# Pin the s3-tests revision for reproducibility. Override with:
#   docker build --build-arg S3TESTS_REF=<sha> ...
# 5522d1c (2026-05-27) is the revision both the SeaweedFS and Garage labs were
# benchmarked against, so results stay comparable across candidates.
# NOTE: as of 2026-10-12 ceph/s3-tests is retired — the suite moved into the
# ceph/ceph repo and this repo is no longer maintained. Moving to a newer
# revision means sourcing it from ceph/ceph (and re-baselining every candidate).
ARG S3TESTS_REF=5522d1c351f75bc00ae0f64f742f3f095f5939d9

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ceph/s3-tests.git /s3-tests
WORKDIR /s3-tests
RUN git checkout "${S3TESTS_REF}" \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir -e . \
    && pip install --no-cache-dir pytest-forked   # per-test process isolation

# Root-level conftest bounds botocore socket timeouts so a hung request fails
# fast and its dead connection is discarded — prevents cross-test cascades.
COPY conftest.py /s3-tests/conftest.py

# Config is mounted at run time and pointed to via S3TEST_CONF.
ENTRYPOINT ["pytest"]
