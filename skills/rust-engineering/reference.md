# Rust engineering reference — category checklist

A scannable, category-organized checklist of idiomatic-Rust rules to consult as a lookup; deep rationale and worked examples for the starred topics live in `uncompressed.md`.

## 1. Ownership & borrowing
- Prefer `&T`/`&mut T` over cloning; clone only when ownership must genuinely transfer or outlive the borrow (guide §2.1).
- Treat `Arc`/`Rc` as a deliberate architectural choice, not a default escape from the borrow checker — document why shared ownership is needed.
- Use `RefCell`/`Mutex` only when interior mutability is the actual requirement, not a convenience patch.
- Let lifetime elision work; write explicit lifetimes only when the compiler can't infer relationships, and name them for meaning (`'buf`, not always `'a`) in nontrivial signatures.
- Use `mem::take`/`mem::replace`/`mem::swap` to move a value out of a `&mut` binding without cloning or fighting the borrow checker.
- Split borrows via separate fields, `split_at_mut`, or destructuring when the borrow checker rejects two disjoint mutable borrows it can't prove are disjoint.
- Return owned data or borrowed slices with clear lifetimes; avoid self-referential structs unless using a crate built for it.
- Avoid `.clone()` calls whose only purpose is silencing a borrow-checker error — that's a design smell, not a fix.

## 2. Error handling
- Libraries: define errors with `thiserror`; applications: aggregate with `anyhow`/`eyre` (guide §1.2).
- Propagate with `?`; reserve `.unwrap()`/`.expect()` for tests, examples, and truly-impossible states (with a message explaining why).
- Never `.unwrap()`/`panic!()` in library code on inputs you don't control.
- Preserve the error source chain — use `#[source]`/`#[from]` instead of stringifying and discarding the cause.
- Mark public error enums `#[non_exhaustive]` so adding a variant isn't a breaking change.
- Don't collapse distinct failure modes into one generic variant — callers need to `match` on cause.
- Convert between error types with `From`/`?`, not manual `map_err(|e| ...)` at every call site.
- Include actionable context (what operation, what input) in error messages, not just the underlying cause.

## 3. Type safety
- Wrap primitive values that carry domain meaning in newtypes (`struct UserId(u64)`) to prevent mixing incompatible values of the same underlying type.
- Parse, don't validate: convert untrusted input into a type that makes the invalid state unrepresentable, once, at the boundary (guide §1.1).
- Prefer enums over `bool` parameters or stringly-typed flags — `Mode::ReadOnly` beats `read_only: bool` at every call site.
- Use `NonZeroU32`/`NonZeroUsize` etc. when zero is invalid, so the compiler enforces it and `Option<NonZero…>` is niche-optimized.
- Use phantom types or the typestate pattern to encode protocol/state transitions when illegal call sequences must be caught at compile time.
- Avoid primitive obsession: a function taking five `String`/`u32` args is a sign several should be a struct or newtypes.
- Make illegal states unrepresentable in the type rather than checked at runtime wherever the type can express the constraint cheaply.

## 4. API design
- Accept the most general borrowed type callers are likely to have: `&str` not `&String`, `&[T]` not `&Vec<T>`, `impl AsRef<Path>` for paths.
- Use `impl Trait` in argument position for flexibility, and in return position to hide concrete iterator/closure types.
- Offer builders for structs with many optional fields instead of multiple constructors or long positional arg lists.
- Implement `From`/`TryFrom`/`FromStr` for idiomatic, discoverable conversions instead of ad hoc `from_x`/`parse_x` functions.
- Annotate types/functions whose result must be handled with `#[must_use]` (builders, `Result`-like types, guards).
- Mark public enums/structs `#[non_exhaustive]` when you expect to add variants/fields without a breaking release.
- Seal traits you don't want external crates implementing, via a private supertrait in an unreachable module.
- Never leak private/internal types through public signatures — it locks you into exposing them forever.
- Keep public API surface minimal; default to private and widen deliberately, not by omission.

## 5. Traits & generics
- Static dispatch (generics/`impl Trait`) for hot paths and monomorphization wins; dynamic dispatch (`dyn Trait`) for heterogeneous collections or reduced code size (guide §2.2).
- Use associated types when a trait has exactly one natural output type per `Self`; use type parameters when a type can implement the trait multiple ways (e.g. `From<A>` and `From<B>`).
- Object-safe traits (for `dyn Trait`) can't have generic methods, `Self`-returning methods, or non-`&self`/`&mut self`/`Box<Self>` receivers — design accordingly if dynamic dispatch is required.
- Blanket impls (`impl<T: Trait> Other for T`) are powerful but can create coherence conflicts downstream — use sparingly and document intent.
- Respect the orphan rule: implement a trait for a type only if you own the trait or the type (or use a local newtype to work around it).
- Resolve coherence violations ("conflicting implementations") by narrowing bounds, using newtypes, or restructuring trait ownership — not `#[allow]`.
- Prefer `where` clauses over inline bounds when the bound list grows or spans multiple type parameters.
- Don't add a generic parameter "for flexibility" without a concrete second caller — it's often premature abstraction.

## 6. Conversions
- Implement `From`/`TryFrom` for infallible/fallible conversions between owned types; implement `FromStr` for parsing from text.
- Implement `AsRef`/`AsMut` for cheap, borrowed reference conversions — not for anything with real cost.
- Avoid `as` for conversions that can silently truncate or wrap (`i64 as i32`, `f64 as i32`); use `TryFrom`/`TryInto` and handle the error.
- `as` is fine for widening numeric conversions that can't lose information (`u8 as u32`) and well-understood pointer/enum-discriminant casts.
- Prefer `Into`/`From` bounds in function signatures over manual conversion calls at every call site.
- Don't silently `.unwrap()` a `TryFrom` conversion on untrusted input.

## 7. Numeric & arithmetic
- Never use `as` to narrow an integer type when the value could be out of range — it truncates silently, no panic, no error.
- Remember debug builds panic on integer overflow but release builds wrap by default — don't rely on either implicitly.
- Use `checked_*` when overflow must be an error, `saturating_*` when clamping is correct, `wrapping_*` when wraparound is the intended semantic (hashing, checksums).
- Never compare floats with `==`; compare against an epsilon, and never use floats as `HashMap`/`match` keys.
- Use `NonZero*` types to make "never zero" a compile-time guarantee instead of a runtime assertion, especially for divisors.
- Guard against divide-by-zero and modulo-by-zero panics on integer types — validate or use `checked_div`/`checked_rem`.
- Be explicit about signed/unsigned mismatches in comparisons and arithmetic — mixing them is a common source of silent boundary bugs.

## 8. Memory & performance
- Avoid needless allocation: accept `&str`/`&[T]` instead of forcing callers to allocate `String`/`Vec`.
- Prefer iterator chains over manual index loops — clearer, and usually optimized as well or better.
- Use the `entry` API (`map.entry(k).or_insert_with(...)`) instead of `contains_key` + separate `insert` — one lookup, not two.
- Call `Vec::with_capacity`/`HashMap::with_capacity` when the final size is known or estimable, to avoid repeated reallocation.
- Use `Cow<str>`/`Cow<[T]>` when a function usually borrows but occasionally needs to own/modify — avoids allocating on the common path.
- Wrap file/socket I/O in `BufReader`/`BufWriter` — unbuffered syscall-per-byte or per-line I/O is a common accidental bottleneck.
- Don't `collect()` into an intermediate `Vec` just to immediately `.iter()` over it again — chain the adaptors instead.
- Swap the default `SipHash` `HashMap` hasher for a faster one (e.g. an FxHash-style hasher) in hot, non-adversarial-input paths.
- Don't allocate in a loop when the allocation can be hoisted and reused (`buf.clear()` + reuse instead of `Vec::new()` each iteration).

## 9. Async & concurrency
- Never hold a non-async-aware guard (`std::sync::MutexGuard`, `RwLockGuard`) across an `.await` point — it can deadlock the executor or block other tasks (guide §4.1).
- Offload blocking or CPU-bound work from an async context with `spawn_blocking` (or a dedicated thread pool) — don't block the runtime's worker threads.
- Prefer bounded channels over unbounded — unbounded channels turn backpressure problems into unbounded memory growth.
- Design futures for cancellation safety: a future dropped mid-`.await` must leave state consistent, especially in `select!` branches.
- Spawned tasks generally require `Send + 'static` — design shared state (`Arc<...>`) accordingly rather than fighting the compiler with lifetimes.
- Use an async-aware `Mutex` only when the lock must be held across an `.await`; otherwise a `std::sync::Mutex` for a synchronous critical section is cheaper.
- Avoid calling a blocking `block_on` from within an already-async context — it can deadlock a single-threaded runtime and wastes a thread on a multi-threaded one.
- Structure concurrent work with explicit cancellation/shutdown signals rather than relying on task abort.

## 10. Unsafe
- Minimize `unsafe` blocks; keep them as small as possible and isolate them behind a safe public API.
- Every `unsafe` block gets a `// SAFETY:` comment explaining which invariants must hold and why they hold here.
- Uphold all documented invariants of the unsafe operation (alignment, initialization, aliasing, lifetime) — violating any is instant undefined behavior, not just a bug.
- Test unsafe code under Miri to catch UB (invalid memory access, uninitialized reads, aliasing violations) that normal tests won't surface.
- Prefer an existing safe abstraction (standard library, well-audited crate) over hand-rolled `unsafe` for the same problem.
- Never reach for `unsafe` merely to silence the borrow checker — if the compiler is rejecting genuinely safe code, restructure instead.
- Document safety preconditions on any `unsafe fn` — what the caller must guarantee, not just what the function does.

## 11. Pattern matching
- Write exhaustive `match` arms over enums; let the compiler catch missing variants when the enum changes.
- Use `let-else` for the "extract or bail early" pattern instead of nested `if let`/`match` with an early return.
- Use `matches!(expr, pattern)` for a boolean pattern test instead of a full `match` returning `true`/`false`.
- Use if-let chains (stable from the 2024 edition, Rust 1.88+) to combine multiple conditions/bindings without deep nesting; verify availability on older toolchains.
- Avoid a catch-all `_ => {}` arm on enums you own — it silently swallows new variants instead of forcing a decision.
- A catch-all is fine (and often necessary) on enums you don't own, especially `#[non_exhaustive]` ones from external crates.
- Prefer destructuring in function parameters/`let` bindings over field-by-field access when it clarifies intent.

## 12. Closures & iterators
- Choose the tightest closure trait bound the API needs: `FnOnce` (call once) < `FnMut` (mutates captures) < `Fn` (read-only, callable repeatedly).
- Use `move` closures when the closure must outlive the current scope (spawned threads/tasks, returned closures); otherwise let borrowing capture stay implicit.
- Return `impl Fn(...) -> T` from factory functions instead of boxing to `Box<dyn Fn>` unless dynamic dispatch is actually required.
- Prefer iterator adaptor chains (`map`/`filter`/`fold`/`zip`) over manual loops with mutable accumulators.
- Avoid needless `.collect()` calls that immediately feed another iterator method — chain instead of materializing.
- Beware iterator laziness: side effects in `map` don't run until the iterator is consumed (`for`, `collect`, `sum`, etc.).
- Use `Iterator::sum`/`product`/`fold`/`try_fold` instead of hand-rolled accumulation where they fit directly.

## 13. Collections
- `Vec<T>` for ordered, index-accessed, growable sequences — the default absent a specific reason otherwise.
- `HashMap`/`HashSet` for unordered key lookup/membership; `BTreeMap`/`BTreeSet` when sorted iteration order or range queries are needed.
- `VecDeque` for a queue/ring buffer needing efficient push/pop at both ends.
- Use the `entry` API for map insert-or-update patterns instead of separate lookup-then-mutate calls.
- Use `HashSet`/`BTreeSet` for membership testing instead of linear-scanning a `Vec` with `.contains()` once the collection is nontrivially sized.
- Choose `BinaryHeap` for priority-queue semantics rather than repeatedly sorting a `Vec`.

## 14. Serde
- Use `#[serde(rename_all = "camelCase")]` (or matching convention) to keep Rust-idiomatic field names while matching the wire format.
- Use `#[serde(default)]` (or `default = "fn"`) for optional fields instead of making everything `Option<T>`.
- Add `#[serde(deny_unknown_fields)]` where strict schema validation matters; omit it where forward-compatible parsing is the goal.
- Choose enum tagging deliberately: external (default), internally tagged (`tag = "type"`), adjacently tagged, or untagged — each has different ambiguity/performance tradeoffs.
- Use `#[serde(borrow)]` with `&str`/`&[u8]` fields to deserialize without allocating, when the input buffer outlives the value.
- Use `#[serde(skip_serializing_if = "...")]` to omit empty/default fields from output.
- Derive `Serialize`/`Deserialize` rather than hand-writing impls unless the wire format genuinely can't be expressed declaratively.

## 15. Macros
- Reach for a plain function, generic, or trait first — write a macro only when the pattern genuinely can't be expressed otherwise (varying arity, token manipulation, compile-time codegen).
- Write declarative (`macro_rules!`) macros hygienically — don't assume call-site identifiers are in scope, and use `$crate` for paths back into your own crate.
- Build proc-macros with `syn` (parsing) and `quote` (codegen) rather than hand-rolling token-stream manipulation.
- Document macro-generated public API just as thoroughly as hand-written API.
- Keep macro-generated code debuggable: prefer generating calls to real functions over inlining large logic bodies.
- Test macros with both valid and invalid inputs (e.g. `trybuild`) to verify error messages stay comprehensible.

## 16. Naming & style
- Follow the conversion-method conventions: `as_*` (cheap borrowed view), `to_*` (possibly expensive, often cloning), `into_*` (consumes `self`).
- Follow the iterator-method conventions: `iter()` (borrowed `&T`), `iter_mut()` (borrowed `&mut T`), `into_iter()` (owned `T`).
- No Hungarian notation and no type suffixes in variable names (`user_list_vec`) — the type system already tracks type.
- Avoid module::type stutter — `config::Config` not `config::ConfigConfig`; `http::Client` not `http::HttpClient`.
- Use `snake_case` for functions/variables/modules, `UpperCamelCase` for types/traits/variants, `SCREAMING_SNAKE_CASE` for consts/statics.
- Prefer short, precise names scoped to their context over long disambiguated names that only matter at broader scope.
- Name booleans as predicates (`is_ready`, `has_children`) so call sites read naturally.

## 17. Documentation
- Add `///` doc comments to every public item — module, type, function, trait, variant, non-obvious field.
- Make doc examples runnable (` ```rust ` blocks) — `cargo test` runs them as doctests and catches drift automatically.
- Include `# Errors`, `# Panics`, and `# Safety` sections on functions where applicable.
- Use intra-doc links (`` [`OtherType`] ``) so docs stay navigable and rustdoc verifies the referenced item exists.
- Add `#![warn(missing_docs)]` at a library crate root to enforce documentation coverage on public API.
- Write the crate-level `//!` doc as the entry point: what the crate does, a minimal usage example, key types.
- Keep doc examples minimal and focused — one concept per example.

## 18. Testing
- Put unit tests in `#[cfg(test)] mod tests` alongside the code, for access to private items.
- Put integration tests in `tests/` — they compile against the crate's public API only, exercising it like a consumer.
- Keep doc examples runnable as doctests — they're both documentation and regression coverage.
- Use property-based testing for functions with invariants over a wide input space (parsers, codecs, arithmetic), not just hand-picked cases.
- Avoid asserting on `Debug`-formatted strings for behavioral correctness — assert on actual values/structure instead.
- Test error paths explicitly — assert on the error variant/kind, not just that it returned `Err`.
- Name tests for the behavior under test (`rejects_empty_input`), not the function (`test_parse`).
- Use `#[should_panic]` sparingly and with an `expected` substring — a bare one passes on any panic.

## 19. Observability
- Prefer `tracing` over `log` in async code — spans follow execution across `.await` points and concurrent tasks; plain `log` doesn't.
- Use structured fields (`tracing::info!(user_id = %id, "processed")`) instead of string interpolation — structured data is queryable downstream.
- Wrap logical units of work in spans (`#[tracing::instrument]` or manual entry) so nested/async operations are attributable to their parent.
- Choose log levels deliberately: `error` for actionable failures, `warn` for degraded-but-recovering, `info` for lifecycle events, `debug`/`trace` for diagnostics.
- Don't log secrets, tokens, or full request/response bodies at default verbosity.
- Record error context (operation, relevant IDs, underlying `Display`), not just "failed".

## 20. Project structure
- Use a workspace once a project has more than one logically separate crate (`core`/`cli`/`server`) sharing a lockfile.
- Organize modules by domain/responsibility, not by kind (avoid a flat `models.rs`/`utils.rs`/`helpers.rs` grab bag as the project grows).
- Keep feature flags additive (enabling one only adds capability, never changes default behavior) and minimal.
- Set and document an MSRV (minimum supported Rust version); verify it in CI against exactly that toolchain.
- Keep `lib.rs`/`main.rs` thin — module declarations, re-exports, top-level wiring; push real logic into named modules.
- Re-export the public API deliberately at the crate root (`pub use`) rather than forcing consumers to know internal module paths.
- Separate binary-only concerns (CLI parsing, process setup) from library logic so the core is testable without a process boundary.

## 21. Linting & CI
- Run `cargo fmt --check` in CI to enforce consistent formatting without debate.
- Run `cargo clippy -- -D warnings` (with `--all-targets --all-features`) in CI — clippy catches correctness and idiom issues rustc alone won't.
- Deny warnings in CI builds so drift can't accumulate silently.
- Run `cargo audit` (known vulnerabilities) and `cargo deny` (license/duplicate/ban checks) as part of CI, not ad hoc.
- Include a build-matrix entry with minimal/no default features (`--no-default-features`) to catch accidental feature-coupling.
- Pin CI to (at least) the crate's stated MSRV in addition to stable, so MSRV claims stay honest.

## 22. Common anti-patterns (quick index)
- Cloning to satisfy the borrow checker instead of restructuring borrows or using `mem::take`/split borrows.
- `unwrap()`/`expect()` scattered through library code instead of propagating `Result` with `?`.
- Reflexive `Box<dyn Trait>` everywhere instead of evaluating static dispatch first.
- `Deref`/`DerefMut` used for inheritance-style polymorphism instead of its intended smart-pointer role.
- Stringly-typed errors (`Err("something went wrong".to_string())`) instead of a proper error enum.
- `#[allow(...)]` used to silence a lint instead of fixing the underlying issue.
- `as` used for narrowing numeric casts instead of `TryFrom`/`TryInto`.
- Unbounded channels that turn backpressure into unbounded memory growth.
- Blocking calls (`std::thread::sleep`, sync I/O, `block_on`) executed directly inside async task bodies.
- God-structs holding unrelated state and behavior instead of decomposed, single-responsibility types.
- Primitive obsession — bare `String`/`u64`/`bool` parameters where a newtype or enum would prevent misuse.
- `.clone()` on `Arc`/`Rc` misread as a deep copy, or reached for reflexively instead of borrowing.
