# SeatLayer iOS public-repository rules

This repository is the public SeatLayer iOS SDK.

## Public-repository hygiene — hard rule

- Commit only product source, tests, build/release automation, public examples,
  package metadata, and customer-facing integration, API, migration, or
  security documentation.
- Never commit planning documents, handovers, implementation audits or reviews,
  cross-SDK comparison matrices, manual QA journals, evidence bundles, dated
  progress reports, before/rejected captures, credentials, non-public hosts,
  private repository references, or developer-machine paths.
- Public product media belongs in `Docs/media/`; regression images belong only
  in automated test-fixture locations. Do not use the Git repository as an
  evidence archive.
- Record verification in CI and release checks, not in tracked screenshots or
  narrative proof documents.
- Run `bash Scripts/check-public-repository.sh` before committing or pushing.

Preserve bridge negotiation, command correlation, stale-event filtering,
unknown-value tolerance, origin restrictions, and the server-side booking
boundary. Keep secrets and booking credentials off the device.
