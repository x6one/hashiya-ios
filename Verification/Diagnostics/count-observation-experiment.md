Count observation diagnostic prepared from c8903523e8831b24d78e87923ea966408dd5419d.

Status: Diagnostic candidate; native validation pending. Not adopted on the
development branch and not release acceptance.

Rail event and geometry records use the same sequence in two bounded lines;
omit generic hosting-controller type descriptions to avoid NSLog truncation.
Log the public native navigation layout direction and screen-edge recognizer
edge flags when its public type permits; do not assume an Arabic SwiftUI
environment proves the native navigation controller uses the right edge.

Question: does unnecessary XCTest description work consume count observation
deadlines after PencilKit has already restored the native stroke? The current
Push iPad control fails the redo5s waiter and later reads actual2/expected2;
artifact-level action/callback timing is still pending. This is not proof of a
permanent XCUIElement cache or of a product redo failure.

Control: c890352 Push39151098686/iPad117744734863. Live log shows redo input
at303.56s, first count observation305.14s, automatic element description309.37s,
the five-second waiter failure, then later actual2/expected2 at320.68s. Fit Width
also retains2 at350.65s; the case reaches360s during portrait cleanup. Completed
control artifact and any native timing remain pending; later truth does not
retroactively satisfy the waiter. PR control39151102579 remains separate.

Controlled change: only saved/undo/redo expectation object arguments inside
exerciseIndividualInkTargets change from count to nil. Their closures still
capture the same count element and require the same values. All32original UI
methods, assertions, thresholds, gestures, functional5/10s deadlines and original
case allowances remain unchanged. Other expectation object arguments stay intact.

Native observations: DEBUG plus --test-margin-viewport gates a maximum256events
per process. Record undo/redo action begin/end, drawingDidChange only outside
active strokes, tool-ended, persistence begin/unchanged/callback-returned, and
store-save-returned with its actual store.saved flag. Each event includes native
canvas identity, current coordinator/page ownership where available, drawing
stroke count, monotonic uptime and actual Thread.isMainThread. Callback return
alone is explicitly not represented as proof of a successful file write.
No layer traversal, synthetic state, drawing mutation, extra cleanup, or per-frame
logging is introduced. Stripping DEBUG blocks leaves the two App files equivalent
to the control's Release source. DEBUG logging can perturb timing; it is diagnostic
evidence, not a success criterion by itself.

Additional pure DEBUG rail observations address the new c890 phone no-movement
failure at fitMarginWidth and the later Standard picker-dismissal failure.
A transparent, noninteractive and non-AX UIView is installed behind only the
InkToolbar HStack when --test-margin-viewport is present. It observes the nearest
native UIScrollView pan and the public navigation content/edge recognizers using
addTarget/removeTarget only. It never sets their delegates, enabled state, failure
dependencies, scroll offsets or scroll configuration. Weak references avoid
retaining obsolete recognizers/controllers. Window detachment, identity changes
and representable dismantling remove this observer's targets; dismantling blocks
reconnection. Connection logs occur only when identity/configuration changes,
not merely on layout or offset changes. Gesture callbacks include at most12Changed
samples per gesture and256total events per process, with actual window location,
recognizer identity/state/enabled flag, scroll frame/content/offset/adjusted insets,
scroll-enabled/bounces, and navigation stack/top/owner identity. No AX label or
test selector is added. Accessing public recognizer getters and installing targets
may itself affect timing or lazy initialization; a passing observer run does not
prove the uninstrumented c890 navigation policy is repaired.

Separate branch-only workflow: diag/tayya-count-observation, named Tayya targeted
count observation diagnostic. One iPad job runs67units plus the historical ten
preceding UI cases and both original ink cases. Functional/case budgets are the
same240default/360maximum;45min is only a whole-job collector/build envelope.
Actual execution order/counts must be confirmed from the resulting native log.
Files setup/byte verification retained. Raw xcresult ZIP/hash precedes attachment
export and native collection. The selective native collector retains all streamed
bytes for at most90s; its sole writer closes before retained-byte metadata is
captured, and partial/error status is explicit. This job cannot satisfy full
preflight/release acceptance. No Office, IPA, signing or production workflow edits.
XCTest subsystem records are retained as well as targeted app events so the
testmanager hierarchy phase can be distinguished from the app-side snapshot.

Validation performed locally:13Tools tests pass; controlled-source checker proves
exactly3expectation object substitutions and unchanged Release source; YAML,
embedded Python and all shell blocks parse; git diff --check passes. Swift/iOS
compilation and native behavior remain unverified here.

Interpretation: compare event timestamps for action entry, actual count change,
save callback and each count poll's AX capture/description. A later correct count
cannot retroactively satisfy the original waiter. Compare diagnostics against the
unmodified c890 control and preserve the full control-run artifacts.
