## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## bahasa & communication style

Always follow the natural, terse, zero-fluff communication rules defined in `bahasa.md` and `.agents/rules/bahasa.md`:
- Bahasa Indonesia santai, natural, to the point.
- Tanpa basa-basi pembuka & penutup.
- Singkat, padat, jelas, tanpa kata-kata membingungkan.
- Istilah teknis & kode tetap Bahasa Inggris.


