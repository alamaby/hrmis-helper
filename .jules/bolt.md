## 2024-05-20 - Stateful widget wrapper around InAppWebView performance issue
**Learning:** In this Flutter architecture, the root widget contains a heavy `InAppWebView`. Frequent status updates that call `setState` without checking if the value actually changed will cause expensive, unnecessary re-renders of the native WebView container.
**Action:** Always verify if a state variable (especially frequent ones like status messages) has actually changed before calling `setState` when the widget tree contains expensive native views like `InAppWebView`.
