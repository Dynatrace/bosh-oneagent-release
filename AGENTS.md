# AGENTS.md

## Purpose

This repository is a BOSH release that installs Dynatrace OneAgent on BOSH-managed VMs, maintained by the KITE team at Dynatrace.

Agents working in this repository should optimize for:
- keeping the BOSH release compatible with current OneAgent versions
- supporting both Linux and Windows Diego cells
- clear ownership and support documentation

## What this repository is

`bosh-oneagent-release` packages Dynatrace OneAgent as a BOSH addon. It is deployed via `bosh update-runtime-config` and installs OneAgent across all managed VMs in a BOSH environment.

## Repository expectations

- Keep changes simple and easy to review.
- Prefer small, focused pull requests.
- Never include credentials, API tokens, or environment-specific secrets in committed files.
- Preserve `CODEOWNERS`, `SUPPORT.md`, and this file.
- Run the CircleCI pipeline before merging.

## What to avoid

- Do not hardcode Dynatrace environment URLs or tokens.
- Do not assume this release is commercially supported.
- Do not add platform-specific logic without testing on both Linux and Windows targets.
