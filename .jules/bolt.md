## 2024-10-24 - Prevent unnecessary WebView re-renders
**Learning:** Calling setState unconditionally for status updates triggers expensive re-renders of the heavy InAppWebView container, even when the value hasn't changed.
**Action:** Always check if the state value actually changed (e.g., `if (_status == status) return;`) before calling setState, especially when the widget tree contains expensive native views.
