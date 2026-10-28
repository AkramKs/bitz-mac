## 2024-05-18 - Caching dlopen and Arrays in High-Frequency Polling
**Learning:** Functions called on a frequent timer (e.g. `ActivityMonitorService` ticking every 5 seconds) should not perform expensive operations like `dlopen`, symbol resolution (`dlsym`), or constantly reallocate static collections (`Set` and `Array`).
**Action:** Always hoist configuration arrays/sets to `static let` properties and cache dynamically loaded pointers (like `IOHIDEventSystemClient`) during initialization to avoid repeated allocations and kernel calls in hot paths.
