## 2024-05-18 - Caching dlopen and Arrays in High-Frequency Polling
**Learning:** Functions called on a frequent timer (e.g. `ActivityMonitorService` ticking every 5 seconds) should not perform expensive operations like `dlopen`, symbol resolution (`dlsym`), or constantly reallocate static collections (`Set` and `Array`).
**Action:** Always hoist configuration arrays/sets to `static let` properties and cache dynamically loaded pointers (like `IOHIDEventSystemClient`) during initialization to avoid repeated allocations and kernel calls in hot paths.

## 2026-10-28 - Avoid array reallocations in fast paths
**Learning:** Arrays created in frequently called methods like `containsDopamineStreamingOrSocialKeyword` and `readActiveChromiumTab` cause repeated memory allocations in Swift which slows down fast paths.
**Action:** Always hoist local array literals inside frequently called loops or monitoring ticks to static constants (`private static let`) in their respective classes or namespaces to reuse the same memory.
