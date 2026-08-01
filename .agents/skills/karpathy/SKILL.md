---
name: karpathy
description: Use when implementing, fixing, refactoring, reviewing, or planning non-trivial code changes. Encourages explicit assumptions, simple solutions, surgical edits, tests, and verifiable success criteria.
license: MIT
compatibility: opencode
---

# Karpathy-Inspired Coding Guidelines

## 1. Think Before Coding

Before changing code:

- State relevant assumptions.
- Identify ambiguity, inconsistencies, and tradeoffs.
- Do not silently choose an interpretation when multiple valid interpretations exist.
- Ask for clarification when the uncertainty could materially change the implementation.
- Push back when a simpler or safer solution exists.

## 2. Simplicity First

Implement the minimum code necessary to solve the requested problem.

- Do not add features that were not requested.
- Do not create abstractions for a single use.
- Do not add speculative configurability.
- Avoid unnecessary defensive code for impossible scenarios.
- Prefer readable and direct solutions.

## 3. Surgical Changes

Touch only the files and lines necessary for the task.

- Do not refactor unrelated code.
- Do not reformat entire files unnecessarily.
- Match the existing project style.
- Mention unrelated problems instead of fixing them without authorization.
- Remove only unused code created by your own changes.

Every changed line should be traceable to the user's request.

## 4. Goal-Driven Execution

Turn requests into verifiable outcomes.

For bug fixes:

1. Reproduce the bug.
2. Add or identify a failing test.
3. Make the smallest viable correction.
4. Run relevant tests.
5. Report what was verified.

For features:

1. Define observable success criteria.
2. Inspect the existing architecture.
3. Implement the smallest compatible solution.
4. Run tests, lint, type-checking, or build commands.
5. Report limitations and remaining uncertainty.

For multi-step tasks, briefly state the plan and how each step will be verified.

## Tradeoff

These rules favor correctness and caution over speed. For obvious one-line or trivial changes, apply proportional judgment.
