---
name: rust-engineering
description: When writing, reviewing, or refactoring Rust and you want well-engineered code, not just code that compiles — the judgment layer above the borrow checker. Covers type-driven design, error architecture, ownership over shared-mutability, API-guideline conventions, async correctness, and wielding the compiler/clippy as a correction loop. Triggers - write Rust, review Rust, refactor Rust, idiomatic Rust, is this good Rust, Rust code quality, Rust best practices, Rust engineering guide, fix a borrow-checker error properly, Rust API design, async Rust pitfalls, avoid clone/unwrap, Box dyn vs impl Trait.
---

Write well-engineered Rust, not code that merely compiles. The characteristic agent failure: satisfying the compiler with the cheapest local edit — `.clone()`, `Rc<RefCell>`, `Box<dyn>`, `.unwrap()` — which compiles but engineers badly. Apply the judgment below; read the compiler and clippy, don't just silence them. When a rule here is one you can't apply from its terse form, open `uncompressed.md` for its worked before/after; for a category not covered below (serde, testing, macros, docs, observability, project structure, naming), consult `reference.md`. If a companion file isn't present, apply the terse rule directly.

When these practices conflict, prefer correctness and robustness over idiom, and idiom over brevity. A project's own established conventions win over these defaults for idiom and style — never over a correctness or robustness practice (a codebase that `.unwrap()`s everywhere is not a license to add more). Apply them to code you're writing or already changing, not as a repo-wide sweep.

Reviewing rather than writing: first scan the diff against the failure-modes list and the "Before you call it done" checklist at the end, then read line-by-line.

## Correctness by construction

- Parse, don't validate: at the boundary, turn raw input into a newtype (private field + fallible `TryFrom` / `new() -> Result`) so illegal states can't be constructed and downstream never re-checks. Enums over `bool`/stringly-typed flags; `NonZero*` and precise domain types over bare primitives; typestate (a separate type per state, so an invalid-state method doesn't exist) when illegal transitions must not compile. Scope this to boundaries and invariants worth enforcing, not every field.
- Errors are API: `thiserror` (typed, `#[non_exhaustive]`) in libraries; `anyhow`/`eyre` (opaque + `.context()`) in binaries. Propagate with `?`; preserve the source (`#[from]`/`#[source]`), never `map_err(|_| Generic)`. `unwrap`/`expect` only for broken invariants, with a message stating *why* it can't fail.

## Ownership before escape hatches

- `.clone()` to end a borrow error is a smell — restructure by symptom (worked before/after: `uncompressed.md` §2.1):
  - single value trapped behind `&mut` → `mem::take`/`replace`
  - two fields borrowed together → split/partial borrows
  - borrow ends too early → collect the owned result first, then mutate
  - cyclic/graph mutation → index/arena graphs (not `Rc<RefCell>` node soup)
  - usually-borrow-sometimes-own → `Cow`
  - genuinely shared ownership → then, and only then, `Rc`/`Arc`
- `Rc<RefCell>`/`Arc<Mutex>` trade a compile-time borrow error for a runtime panic/deadlock — use only when ownership is genuinely shared, never to dodge design.
- `impl Trait`/generics (static dispatch, no allocation) by default — one concrete type per call site needs no erasure; `Box<dyn>` only for heterogeneous or open type sets; `enum` + exhaustive `match` for a closed set of variants.
- `Deref` only for real smart pointers; for a type-safety newtype, expose deliberate methods — don't blanket-deref the inner API you meant to constrain.

## API and numeric edges

- Accept the most general borrowed type (`&str`, `&[T]`, `impl AsRef<Path>`, `impl IntoIterator`); return `impl Iterator` when the caller may not need a collection. Conversions via `From`/`TryFrom`/`FromStr`; builders over telescoping `new()`; `#[must_use]`, `#[non_exhaustive]`, sealed traits. Don't leak private types in public signatures.
- `as` truncates, wraps, and flips sign silently — use `try_into()` at narrowing/sign boundaries, `from`/`into` only for lossless widening. Overflow wraps in release but panics in debug — state intent with `checked_`/`saturating_`/`wrapping_`. Never `==` on float arithmetic.

## Async correctness

Runtime API names below are tokio; use your runtime's equivalents.

- Never hold a `std::sync::MutexGuard` across `.await` (makes the future `!Send`, blocks other waiters) — scope the guard to drop before the await, or use `tokio::sync::Mutex` only when the lock must span an await.
- Offload blocking/CPU work to `spawn_blocking`; use async I/O and `tokio::time::sleep`, never `std::thread::sleep`, in a task.
- Bounded channels for backpressure. Mind `select!` cancellation — a branch dropped mid-`.await` loses partial work. Spawned futures must be `Send + 'static`.

## The compiler is your harness

- Every iteration: `cargo check` → `cargo clippy -- -D warnings` (read the *whole* diagnostic, fix the cause, don't pattern-match to the first edit that compiles) → `cargo fmt` → `cargo test` (+ doc-tests; `proptest` for invariant-heavy code).
- Every `unsafe` block carries a `// SAFETY:` note per invariant and is exercised under Miri; never add `unsafe` to escape the borrow checker.
- Never `#[allow(...)]`, delete a lint, or drop `-D warnings` for a green build unless you can state why the lint is wrong here. A red build is your densest signal — suppressing it deletes information, it doesn't fix anything.
- Hygiene: `cargo-audit`/`cargo-deny` for advisories and policy, `cargo machete` for unused deps; keep the dependency set and its feature flags minimal.

## Before you call it done

- [ ] `cargo fmt` clean; `cargo clippy -- -D warnings` clean, no new `#[allow]` without a justifying comment.
- [ ] `cargo test` green, including doc-tests.
- [ ] No `.unwrap()`/`.expect()` on fallible paths; library errors typed, sources preserved.
- [ ] No `.clone()` that only ended a borrow; no `Rc<RefCell>`/`Arc<Mutex>` that isn't genuinely shared.
- [ ] No reflexive `Box<dyn>` where `impl Trait` fits; no `Deref` used as inheritance.
- [ ] No `as` on narrowing/sign-changing casts; overflow intent explicit.
- [ ] Async: no guard held across `.await`, no blocking the runtime, channels bounded.
- [ ] Invariants encoded in types at the boundary; every `unsafe` has a `// SAFETY:` note.

Miri, `cargo-audit`, `cargo-deny`, and `cargo machete` are best-effort — skip any not installed rather than blocking completion on it. If the project isn't a plain-cargo build or a step is environmentally blocked, run the project's equivalent and note anything skipped. If no toolchain can be run at all, apply the checklist by inspection and flag explicitly that verification did not execute.

Recurring failure modes to self-check: clone-to-satisfy-borrow-checker · unwrap-everywhere · reflexive `Box<dyn>` · `Rc<RefCell>`/`Arc<Mutex>` to dodge ownership · `Deref` inheritance · stringly-typed errors / dropped source · `as` narrowing · `#[allow]` to hide lints · guard-across-`.await` or blocking in async · applying the first edit that compiles instead of reading the diagnostic.
