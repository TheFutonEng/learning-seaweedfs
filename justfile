# SeaweedFS learning lab — environment & test automation.
# Run `just` (or `just --list`) to see available recipes.
#
# Conventions:
#   - Cluster is managed with k3d (see k3d/cluster.yaml).
#   - SeaweedFS is installed from the PUBLISHED Helm repo (not a local chart),
#     so anyone can use this repo without cloning the SeaweedFS source.
#   - The S3 client runs in a throwaway container via `docker run`, so no host
#     install of aws-cli / s3cmd / mc is required.

set shell := ["bash", "-uc"]

# --- Configuration -----------------------------------------------------------
cluster       := "seaweedfs-lab"
namespace     := "seaweedfs"
release       := "seaweedfs"
chart_repo    := "https://seaweedfs.github.io/seaweedfs/helm"
chart_version := "4.39.0"
s3_port       := "8333"
client_image  := "amazon/aws-cli:latest"
results_file  := "test-results.tsv"

# Local-lab-only throwaway S3 credentials. DO NOT reuse anywhere real.
# The admin creds must match the "admin" identity in k3d/s3-identities-secret.yaml.
s3_access_key := "seaweedadmin"
s3_secret_key := "lab-secret-change-me"

# Bucket-scoped "tenant" identities (also defined in k3d/s3-identities-secret.yaml).
tenant_a_key    := "tenant-a"
tenant_a_secret := "tenant-a-secret-change-me"
tenant_b_key    := "tenant-b"
tenant_b_secret := "tenant-b-secret-change-me"

# Show the list of recipes (default when running bare `just`).
default:
    @just --list

# === Environment lifecycle ===================================================

# Create the k3d cluster (idempotent-ish: errors if it already exists).
cluster-up:
    k3d cluster create --config k3d/cluster.yaml
    kubectl cluster-info

# Delete the k3d cluster and everything in it.
cluster-down:
    -k3d cluster delete {{cluster}}

# Install/upgrade SeaweedFS from the published Helm repo.
deploy:
    helm repo add seaweedfs {{chart_repo}}
    helm repo update seaweedfs
    # The s3 identity config secret must exist before the s3 pod starts, so we
    # ensure the namespace + secret first (Helm also --create-namespace's it).
    kubectl create namespace {{namespace}} --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f k3d/s3-identities-secret.yaml
    helm upgrade --install {{release}} seaweedfs/seaweedfs \
        --version {{chart_version}} \
        --namespace {{namespace}} --create-namespace \
        -f k3d/seaweedfs-values.yaml \
        --wait --timeout 5m
    @echo "SeaweedFS deployed. Try: just status"

# Uninstall the SeaweedFS release (leaves the cluster running).
undeploy:
    -helm uninstall {{release}} --namespace {{namespace}}

# Full bring-up: create cluster, then deploy SeaweedFS.
up: cluster-up deploy

# Full teardown: delete the cluster (removes the release too).
down: cluster-down

# === Inspection ==============================================================

# Show pods, services, PVCs, and statefulsets in the SeaweedFS namespace.
status:
    @echo "### Pods" && kubectl -n {{namespace}} get pods -o wide
    @echo "### Services" && kubectl -n {{namespace}} get svc
    @echo "### StatefulSets" && kubectl -n {{namespace}} get statefulset
    @echo "### PVCs" && kubectl -n {{namespace}} get pvc

# Tail logs for a component: master | filer | volume | s3  (e.g. `just logs filer`)
logs component="filer":
    kubectl -n {{namespace}} logs -l app.kubernetes.io/component={{component}} --tail=100 -f

# Open a `weed shell` session inside the master pod (cluster admin CLI).
weed-shell:
    kubectl -n {{namespace}} exec -it statefulset/{{release}}-master -- weed shell

# Port-forward the S3 gateway to localhost:8333 (foreground; Ctrl-C to stop).
port-forward-s3:
    @echo "S3 API available at http://localhost:{{s3_port}}  (Ctrl-C to stop)"
    kubectl -n {{namespace}} port-forward svc/{{release}}-s3 {{s3_port}}:{{s3_port}}

# Port-forward the master UI to localhost:9333 (foreground; Ctrl-C to stop).
port-forward-master:
    @echo "Master UI at http://localhost:9333  (Ctrl-C to stop)"
    kubectl -n {{namespace}} port-forward svc/{{release}}-master 9333:9333

# === Tests ===================================================================

# End-to-end S3 CRUD smoke test against the S3 gateway (containerized aws-cli).
s3-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    bucket="lab-smoke-$RANDOM"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    echo ">> Port-forwarding S3 gateway..."
    kubectl -n {{namespace}} port-forward svc/{{release}}-s3 {{s3_port}}:{{s3_port}} >"$tmp/pf.log" 2>&1 &
    pf=$!
    trap 'kill $pf 2>/dev/null || true; rm -rf "$tmp"' EXIT
    for _ in $(seq 1 30); do
        curl -s -o /dev/null "http://localhost:{{s3_port}}" && break || sleep 0.5
    done

    aws() {
        docker run --rm --network host \
            -e AWS_ACCESS_KEY_ID={{s3_access_key}} \
            -e AWS_SECRET_ACCESS_KEY={{s3_secret_key}} \
            -e AWS_EC2_METADATA_DISABLED=true \
            -v "$tmp:/data" \
            {{client_image}} \
            --endpoint-url "http://localhost:{{s3_port}}" --region us-east-1 "$@"
    }

    echo ">> Create bucket: $bucket"
    aws s3 mb "s3://$bucket"

    echo ">> Upload object"
    echo "hello seaweedfs @ $(date -u +%FT%TZ)" > "$tmp/hello.txt"
    aws s3 cp /data/hello.txt "s3://$bucket/hello.txt"

    echo ">> List bucket"
    aws s3 ls "s3://$bucket/"

    echo ">> Download object (round-trip)"
    aws s3 cp "s3://$bucket/hello.txt" /data/roundtrip.txt
    if diff -q "$tmp/hello.txt" "$tmp/roundtrip.txt" >/dev/null; then
        echo "   round-trip content matches ✅"
    else
        echo "   round-trip MISMATCH ❌"; exit 1
    fi

    echo ">> Cleanup: delete object + bucket"
    aws s3 rm "s3://$bucket/hello.txt"
    aws s3 rb "s3://$bucket"

    echo ">> s3-smoke PASSED ✅"

# Verify S3 auth is enforced: good creds allowed, bad creds + anonymous denied.
s3-auth-check:
    #!/usr/bin/env bash
    set -uo pipefail   # not -e: we deliberately expect some calls to fail
    tmp="$(mktemp -d)"
    kubectl -n {{namespace}} port-forward svc/{{release}}-s3 {{s3_port}}:{{s3_port}} >"$tmp/pf.log" 2>&1 &
    pf=$!
    trap 'kill $pf 2>/dev/null || true; rm -rf "$tmp"' EXIT
    for _ in $(seq 1 30); do curl -s -o /dev/null "http://localhost:{{s3_port}}" && break || sleep 0.5; done

    # Run `s3 ls` with the given access/secret key; extra args passed through.
    ls_with() {
        docker run --rm --network host \
            -e AWS_ACCESS_KEY_ID="$1" -e AWS_SECRET_ACCESS_KEY="$2" \
            -e AWS_EC2_METADATA_DISABLED=true \
            {{client_image}} \
            --endpoint-url "http://localhost:{{s3_port}}" --region us-east-1 s3 ls "${@:3}" 2>&1
    }
    denied_re='AccessDenied|Forbidden|403|InvalidAccessKeyId|SignatureDoesNotMatch'
    fail=0

    echo ">> 1) correct credentials — expect ALLOWED"
    if ls_with {{s3_access_key}} {{s3_secret_key}} >/dev/null; then echo "   ALLOWED ✅"; else echo "   unexpectedly DENIED ❌"; fail=1; fi

    echo ">> 2) wrong credentials — expect DENIED"
    out="$(ls_with wrong-key wrong-secret)"; rc=$?
    if [ $rc -eq 0 ]; then echo "   ALLOWED ❌ (auth not enforced!)"; fail=1
    elif echo "$out" | grep -qiE "$denied_re"; then echo "   DENIED ✅"
    else echo "   INCONCLUSIVE (non-auth error) ❌: $out"; fail=1; fi

    echo ">> 3) anonymous (unsigned) — expect DENIED"
    out="$(docker run --rm --network host -e AWS_EC2_METADATA_DISABLED=true {{client_image}} \
            --endpoint-url "http://localhost:{{s3_port}}" --region us-east-1 --no-sign-request s3 ls 2>&1)"; rc=$?
    if [ $rc -eq 0 ]; then echo "   ALLOWED ❌ (anonymous access open!)"; fail=1
    elif echo "$out" | grep -qiE "$denied_re"; then echo "   DENIED ✅"
    else echo "   INCONCLUSIVE (non-auth error) ❌: $out"; fail=1; fi

    [ $fail -eq 0 ] && echo ">> s3-auth-check PASSED ✅" || { echo ">> s3-auth-check FAILED ❌"; exit 1; }

# Bucket-scoped identity isolation: a tenant can use its own bucket, not another's (P1-08).
tenant-isolation-test:
    #!/usr/bin/env bash
    set -uo pipefail   # not -e: we deliberately expect some calls to be denied
    tmp="$(mktemp -d)"
    kubectl -n {{namespace}} port-forward svc/{{release}}-s3 {{s3_port}}:{{s3_port}} >"$tmp/pf.log" 2>&1 &
    pf=$!
    trap 'kill $pf 2>/dev/null || true; rm -rf "$tmp"' EXIT
    for _ in $(seq 1 30); do curl -s -o /dev/null "http://localhost:{{s3_port}}" && break || sleep 0.5; done
    echo "hello from a tenant" > "$tmp/obj.txt"
    denied_re='AccessDenied|Forbidden|403'
    fail=0

    # Run an aws-cli command as a given identity; prints combined output, returns rc.
    s3as() {
        local k="$1" s="$2"; shift 2
        docker run --rm --network host \
            -e AWS_ACCESS_KEY_ID="$k" -e AWS_SECRET_ACCESS_KEY="$s" \
            -e AWS_EC2_METADATA_DISABLED=true -v "$tmp:/data" \
            {{client_image}} \
            --endpoint-url "http://localhost:{{s3_port}}" --region us-east-1 "$@" 2>&1
    }
    expect_allowed() {
        local desc="$1"; shift
        local out rc; out="$("$@")"; rc=$?
        if [ $rc -eq 0 ]; then echo "   ALLOW ✅  $desc"
        else echo "   unexpected DENY ❌  $desc :: $out"; fail=1; fi
    }
    expect_denied() {
        local desc="$1"; shift
        local out rc; out="$("$@")"; rc=$?
        if [ $rc -eq 0 ]; then echo "   unexpected ALLOW ❌  $desc"; fail=1
        elif echo "$out" | grep -qiE "$denied_re"; then echo "   DENY  ✅  $desc"
        else echo "   INCONCLUSIVE ❌ (non-auth error)  $desc :: $out"; fail=1; fi
    }

    echo ">> admin creates bucket-a and bucket-b"
    s3as {{s3_access_key}} {{s3_secret_key}} s3 mb s3://bucket-a >/dev/null 2>&1 || true
    s3as {{s3_access_key}} {{s3_secret_key}} s3 mb s3://bucket-b >/dev/null 2>&1 || true

    echo ">> tenant-a on its OWN bucket-a (expect allowed)"
    expect_allowed "tenant-a PUT  bucket-a" s3as {{tenant_a_key}} {{tenant_a_secret}} s3 cp /data/obj.txt s3://bucket-a/obj.txt
    expect_allowed "tenant-a LIST bucket-a" s3as {{tenant_a_key}} {{tenant_a_secret}} s3 ls s3://bucket-a/
    expect_allowed "tenant-a GET  bucket-a" s3as {{tenant_a_key}} {{tenant_a_secret}} s3 cp s3://bucket-a/obj.txt /data/got.txt

    echo ">> tenant-a on the OTHER bucket-b (expect denied)"
    expect_denied  "tenant-a PUT  bucket-b" s3as {{tenant_a_key}} {{tenant_a_secret}} s3 cp /data/obj.txt s3://bucket-b/obj.txt
    expect_denied  "tenant-a LIST bucket-b" s3as {{tenant_a_key}} {{tenant_a_secret}} s3 ls s3://bucket-b/

    echo ">> tenant-b symmetric check"
    expect_allowed "tenant-b PUT  bucket-b" s3as {{tenant_b_key}} {{tenant_b_secret}} s3 cp /data/obj.txt s3://bucket-b/obj.txt
    expect_denied  "tenant-b PUT  bucket-a" s3as {{tenant_b_key}} {{tenant_b_secret}} s3 cp /data/obj.txt s3://bucket-a/obj.txt
    expect_denied  "tenant-b LIST bucket-a" s3as {{tenant_b_key}} {{tenant_b_secret}} s3 ls s3://bucket-a/

    echo ">> cleanup (admin removes tenant buckets)"
    s3as {{s3_access_key}} {{s3_secret_key}} s3 rm s3://bucket-a --recursive >/dev/null 2>&1 || true
    s3as {{s3_access_key}} {{s3_secret_key}} s3 rm s3://bucket-b --recursive >/dev/null 2>&1 || true
    s3as {{s3_access_key}} {{s3_secret_key}} s3 rb s3://bucket-a >/dev/null 2>&1 || true
    s3as {{s3_access_key}} {{s3_secret_key}} s3 rb s3://bucket-b >/dev/null 2>&1 || true

    [ $fail -eq 0 ] && echo ">> tenant-isolation-test PASSED ✅" || { echo ">> tenant-isolation-test FAILED ❌"; exit 1; }

# --- Phase 2: durability & storage ------------------------------------------

# Data survives a component restart + report S3 recovery time (P2-02/03/04).
restart-survives component="filer" timeout="330":
    #!/usr/bin/env bash
    set -uo pipefail
    tmp="$(mktemp -d)"; pf=""
    cleanup() { [ -n "$pf" ] && kill $pf 2>/dev/null; rm -rf "$tmp"; }
    trap cleanup EXIT
    start_pf() {
        [ -n "$pf" ] && kill $pf 2>/dev/null || true
        kubectl -n {{namespace}} port-forward svc/{{release}}-s3 {{s3_port}}:{{s3_port}} >"$tmp/pf.log" 2>&1 &
        pf=$!
        for _ in $(seq 1 30); do curl -s -o /dev/null "http://localhost:{{s3_port}}" && return 0; sleep 0.5; done
        return 1
    }
    aws() {
        docker run --rm --network host \
            -e AWS_ACCESS_KEY_ID={{s3_access_key}} -e AWS_SECRET_ACCESS_KEY={{s3_secret_key}} \
            -e AWS_EC2_METADATA_DISABLED=true -v "$tmp:/data" {{client_image}} \
            --endpoint-url "http://localhost:{{s3_port}}" --region us-east-1 "$@"
    }
    case "{{component}}" in
        s3)     target="deploy/{{release}}-s3" ;;
        master) target="statefulset/{{release}}-master" ;;
        filer)  target="statefulset/{{release}}-filer" ;;
        volume) target="statefulset/{{release}}-volume" ;;
        *) echo "unknown component '{{component}}' (use master|filer|volume|s3)"; exit 2 ;;
    esac

    bucket="durability"; marker="probe-$(date -u +%FT%TZ)-$RANDOM"
    echo ">> Seeding s3://$bucket/probe.txt"
    start_pf || { echo "initial port-forward failed"; exit 1; }
    aws s3 mb "s3://$bucket" >/dev/null 2>&1 || true
    echo "$marker" > "$tmp/probe.txt"
    aws s3 cp /data/probe.txt "s3://$bucket/probe.txt" >/dev/null

    echo ">> Restarting {{component}} ($target)"
    t0=$(date +%s)
    kubectl -n {{namespace}} rollout restart "$target" >/dev/null
    kubectl -n {{namespace}} rollout status "$target" --timeout=180s

    echo ">> Waiting for the S3 API to serve the object again (timeout {{timeout}}s)"
    ok=0
    while [ $(( $(date +%s) - t0 )) -lt {{timeout}} ]; do
        curl -s -o /dev/null "http://localhost:{{s3_port}}" || start_pf >/dev/null 2>&1 || true
        if aws s3 cp "s3://$bucket/probe.txt" /data/got.txt >/dev/null 2>&1; then ok=1; break; fi
        sleep 3
    done
    t1=$(date +%s)
    if [ $ok -eq 1 ] && [ "$(cat "$tmp/got.txt" 2>/dev/null)" = "$marker" ]; then
        echo ">> PASS ✅  data survived {{component}} restart; S3 recovered in $((t1-t0))s"
    else
        echo ">> FAIL ❌  object not recovered within {{timeout}}s (or content mismatch)"; exit 1
    fi

# Verify objects persist across a full uninstall + redeploy (PVCs retained). (P2-05)
redeploy-persists:
    #!/usr/bin/env bash
    set -uo pipefail
    tmp="$(mktemp -d)"; pf=""
    cleanup() { [ -n "$pf" ] && kill $pf 2>/dev/null; rm -rf "$tmp"; }
    trap cleanup EXIT
    start_pf() {
        [ -n "$pf" ] && kill $pf 2>/dev/null || true
        kubectl -n {{namespace}} port-forward svc/{{release}}-s3 {{s3_port}}:{{s3_port}} >"$tmp/pf.log" 2>&1 &
        pf=$!
        for _ in $(seq 1 30); do curl -s -o /dev/null "http://localhost:{{s3_port}}" && return 0; sleep 0.5; done
        return 1
    }
    aws() {
        docker run --rm --network host \
            -e AWS_ACCESS_KEY_ID={{s3_access_key}} -e AWS_SECRET_ACCESS_KEY={{s3_secret_key}} \
            -e AWS_EC2_METADATA_DISABLED=true -v "$tmp:/data" {{client_image}} \
            --endpoint-url "http://localhost:{{s3_port}}" --region us-east-1 "$@"
    }
    bucket="durability"; marker="persist-$(date -u +%FT%TZ)-$RANDOM"
    echo ">> Seeding s3://$bucket/persist.txt"
    start_pf || { echo "port-forward failed"; exit 1; }
    aws s3 mb "s3://$bucket" >/dev/null 2>&1 || true
    echo "$marker" > "$tmp/persist.txt"
    aws s3 cp /data/persist.txt "s3://$bucket/persist.txt" >/dev/null
    kill $pf 2>/dev/null; pf=""

    echo ">> helm uninstall (StatefulSet PVCs are retained by default)"
    helm uninstall {{release}} -n {{namespace}}
    kubectl -n {{namespace}} wait --for=delete pod -l app.kubernetes.io/name=seaweedfs --timeout=120s || true
    echo ">> PVCs still present:"
    kubectl -n {{namespace}} get pvc

    echo ">> Redeploying"
    just deploy

    echo ">> Reading the object back"
    start_pf || { echo "port-forward failed after redeploy"; exit 1; }
    if aws s3 cp "s3://$bucket/persist.txt" /data/got.txt >/dev/null 2>&1 && [ "$(cat "$tmp/got.txt")" = "$marker" ]; then
        echo ">> PASS ✅  object survived uninstall + redeploy"
    else
        echo ">> FAIL ❌  object missing or content mismatch after redeploy"; exit 1
    fi

# Verify a large (multipart) upload round-trips intact. (P2-06)
multipart-test size_mb="20":
    #!/usr/bin/env bash
    set -euo pipefail
    tmp="$(mktemp -d)"; pf=""
    cleanup() { [ -n "$pf" ] && kill $pf 2>/dev/null; rm -rf "$tmp"; }
    trap cleanup EXIT
    kubectl -n {{namespace}} port-forward svc/{{release}}-s3 {{s3_port}}:{{s3_port}} >"$tmp/pf.log" 2>&1 &
    pf=$!
    for _ in $(seq 1 30); do curl -s -o /dev/null "http://localhost:{{s3_port}}" && break || sleep 0.5; done
    aws() {
        docker run --rm --network host \
            -e AWS_ACCESS_KEY_ID={{s3_access_key}} -e AWS_SECRET_ACCESS_KEY={{s3_secret_key}} \
            -e AWS_EC2_METADATA_DISABLED=true -v "$tmp:/data" {{client_image}} \
            --endpoint-url "http://localhost:{{s3_port}}" --region us-east-1 "$@"
    }
    bucket="multipart-$RANDOM"
    echo ">> Generating {{size_mb}}MB random file (aws-cli auto-multiparts above 8MB)"
    dd if=/dev/urandom of="$tmp/big.bin" bs=1M count={{size_mb}} status=none
    sha_in="$(sha256sum "$tmp/big.bin" | cut -d' ' -f1)"
    aws s3 mb "s3://$bucket" >/dev/null
    echo ">> Uploading"
    aws s3 cp --no-progress /data/big.bin "s3://$bucket/big.bin"
    echo ">> Downloading"
    aws s3 cp --no-progress "s3://$bucket/big.bin" /data/roundtrip.bin
    sha_out="$(sha256sum "$tmp/roundtrip.bin" | cut -d' ' -f1)"
    aws s3 rm "s3://$bucket/big.bin" >/dev/null; aws s3 rb "s3://$bucket" >/dev/null
    if [ "$sha_in" = "$sha_out" ]; then
        echo ">> PASS ✅  {{size_mb}}MB round-trip intact (sha256 $sha_in)"
    else
        echo ">> FAIL ❌  checksum mismatch: in=$sha_in out=$sha_out"; exit 1
    fi

# --- Phase 3: S3 compatibility -----------------------------------------------

# Bucket versioning: multiple versions retained + retrievable by version-id. (P3-01)
s3-versioning-test:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp="$(mktemp -d)"; pf=""
    trap '[ -n "$pf" ] && kill $pf 2>/dev/null; rm -rf "$tmp"' EXIT
    kubectl -n {{namespace}} port-forward svc/{{release}}-s3 {{s3_port}}:{{s3_port}} >"$tmp/pf.log" 2>&1 & pf=$!
    for _ in $(seq 1 30); do curl -s -o /dev/null "http://localhost:{{s3_port}}" && break || sleep 0.5; done
    aws() {
        docker run --rm --network host -e AWS_ACCESS_KEY_ID={{s3_access_key}} \
            -e AWS_SECRET_ACCESS_KEY={{s3_secret_key}} -e AWS_EC2_METADATA_DISABLED=true \
            -v "$tmp:/data" {{client_image}} \
            --endpoint-url "http://localhost:{{s3_port}}" --region us-east-1 "$@"
    }
    b="ver-$RANDOM"
    aws s3 mb "s3://$b" >/dev/null
    echo ">> Enabling versioning on $b"
    aws s3api put-bucket-versioning --bucket "$b" --versioning-configuration Status=Enabled
    echo ">> Checking versioning status"
    aws s3api get-bucket-versioning --bucket "$b"
    printf 'version-one\n' > "$tmp/v1.txt"; printf 'version-two\n' > "$tmp/v2.txt"
    v1=$(aws s3api put-object --bucket "$b" --key obj --body /data/v1.txt --query VersionId --output text)
    v2=$(aws s3api put-object --bucket "$b" --key obj --body /data/v2.txt --query VersionId --output text)
    echo ">> Wrote 2 versions: v1=$v1  v2=$v2"
    n=$(aws s3api list-object-versions --bucket "$b" --query 'length(Versions)' --output text)
    aws s3api get-object --bucket "$b" --key obj --version-id "$v1" /data/got1.txt >/dev/null
    aws s3api get-object --bucket "$b" --key obj /data/gotlatest.txt >/dev/null
    ok=1
    [ "$n" = "2" ] || { echo "   expected 2 versions, got $n ❌"; ok=0; }
    [ "$v1" != "$v2" ] && [ "$v1" != "None" ] && [ -n "$v1" ] || { echo "   version ids missing/equal ❌"; ok=0; }
    [ "$(cat "$tmp/got1.txt")" = "version-one" ] || { echo "   v1 fetch mismatch ❌"; ok=0; }
    [ "$(cat "$tmp/gotlatest.txt")" = "version-two" ] || { echo "   latest fetch mismatch ❌"; ok=0; }
    echo ">> cleanup"
    aws s3api list-object-versions --bucket "$b" --output json > "$tmp/vs.json" 2>/dev/null || true
    jq -r '(.Versions // [])[],(.DeleteMarkers // [])[] | "\(.Key)\t\(.VersionId)"' "$tmp/vs.json" 2>/dev/null \
        | while IFS=$'\t' read -r k vid; do aws s3api delete-object --bucket "$b" --key "$k" --version-id "$vid" >/dev/null 2>&1 || true; done
    aws s3 rb "s3://$b" >/dev/null 2>&1 || true
    [ $ok -eq 1 ] && echo ">> s3-versioning-test PASSED ✅" || { echo ">> s3-versioning-test FAILED ❌"; exit 1; }

# Presigned URL: fetch an object over HTTP with no credentials. (P3-02)
s3-presign-test:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp="$(mktemp -d)"; pf=""
    trap '[ -n "$pf" ] && kill $pf 2>/dev/null; rm -rf "$tmp"' EXIT
    kubectl -n {{namespace}} port-forward svc/{{release}}-s3 {{s3_port}}:{{s3_port}} >"$tmp/pf.log" 2>&1 & pf=$!
    for _ in $(seq 1 30); do curl -s -o /dev/null "http://localhost:{{s3_port}}" && break || sleep 0.5; done
    aws() {
        docker run --rm --network host -e AWS_ACCESS_KEY_ID={{s3_access_key}} \
            -e AWS_SECRET_ACCESS_KEY={{s3_secret_key}} -e AWS_EC2_METADATA_DISABLED=true \
            -v "$tmp:/data" {{client_image}} \
            --endpoint-url "http://localhost:{{s3_port}}" --region us-east-1 "$@"
    }
    b="presign-$RANDOM"; marker="presigned-content-$RANDOM"
    aws s3 mb "s3://$b" >/dev/null
    echo "$marker" > "$tmp/obj.txt"
    aws s3 cp --no-progress /data/obj.txt "s3://$b/obj.txt" >/dev/null
    echo ">> Generating presigned GET URL (expires in 300s)"
    url=$(aws s3 presign "s3://$b/obj.txt" --expires-in 300)
    echo "   $url"
    echo ">> Fetching URL with plain curl (no credentials)"
    got=$(curl -s "$url")
    aws s3 rm "s3://$b/obj.txt" >/dev/null; aws s3 rb "s3://$b" >/dev/null
    if [ "$got" = "$marker" ]; then echo ">> s3-presign-test PASSED ✅"; else echo ">> s3-presign-test FAILED ❌ (got: $got)"; exit 1; fi

# Object content-type + user metadata are preserved. (P3-04)
s3-metadata-test:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp="$(mktemp -d)"; pf=""
    trap '[ -n "$pf" ] && kill $pf 2>/dev/null; rm -rf "$tmp"' EXIT
    kubectl -n {{namespace}} port-forward svc/{{release}}-s3 {{s3_port}}:{{s3_port}} >"$tmp/pf.log" 2>&1 & pf=$!
    for _ in $(seq 1 30); do curl -s -o /dev/null "http://localhost:{{s3_port}}" && break || sleep 0.5; done
    aws() {
        docker run --rm --network host -e AWS_ACCESS_KEY_ID={{s3_access_key}} \
            -e AWS_SECRET_ACCESS_KEY={{s3_secret_key}} -e AWS_EC2_METADATA_DISABLED=true \
            -v "$tmp:/data" {{client_image}} \
            --endpoint-url "http://localhost:{{s3_port}}" --region us-east-1 "$@"
    }
    b="meta-$RANDOM"
    aws s3 mb "s3://$b" >/dev/null
    echo '{"hello":"world"}' > "$tmp/obj.json"
    echo ">> Put object with content-type + user metadata"
    aws s3api put-object --bucket "$b" --key obj.json --body /data/obj.json \
        --content-type application/json --metadata team=platform,env=lab >/dev/null
    echo ">> head-object"
    aws s3api head-object --bucket "$b" --key obj.json --output json > "$tmp/head.json"
    ct=$(jq -r '.ContentType' "$tmp/head.json")
    m_team=$(jq -r '.Metadata.team' "$tmp/head.json")
    m_env=$(jq -r '.Metadata.env' "$tmp/head.json")
    echo "   ContentType=$ct  team=$m_team  env=$m_env"
    aws s3 rm "s3://$b/obj.json" >/dev/null; aws s3 rb "s3://$b" >/dev/null
    if [ "$ct" = "application/json" ] && [ "$m_team" = "platform" ] && [ "$m_env" = "lab" ]; then
        echo ">> s3-metadata-test PASSED ✅"
    else echo ">> s3-metadata-test FAILED ❌"; exit 1; fi

# Cross-SDK / SigV4 check: MinIO's own `mc` client (SigV4) interoperates. (P3-05)
s3-mc-test:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp="$(mktemp -d)"; pf=""
    trap '[ -n "$pf" ] && kill $pf 2>/dev/null; rm -rf "$tmp"' EXIT
    kubectl -n {{namespace}} port-forward svc/{{release}}-s3 {{s3_port}}:{{s3_port}} >"$tmp/pf.log" 2>&1 & pf=$!
    for _ in $(seq 1 30); do curl -s -o /dev/null "http://localhost:{{s3_port}}" && break || sleep 0.5; done
    # MinIO client via MC_HOST env (no persistent alias needed across containers).
    mc() {
        docker run --rm --network host -v "$tmp:/data" \
            -e MC_HOST_sw="http://{{s3_access_key}}:{{s3_secret_key}}@localhost:{{s3_port}}" \
            minio/mc "$@"
    }
    b="mc-$RANDOM"; marker="mc-sdk-$RANDOM"
    echo ">> mc (MinIO Go SDK, SigV4) operations against SeaweedFS"
    mc mb "sw/$b"
    echo "$marker" > "$tmp/obj.txt"
    mc cp /data/obj.txt "sw/$b/obj.txt"
    mc ls "sw/$b"
    got=$(mc cat "sw/$b/obj.txt")
    mc rm "sw/$b/obj.txt"; mc rb "sw/$b"
    if [ "$got" = "$marker" ]; then echo ">> s3-mc-test PASSED ✅ (MinIO client interoperates)"; else echo ">> s3-mc-test FAILED ❌"; exit 1; fi

# Show the saved test report; if none exists yet, run the full suite first.
test-report:
    #!/usr/bin/env bash
    set -uo pipefail
    if [ ! -s "{{results_file}}" ]; then
        echo ">> No saved results ({{results_file}}) — running the full suite first..."
        just test-all
    fi
    gen=$(grep '^# generated:' "{{results_file}}" | cut -d' ' -f3-)
    echo
    echo "=========================================================="
    echo " SeaweedFS test report"
    echo " generated: ${gen:-unknown}"
    echo "=========================================================="
    while IFS=$'\t' read -r st name; do
        case "$st" in PASS) icon="✅";; FAIL) icon="❌";; *) continue;; esac
        printf "  %s  %s\n" "$icon" "$name"
    done < <(grep -v '^#' "{{results_file}}")
    pass=$(grep -c '^PASS' "{{results_file}}" || true)
    fail=$(grep -c '^FAIL' "{{results_file}}" || true)
    echo "----------------------------------------------------------"
    printf "  %s passed, %s failed\n" "${pass:-0}" "${fail:-0}"
    echo "  Per-test logs: ./test-logs/   |   Re-run: just test-all"
    echo "  Broad S3 conformance is a separate survey: just mint-report"
    echo "=========================================================="

# Run the full pass/fail test suite and record results (restarts pods + redeploys; ~5-8 min).
test-all:
    #!/usr/bin/env bash
    set -uo pipefail
    logdir="test-logs"; mkdir -p "$logdir"
    : > "{{results_file}}"
    printf '# generated: %s\n' "$(date -u +%FT%TZ)" >> "{{results_file}}"
    echo ">> Running full suite (functional tests, then disruptive restart/redeploy tests)"
    run_one() {
        local name="$1"; shift
        printf "  %-22s ... " "$name"
        if just "$@" >"$logdir/$name.log" 2>&1; then
            echo "PASS"; printf 'PASS\t%s\n' "$name" >> "{{results_file}}"
        else
            echo "FAIL"; printf 'FAIL\t%s\n' "$name" >> "{{results_file}}"
        fi
    }
    # Non-disruptive functional tests first.
    run_one s3-smoke          s3-smoke
    run_one s3-auth-check     s3-auth-check
    run_one tenant-isolation  tenant-isolation-test
    run_one multipart         multipart-test
    run_one versioning        s3-versioning-test
    run_one presign           s3-presign-test
    run_one metadata          s3-metadata-test
    run_one mc-interop        s3-mc-test
    # Disruptive tests last (restart pods / uninstall+redeploy).
    run_one restart-s3        restart-survives s3
    run_one restart-volume    restart-survives volume
    run_one restart-filer     restart-survives filer
    run_one redeploy-persists redeploy-persists
    echo ">> Suite complete. View with: just test-report"

# Broad S3 conformance suite via MinIO Mint (P3 breadth). Pass suites as one arg,
# e.g. `just mint-test "awscli mc minio-go"`. Some failures are EXPECTED — Mint
# targets MinIO, so MinIO-specific behaviors won't all match SeaweedFS.
mint-test suites="awscli mc minio-go s3cmd":
    #!/usr/bin/env bash
    set -uo pipefail
    tmp="$(mktemp -d)"; pf=""
    trap '[ -n "$pf" ] && kill $pf 2>/dev/null; rm -rf "$tmp"' EXIT
    kubectl -n {{namespace}} port-forward svc/{{release}}-s3 {{s3_port}}:{{s3_port}} >"$tmp/pf.log" 2>&1 & pf=$!
    for _ in $(seq 1 30); do curl -s -o /dev/null "http://localhost:{{s3_port}}" && break || sleep 0.5; done
    # RUN_ON_FAIL=1 keeps each suite going past failures. Mint's own file logging
    # is unreliable per-suite, so we persist the FULL stdout to
    # ./mint-logs/last-run.log — that's the authoritative record `mint-report` reads.
    # (awscli also writes complete per-test results to ./mint-logs/log.json.)
    mkdir -p mint-logs
    echo ">> Running MinIO Mint suites: {{suites}}  (log -> ./mint-logs/last-run.log)"
    {
        echo "# generated: $(date -u +%FT%TZ)"
        echo "# suites: {{suites}}"
        docker run --rm --network host \
            -e SERVER_ENDPOINT="localhost:{{s3_port}}" \
            -e ACCESS_KEY="{{s3_access_key}}" \
            -e SECRET_KEY="{{s3_secret_key}}" \
            -e ENABLE_HTTPS=0 \
            -e RUN_ON_FAIL=1 \
            -v "$(pwd)/mint-logs:/mint/log" \
            minio/mint {{suites}}
    } 2>&1 | tee mint-logs/last-run.log

# Show the saved MinIO Mint conformance report; if none exists, run mint-test first.
mint-report:
    #!/usr/bin/env bash
    set -uo pipefail
    RUN=mint-logs/last-run.log
    if [ ! -s "$RUN" ]; then
        echo ">> No saved conformance run — running mint-test (default suites) first..."
        just mint-test
    fi
    gen=$(grep -m1 '^# generated:' "$RUN" | cut -d' ' -f3-)
    suites=$(grep -m1 '^# suites:' "$RUN" | cut -d' ' -f3-)
    echo
    echo "=================================================================="
    echo " SeaweedFS S3 conformance — MinIO Mint"
    echo " generated: ${gen:-unknown}"
    echo " suites:    ${suites:-unknown}"
    echo " note: Mint targets MinIO, so some edge failures are EXPECTED."
    echo "=================================================================="
    echo " Per-suite result:"
    grep -E 'Running .+ tests \.\.\.' "$RUN" \
      | sed -E 's/.*Running ([a-z0-9_-]+) tests \.\.\. done in ([0-9]+).*/  PASS  \1  (\2s)/; s/.*Running ([a-z0-9_-]+) tests \.\.\. FAILED in ([0-9]+).*/  FAIL  \1  (\2s)/'
    ex=$(grep -m1 -E 'Executed .* out of .* tests' "$RUN" || true)
    [ -n "$ex" ] && { echo "----------------------------------------------------------------"; echo "  $ex"; }
    echo "----------------------------------------------------------------"
    echo " Failure detail (first failure surfaced per failing suite):"
    if grep -q '"status": "FAIL"' "$RUN"; then
        awk '/^\{/{f=1;b=""} f{b=b $0 ORS} /^\}/{f=0; if (b ~ /"status": "FAIL"/) printf "%s", b}' "$RUN" | sed 's/^/  /'
    else
        echo "  (no failures)"
    fi
    if [ -s mint-logs/log.json ]; then
        echo "----------------------------------------------------------------"
        echo " awscli full per-test counts (from log.json):"
        jq -r '.status' mint-logs/log.json 2>/dev/null | sort | uniq -c | sed 's/^/  /'
    fi
    echo "----------------------------------------------------------------"
    echo "  Full run log: ./mint-logs/last-run.log   |   Re-run: just mint-test"
    echo "  Narrative: docs/01-test-plan.md (P3-06), docs/02-lessons.md"
    echo "=================================================================="

# Show cluster leader + volume topology from the master API (proves P1-07).
topology:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp="$(mktemp -d)"
    kubectl -n {{namespace}} port-forward svc/{{release}}-master 9333:9333 >"$tmp/pf.log" 2>&1 &
    pf=$!
    trap 'kill $pf 2>/dev/null || true; rm -rf "$tmp"' EXIT
    for _ in $(seq 1 30); do curl -s -o /dev/null http://localhost:9333/cluster/status && break || sleep 0.5; done

    echo "### Cluster status"
    curl -s http://localhost:9333/cluster/status | jq '{IsLeader, Leader, MaxVolumeId}'
    echo "### Volume topology (per data node)"
    curl -s http://localhost:9333/dir/status \
        | jq '.Topology | {Max, Free, DataNodes: [.DataCenters[].Racks[].DataNodes[] | {Url, Volumes, Max, VolumeIds}]}'

# Print the S3 endpoint + credentials for manual testing.
s3-info:
    @echo "Endpoint (via 'just port-forward-s3'): http://localhost:{{s3_port}}"
    @echo "Access key: {{s3_access_key}}"
    @echo "Secret key: {{s3_secret_key}}"
