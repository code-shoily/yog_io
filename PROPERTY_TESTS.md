# Property-Based Tests for yog_io

This document describes the property-based testing strategy for `yog_io`, including invariants, hypotheses, and format limitations.

## Overview

Property-based tests use the `qcheck` library to generate random graphs and verify that serialization roundtrips preserve essential properties. Unlike example-based tests, these tests explore a wide range of graph structures and catch edge cases that manual tests might miss.

## Running Property Tests

```bash
# Run all tests (including property tests)
gleam test

# Run specific property test
gleam test yog_io@property_test.graphml_structural_roundtrip_property_test
```

## Invariants by Format

### GraphML Format

**Invariants Tested:**
- ✅ **Structural Equality**: Complete graph topology preserved (nodes, edges, connectivity)
- ✅ **Graph Type**: Directed/Undirected property maintained
- ✅ **Node Data**: All node attributes preserved
- ✅ **Edge Data**: All edge attributes preserved
- ✅ **Node IDs**: Original IDs maintained
- ✅ **Node Count**: Number of nodes unchanged
- ✅ **Edge Count**: Number of edges unchanged

**Hypotheses:**
- Identity attribute mappers (`fn(x) { x }`) produce exact roundtrips
- Empty graphs serialize and deserialize correctly
- Unicode characters in labels are preserved

**Limitations:**
- None significant; GraphML is the most robust format for roundtrip fidelity

---

### JSON Format (Generic)

**Invariants Tested:**
- ✅ **Structural Equality**: Complete graph topology preserved
- ✅ **Graph Type**: Directed/Undirected property maintained
- ✅ **Node Count**: Number of nodes unchanged
- ✅ **Edge Count**: Number of edges unchanged
- ✅ **Node IDs**: Original IDs maintained

**Hypotheses:**
- Default export options preserve all graph data
- Custom serializers can maintain type safety
- Multigraph edge IDs are unique and preserved

**Limitations:**
- Only Generic format supports bidirectional read/write
- D3.js, Cytoscape.js, vis.js, and NetworkX formats are write-only
- Empty node/edge data may serialize as `null`

---

### GDF Format

**Invariants Tested:**
- ✅ **Structural Equality**: Complete topology for non-empty graphs
- ✅ **Node Count**: Number of nodes unchanged
- ✅ **Edge Count**: Number of edges unchanged
- ⚠️ **Graph Type**: Determined from edge data (may default for empty graphs)

**Hypotheses:**
- CSV escaping preserves special characters (commas, quotes, newlines)
- Custom separators work correctly
- Type annotations don't affect data parsing

**Limitations:**
- Empty graphs cannot reliably determine graph type (no `directed` column)
- Node IDs may be reassigned if not sequential
- Extra nodes may be created from edge references

---

### TGF Format

**Invariants Tested:**
- ✅ **Node Count**: Number of nodes preserved (with auto-creation)
- ✅ **Edge Count**: Number of edges maintained
- ✅ **Graph Type**: Preserved when explicitly specified
- ⚠️ **Structural Equality**: Best-effort; auto-node creation can add nodes

**Hypotheses:**
- Auto-node creation provides lenient parsing
- Multi-word labels with spaces are handled
- Separator line (`#`) is correctly identified

**Limitations:**
- Node IDs in edge section that don't exist in node section create new nodes
- Graph type must be specified at parse time (not in format)
- No native support for edge data (labels optional)

---

### LEDA Format

**Invariants Tested:**
- ✅ **Node Count**: Number of nodes preserved
- ✅ **Edge Count**: Number of edges maintained
- ✅ **Graph Type**: Directed (`-1`) vs Undirected (`-2`) preserved
- ⚠️ **Structural Equality**: Node IDs renumbered to 1-indexed sequential

**Hypotheses:**
- `|{...}|` delimiters correctly parsed
- Reversal edge indices handled for undirected graphs
- Type declarations don't enforce actual types

**Limitations:**
- Node IDs are ALWAYS renumbered to 1, 2, 3... (sequential)
- Original node IDs are lost
- Strict format requires exact line structure

---

### Pajek Format

**Invariants Tested:**
- ✅ **Node Count**: Number of nodes preserved
- ✅ **Edge Count**: Number of edges maintained
- ✅ **Graph Type**: Preserved via `*Arcs` vs `*Edges`
- ⚠️ **Structural Equality**: Node IDs renumbered; edge weights may change type

**Hypotheses:**
- Multi-word quoted labels parsed correctly
- Case-insensitive section headers (`*Arcs` = `*arcs`)
- Optional weights parsed when present

**Limitations:**
- Node IDs renumbered to 1, 2, 3... based on *Vertices section order
- Edge weights parsed as Float (may lose String data)
- Visual attributes (coordinates, shapes, colors) not fully supported

---

## Structural Equality Definition

Two graphs are **structurally equal** if and only if:

```gleam
graphs_structurally_equal(g1, g2) :=
  g1.kind == g2.kind &&
  g1.nodes == g2.nodes &&                    // Same IDs with same data
  g1.out_edges == g2.out_edges &&            // Same connectivity
  model.node_count(g1) == model.node_count(g2) &&
  model.edge_count(g1) == model.edge_count(g2)
```

### Format Support Matrix

| Format | Structural Equality | Notes |
|--------|---------------------|-------|
| GraphML | ✅ Full | Best format for fidelity |
| JSON | ✅ Full | Perfect with Generic format |
| GDF | ✅ Non-empty | Type detection from edges |
| TGF | ⚠️ Partial | Auto-node creation |
| LEDA | ❌ No | IDs renumbered 1, 2, 3... |
| Pajek | ❌ No | IDs renumbered 1, 2, 3... |

## Common Property Test Patterns

### 1. Roundtrip Invariant
```gleam
graph == graph |> serialize |> deserialize
```

### 2. Node Preservation
```gleam
model.node_count(graph) == model.node_count(parsed)
```

### 3. Edge Preservation
```gleam
model.edge_count(graph) == model.edge_count(parsed)
```

### 4. Type Preservation
```gleam
graph.kind == parsed.kind
```

### 5. Undirected Symmetry
```gleam
// For undirected graphs: edge(u, v) implies edge(v, u)
edge(u, v) ∈ g ↔ edge(v, u) ∈ g
```

## Edge Cases Covered

- **Empty graphs**: No nodes, no edges
- **Single node**: One node, no edges
- **Single edge**: Two nodes, one connection
- **Isolated nodes**: Nodes with no edges
- **Dense graphs**: Many edges between few nodes
- **Sparse graphs**: Few edges among many nodes
- **Path graphs**: Linear chain structure
- **Star graphs**: Hub-and-spoke topology

## Shrinking and Debugging

When a property test fails, `qcheck` automatically **shrinks** the counterexample to find the minimal failing case:

```
 panic: test: yog_io@property_test.json_roundtrip_property_test
 info: a property was falsified!
qcheck assert test/yog_io/property_test.gleam:336
 code: assert graphs_structurally_equal(parsed, graph)
 left: Graph(Directed, dict.from_list([...]), ...)
right: Graph(Undirected, dict.from_list([...]), ...)
 info: Assertion failed.
qcheck shrinks
 orig: Graph(Directed, dict.from_list([#(1, "A"), #(2, "B"), #(3, "C")]), ...)
shrnk: Graph(Directed, dict.from_list([#(1, "A")]), ...)
steps: 3
```

This shows:
- Original failing case (3 nodes)
- Shrunk minimal case (1 node)
- Specific assertion that failed

## Adding New Property Tests

To add a property test for a new format:

```gleam
/// My format roundtrip property
pub fn myformat_roundtrip_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())
  
  let serialized = myformat.serialize(graph)
  let assert Ok(parsed) = myformat.deserialize(serialized)
  
  // Choose appropriate invariant based on format capabilities:
  
  // For formats with full structural fidelity:
  assert graphs_structurally_equal(parsed, graph)
  
  // For formats with ID remapping:
  assert model.node_count(parsed) == model.node_count(graph)
  assert model.edge_count(parsed) == model.edge_count(graph)
}
```

## References

- [qcheck documentation](https://hexdocs.pm/qcheck/)
- [Property-based testing guide](https://hypothesis.works/articles/what-is-property-based-testing/)
- [yog graph library](https://hex.pm/packages/yog)
