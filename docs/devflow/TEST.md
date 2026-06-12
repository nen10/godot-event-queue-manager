# Devflow Test Index

This file describes how Autopilot should verify work in this repository. Replace placeholders before executing implementation tasks.

## Standard verification command

```sh
<standard test command, for example ./tools/test.sh>
```

Autopilot must run this command, or record why it cannot run.

## Environment requirements

| requirement | expected value | how to check |
|---|---|---|
| runtime / framework | `<fill>` | `<command>` |
| package manager | `<fill>` | `<command>` |
| test runner | `<fill>` | `<command>` |
| build tools | `<fill>` | `<command>` |

If a required tool is missing, record `BLOCKED_BY_TEST_ENV` with the exact command and error output.

## Test paths

| path / command | category | what it proves | when to run |
|---|---|---|---|
| `<command>` | Unit / Core | `<contract>` | `<tasks>` |
| `<command>` | Integration | `<contract>` | `<tasks>` |
| `<command>` | UI / workflow | `<contract>` | `<tasks>` |
| `<command>` | Package / release | `<contract>` | `<tasks>` |

## Completion proof rules

A task may be marked `COMPLETE` only when:

- Acceptance in `IMPLEMENTATION_QUEUE.md` is satisfied.
- Relevant test paths above passed, or an environment-blocking result was documented.
- `docs/devflow/TEST.md` was updated if tests were added or changed.
- Self-review has no `repair-now` items.

## Test result log format

```md
# <TASK_ID> Test Result <YYYY-MM-DD>

## Commands attempted

```sh
<command>
```

## Result

<pass/fail/blocked summary>

## Classification

`passed` | `repair-now` | `known-env-failure` | `pre-existing` | `accepted-risk`

## Follow-up

<none or queue task ids>
```
