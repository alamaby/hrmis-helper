## $(date +%Y-%m-%d) - Added keyboard navigation and accessibility tooltip to Credential Form
**Learning:** In Flutter, `IconButton`s without tooltips lack semantic meaning for screen readers. Adding a tooltip automatically acts as an accessibility label. Additionally, utilizing `TextInputAction.next` and `TextInputAction.done` on `TextFormField`s allows seamless keyboard progression and submission. Double-submission prevention is also essential when enabling soft-keyboard submission.
**Action:** Always verify that icon-only buttons have descriptive `tooltip`s for accessibility, map out keyboard paths using `textInputAction`, and secure submission paths with boolean locks to prevent duplicate asynchronous calls.

## 2024-10-12 - Prevent fragmented screen reader audio in visual rows/cards
**Learning:** In Flutter, the default screen reader behavior fragments visually distinct, multi-child rows and cards (like a metric card or an info row) into multiple disjointed readouts, which creates poor audio UX. Grouping the entire component in a `Semantics` widget with `excludeSemantics: true` and a unified comma-separated `label` results in a significantly smoother and more coherent screen reader experience.
**Action:** When creating visually complex data displays (like cards or rows with multiple text components), wrap them in a `Semantics` widget combining their values, instead of relying on Flutter's default child-by-child reading.

## 2026-10-15 - Added credential autofill support
**Learning:** In Flutter, wrapping a form in an `AutofillGroup` and setting `autofillHints` and `keyboardType` properties enables native OS password managers to save and fill credentials. This requires calling `TextInput.finishAutofillContext()` upon successful validation to signal the OS to save the credentials.
**Action:** Add autofill support to all login and credential forms to improve user experience and reduce friction.

## 2024-05-24 - Accurate Visual State Indicators
**Learning:** Using a static checkmark icon (`Icons.task_alt`) for all status messages—even when an operation is "checking", "pending", or has "failed"—creates cognitive dissonance and visual confusion. Users rely heavily on visual cues like spinners for active tasks or warning icons for errors to quickly understand system state without reading the full text.
**Action:** Always dynamically map icons to their corresponding states (e.g., `CircularProgressIndicator` for loading/checking, `error_outline` for failures) instead of hardcoding a success icon next to a dynamic text message.
