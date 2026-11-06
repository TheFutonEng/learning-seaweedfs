# Containerized third-party S3 compatibility suite
# (https://github.com/michalszynkiewicz/s3-testsuite). Built + run by
# `just s3-testsuite` — runs as a pod INSIDE the cluster, no port-forward.
#
# Complements Ceph s3-tests (s3-tests/): ~200 standard tests ranked P0-P3 by
# importance, plus a 63-test "extended" suite for concurrency, overwrite
# atomicity, listing consistency, 10K-object listing and bulk throughput. Its
# authors publish results for AWS, MinIO, SeaweedFS 4.13 and Garage, which we
# reuse as reference columns.
FROM python:3.11-slim

# Pin the suite revision for reproducibility. Override with:
#   docker build --build-arg SUITE_REF=<sha> ...
ARG SUITE_REF=ec150b9d1fe85e53659ce8ffdbd46b94b7c1e8e1

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/michalszynkiewicz/s3-testsuite.git /suite
WORKDIR /suite
RUN git checkout "${SUITE_REF}" \
    && pip install --no-cache-dir -r requirements.txt

# Provider config (providers/<name>.yaml) is mounted from a ConfigMap at run time.
ENTRYPOINT []
