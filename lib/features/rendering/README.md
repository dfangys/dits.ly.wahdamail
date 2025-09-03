# Rendering/Preview Pipeline (P10)

Data flow
Body/Attachments → HtmlSanitizer + CidResolver → RenderedContent

Policy
- Default block remote content (http/https images). allowRemote=true will keep <img> but no fetching occurs in P10
- Strip <script>, <iframe>, inline event handlers (on*), external CSS, and dangerous attributes (javascript:)

Cache
- PreviewCache: LRU (max 100 items); least-recently used eviction

Notes
- No UI/webview changes; infra-only. No network fetches.
- No DB schema/index changes.
- Flags remain OFF.

# rendering

