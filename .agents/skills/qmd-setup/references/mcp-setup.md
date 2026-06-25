# QMD MCP Server Setup

## Setup prerequisite

Use the `qmd-setup` skill to prepare collections and index content before using
the MCP server.

## Configure MCP Client

Create or update a repository-local `.mcp.json` file:
```json
{
  "mcpServers": {
    "qmd": { "command": "qmd", "args": ["mcp"] }
  }
}
```

## HTTP Mode

```bash
qmd mcp --http              # Port 8181
qmd mcp --http --daemon     # Background
qmd mcp stop                # Stop daemon
```

## Tools

### query

Search with structured queries.

```json
{
  "searches": [
    { "type": "lex", "query": "keyword phrases" },
    { "type": "vec", "query": "natural language question" },
    { "type": "hyde", "query": "hypothetical answer passage..." }
  ],
  "collections": ["optional-collection"],
  "limit": 10
}
```

| Type | Method | Input |
|------|--------|-------|
| `lex` | BM25 | Keywords (2-5 terms) |
| `vec` | Vector | Question |
| `hyde` | Vector | Answer passage (50-100 words) |

### get

Retrieve document by path or `#docid`.

| Param | Type | Description |
|-------|------|-------------|
| `path` | string | File path or `#docid` |
| `full` | bool? | Return full content |
| `lineNumbers` | bool? | Add line numbers |

### multi_get

Retrieve multiple documents.

| Param | Type | Description |
|-------|------|-------------|
| `pattern` | string | Glob or comma-separated list |
| `maxBytes` | number? | Skip large files (default 10KB) |

### status

Index health and collections. No params.

## Troubleshooting

- **Not starting**: `which qmd`, `qmd mcp` manually
- **No results**: `qmd collection list`, `qmd embed`
- **Slow first search**: Normal, models loading (~3GB)
