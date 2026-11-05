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

## Partial style-query containment

The first application hosted run exposed a wide italic capture overwriting
nested styles outside its requested dirty range. Named-range TokenApplication
initializers now clip each emitted token to the requested range, retaining
capture order and name mapping and dropping empty intersections. A narrow query
cannot restyle an unqueried neighbor. Both existing initializer signatures are
preserved; the generic TokenApplication initializer is unchanged. The actual
warmed-client/partial-application reproduction fails twice before this correction
and passes afterward. A separate control covers mapping, ordering, disjoint and
empty captures. Hosted rerun of the original failing app check is required.
