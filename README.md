# Learning SeaweedFS

With MinIO going closed source, this repo explores [SeaweedFS](https://github.com/seaweedfs/seaweedfs)
as an open-source way to provide S3 storage in a Kubernetes cluster. It documents
how to spin up a throwaway test environment and captures lessons as we go.

The end goal is informing a UDS package for SeaweedFS. But first we learn the
**bare upstream** deployment on plain K3d, before layering on UDS/Istio/SSO
complexity.

## Prerequisites

Already installed and used by the automation:

- [`k3d`](https://k3d.io) — local Kubernetes via Docker
- `kubectl`, [`helm`](https://helm.sh) — **Helm ≥ 3.17** required (chart 4.39.0
  uses the `fromToml` template function added in 3.17)
- [`just`](https://github.com/casey/just) — task runner (see `justfile`)
- `docker` — also used to run a throwaway `aws-cli` container for S3 tests
  (no host `aws`/`s3cmd`/`mc` install required)

SeaweedFS is installed from its **published Helm repo**
(`https://seaweedfs.github.io/seaweedfs/helm`) — you do **not** need to clone the
SeaweedFS source to use this repo.

## Quickstart

```bash
just              # list all recipes
just up           # create k3d cluster + deploy SeaweedFS
just status       # check pods / services / PVCs
just test-report  # show saved test results (runs the full suite if none exist yet)
just s3-smoke     # end-to-end S3 CRUD test (create/put/list/get/delete)
just s3-auth-check # verify auth: good creds allowed, bad/anonymous denied
just topology     # cluster leader + volume topology from the master API
just tenant-isolation-test # bucket-scoped identity isolation (SeaweedFS "tenants")
just down         # tear everything down

# Phase 2 — durability & storage
just restart-survives filer   # data survives a component restart (master|filer|volume|s3)
just redeploy-persists        # data survives uninstall + redeploy (PVCs retained)
just multipart-test           # large (multipart) upload round-trips intact

# Phase 3 — S3 compatibility
just s3-versioning-test       # bucket versioning: versions retained + retrievable
just s3-presign-test          # presigned URL fetch (no credentials)
just s3-metadata-test         # content-type + user metadata preserved
just s3-mc-test               # MinIO mc client (SigV4) interoperates
just mint-report              # broad MinIO Mint conformance report (runs suite if needed)
just s3-tests-report          # granular Ceph s3-tests conformance (per-test pass/fail)
```

For manual poking:

```bash
just s3-info            # print endpoint + lab credentials
just port-forward-s3    # expose S3 API at http://localhost:8333
just port-forward-master # expose master UI at http://localhost:9333
just weed-shell         # open the SeaweedFS admin CLI
just logs filer         # tail logs (master|filer|volume|s3)
```

> The S3 credentials in the `justfile` are **local-lab throwaway values**. Don't
> reuse them anywhere real.

## Viewing test results

- `just test-report` — prints the saved pass/fail table. If there are no saved
  results yet, it runs the full suite (`test-all`) first, then prints them.
- `just test-all` — always re-runs the full suite and refreshes the saved results.
- Results persist to `test-results.tsv`; per-test output is in `test-logs/`
  (both gitignored).
- `just mint-report` — the broad **S3 conformance** survey (MinIO Mint). Same
  pattern: prints the saved report, or runs `mint-test` first if none exists.
  Full run log persists to `mint-logs/last-run.log`. This is a *survey* (some
  edge failures are expected since Mint targets MinIO), kept separate from the
  pass/fail suite above.
- `just s3-tests-report` — **granular** S3 conformance via Ceph s3-tests (boto3),
  hundreds of per-test pass/fail results (deeper than Mint). Containerized
  (`s3-tests/Dockerfile`); config in `s3-tests/s3tests.conf`; run log persists to
  `s3-tests/logs/last-run.log`. Some failures are expected (the suite targets
  Ceph RGW).

The authoritative, annotated results live in `docs/01-test-plan.md` (status per
test) and `docs/02-lessons.md` (findings).

## Layout

```
learning-seaweedfs/
├── README.md                     # you are here
├── justfile                      # environment + test automation
├── k3d/
│   ├── cluster.yaml              # k3d cluster definition
│   └── seaweedfs-values.yaml     # minimal Helm values (S3 enabled)
└── docs/
    ├── 00-architecture.md        # component model & how writes flow
    ├── 01-test-plan.md           # phased test plan (the checklist we work through)
    └── 02-lessons.md             # running log of findings
```

## Where to start

1. Read `docs/00-architecture.md` for the component model.
2. Run `just up` then `just s3-smoke`.
3. Work through `docs/01-test-plan.md`, recording results and notes as you go.
4. Capture anything surprising in `docs/02-lessons.md`.
