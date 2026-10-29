const title = "⚡ Bolt: Avoid array reallocations in readActiveChromiumTab";
const body = `Closes #29

💡 What: Hoisted inline array literals (\`relativeBaseDirs\`) into static constants within \`BrowserTabTelemetryReader\`.
🎯 Why: \`readActiveChromiumTab\` is part of a high-frequency polling path that runs every 5 seconds. Re-creating these array literals inside the \`if/else\` block on every call causes unnecessary repeated memory allocations, which adds overhead and triggers the garbage collector/ARC more frequently.
📊 Impact: Eliminates array heap allocations during the chromium tab monitoring tick, improving battery life and performance overhead.
🔬 Measurement: Verify by visual code inspection and observing reduced memory allocation footprint during prolonged profiling.`;
const content = `${title}\n${body}`;
const ticketPattern = /(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?|issue|ref[s]?)\s*:?\s*#\d+/i;
console.log(ticketPattern.test(content));
