# MostlyText dependency patches

This owner fork retains the original BSD-3-Clause LICENSE unchanged. The current
runtime baseline is dabf50c947148c49acd0d321dfe8f3805d10b3da; the manifest-only
child e1e0c6de7f299fd8e9ff2b5ecb468d04ee6d50a9 pins the application-reviewed
SwiftTreeSitter fork 1b1c85e94df6421a0e4bdcb9f3afaddb16b75d43.

## Embedded-language invalidation and query readiness

Root edits now invalidate embedded-language work. Content epoch and shifted
validity are published before synchronous parse completion, and sublayer
invalidation precedes external callbacks. Sync queries defer with nil while
inline validation is unfinished; async queries wait and reject obsolete content
with CancellationError. Processing begins inside the highlight provider after
capturing its epoch, so reentrant edits cannot escape that guard.

SinglePhaseRangeValidator completion now counts a running provider and scheduled
follow-up regions as unfinished work. Its old queue-empty check returned after
dequeue but before provider completion. The public API signatures are retained;
a package-only validity accessor supports TreeSitterClient readiness checks.

ValidationCompletionTests uses a controlled continuation gate for single and
disjoint regions, including an in-flight completion observer. The MostlyText
application adds strict warmed Markdown/fresh-client controls across Unicode,
three line endings, three edit shapes and ordinary/reentrant callbacks, plus a
reentrant content-epoch cancellation test. Source-identical Foundation/C-only
RangeState and TreeSitterClient fixtures pass Debug and Release, including the
existing thousand-insert/query stress test. Original-source regressions and
failed intermediate/setup controls are retained in the application's evidence
packet. Full application hosted CI is required for adoption.

The client correction alone does not fix buffered style-coordinate drift;
the next section records that separate repair. Neither correction widens parser
thresholds, raises the application fallback, proves complete-editor latency or
establishes native acceptance. Grammar bytes and public styling APIs remain
unchanged; no upstream contribution is made.

## Buffered repaint coordinates

A package-only edit notification transforms retained dirty intervals before
TextViewHighlighter asks the client to publish the new edit's invalidations.
Preserve surviving source before and after deletions, shift the latter, and
conservatively include replacement text touching a dirty interval. Keep idle,
all-document, nested-depth and reentrant-flush behavior. Interval sweeps avoid
per-character work; generic NSRange.apply is not used because a deletion across
an interval's beginning can otherwise drop its surviving tail.

BufferedCoordinateTests includes an independent per-character oracle over
75,772 small edit cases, successive-edit/nesting checks, deleted-tail survival,
all-document and idle states, sparse coordinates and reentrant scope ownership.
The baseline-only no-op notification shim explicitly models the absent old API;
it is not native execution. Full application hosted qualification of the actual
TextViewHighlighter callback order remains required. This does not activate the
widened background experiment or establish complete-editor performance.

## Partial style-query containment without changing semantic tokens

A partial query may return a capture extending outside its paint authority.
Keep that complete semantic Token for attribute providers and source geometry.
The package-only TokenApplication.forEachTokenToApply iterator yields the
original token plus a separately intersected painting range. All three concrete
text-system interfaces call the provider with the original token and apply its
attributes only within the painting range. Public signatures, name mapping,
clearing behavior and scheduling remain unchanged.

The first hosted run exposed a wide italic capture overwriting unqueried nested
styles. An initial token-clipping attempt fixed that visual comparison but broke
the established byte-geometry provider contract in the next hosted run. Both
failures are retained. Final controls separately require complete semantic token
ranges and bounded paint ranges, including empty/disjoint/nil authority. The
actual warmed-client outside-query property remains active: hosted tests use
the real TextStorageSystemInterface, while the inspected Foundation fixture uses
the exact iterator with memory styles. No native conditional tail runs locally.

Compile-only standalone qualification temporarily seeds the exact application
lock and restores the historical dependency-root lock afterward; the application
lock remains the tested resolution authority. No application transitive version
changes. Full corrected-head hosted CI, including unchanged byte-geometry and
style checks, remains required.

## Complete injection coverage dependency

This manifest-only child pins SwiftTreeSitter7d2dc87e8b9326062d75bc1ef985f17d28e94da9.
It extends partial injection queries over old as well as fresh capture extents
and adds a default-true per-language tree-reuse policy. MostlyText explicitly
disables reuse only for MarkdownInline after a valid UTF-16 scalar edit exposed
a fresh-tree discrepancy. All Neon runtime/test bytes and original BSD licence
are identical to baf93c72924e31e16b84adced6ee29cb02934c3b. The application lock
remains qualification authority; no unrelated dependency is upgraded.

## Runtime range-lookup transitive pin

This manifest-only child pins SwiftTreeSitter0beea992c4246f93a122de846c8611c9be19aeb7,
which pins owner tree-sitter5ce80b6f0e29096a5f06826a3ba610c4e89bc255. Every
Neon runtime/test byte remains identical to be25e35787585430f0f1ac845ed44c11e7f8150a
and baf93c72924e31e16b84adced6ee29cb02934c3b. Original BSD licence is unchanged;
the application lock is qualification authority. See the runtime patch manifest
for behavior-preservation proof and explicit original fresh-tree/Rustdoc failures.

## One-phase style-result version ownership

TokenSystemValidator rechecks the request's content version after both async
provider completion and synchronous provider return, immediately before the
style interface receives any result. A provider can suspend or reenter editing;
obsolete results return the existing Validation.stale without touching styles.
No public API, validation scheduling, buffer, geometry or parser pin changes.

Exact-source Foundation-only controls fail24 assertions before this correction:
shrunk/grown/same-length changes across a controlled await and synchronous
reentrant edits, each with apply/replace actions. Unchanged-content application
and already-obsolete-request skip controls pass before/after. All46 component
functions plus8 XCTest cases pass Debug/Release after the repair, including
previous client/style/buffer/range and2,000-scalar-edit regressions. The first
fixture compiler crashes lowering the generic default sync closure; supplying
an explicit nil sync closure avoids the compiler defect without changing the
provider contract, test assertions or compiler/language mode. Both first failure
and actual24-assertion baseline are retained by the app evidence packet.

Actual hosted Neon/application integration remains required before adoption;
this narrow return boundary does not establish mounted editor lifecycle, the
original parser abort, native Release stress or full-editor responsiveness.
Original BSD text and every preceding owner repair remain unchanged.
