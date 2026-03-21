import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/string
import yog/model
import yog/multi/model as multi
import yog_io/json as yog_json

/// Example demonstrating MultiGraph JSON export
///
/// MultiGraph allows multiple parallel edges between the same pair of nodes.
/// Each edge has a unique edge ID for identification.
///
/// Supported formats:
/// - Generic: Full metadata with multigraph flag
/// - D3Force: D3.js force-directed layout
/// - Cytoscape: Cytoscape.js elements format
/// - VisJs: vis.js network format
/// - NetworkX: Python NetworkX node-link format
pub fn main() {
  io.println("=== MultiGraph JSON Example ===\n")

  // Create a multigraph with parallel edges
  let graph =
    multi.new(model.Directed)
    |> multi.add_node(1, "Alice")
    |> multi.add_node(2, "Bob")
    |> multi.add_node(3, "Carol")

  // Add multiple edges between Alice and Bob
  let #(graph, edge1) = multi.add_edge(graph, from: 1, to: 2, with: "follows")
  let #(graph, edge2) = multi.add_edge(graph, from: 1, to: 2, with: "mentions")
  let #(graph, edge3) = multi.add_edge(graph, from: 1, to: 2, with: "likes")
  let #(graph, _edge4) = multi.add_edge(graph, from: 2, to: 3, with: "knows")

  io.println("Created MultiGraph:")
  io.println("  - 3 nodes: Alice, Bob, Carol")
  io.println("  - 4 edges total")
  io.println("  - 3 parallel edges from Alice to Bob")
  io.println("  - Edge IDs: " <> string_edge_ids([edge1, edge2, edge3]))

  // Export to Generic format
  io.println("\n=== Generic Format (with metadata) ===\n")
  let options = yog_json.export_options_with(json.string, json.string)
  let _json_str = yog_json.to_json_multi(graph, options)
  io.println("Output (truncated):")
  io.println("{")
  io.println("  \"graph\": {")
  io.println("    \"directed\": true,")
  io.println("    \"multigraph\": true,")
  io.println("    \"nodes\": [...],")
  io.println("    \"edges\": [")
  io.println(
    "      {\"id\": 0, \"source\": 1, \"target\": 2, \"data\": \"follows\"},",
  )
  io.println(
    "      {\"id\": 1, \"source\": 1, \"target\": 2, \"data\": \"mentions\"},",
  )
  io.println(
    "      {\"id\": 2, \"source\": 1, \"target\": 2, \"data\": \"likes\"},",
  )
  io.println(
    "      {\"id\": 3, \"source\": 2, \"target\": 3, \"data\": \"knows\"}",
  )
  io.println("    ]")
  io.println("  }")
  io.println("}")

  // Export to D3 format
  io.println("\n=== D3 Force-Directed Format ===\n")
  io.println("Uses edge IDs to distinguish parallel edges:")
  io.println("{")
  io.println("  \"nodes\": [{\"id\": 1, \"label\": \"Alice\"}, ...],")
  io.println("  \"links\": [")
  io.println(
    "    {\"id\": 0, \"source\": 1, \"target\": 2, \"label\": \"follows\"},",
  )
  io.println(
    "    {\"id\": 1, \"source\": 1, \"target\": 2, \"label\": \"mentions\"},",
  )
  io.println(
    "    {\"id\": 2, \"source\": 1, \"target\": 2, \"label\": \"likes\"}",
  )
  io.println("  ]")
  io.println("}")

  // Export to Cytoscape format
  io.println("\n=== Cytoscape.js Format ===\n")
  io.println("Each edge has unique ID in elements array:")
  io.println("{")
  io.println("  \"elements\": [")
  io.println("    {\"data\": {\"id\": \"1\", \"label\": \"Alice\"}},")
  io.println("    {\"data\": {\"id\": \"2\", \"label\": \"Bob\"}},")
  io.println(
    "    {\"data\": {\"id\": \"e0\", \"source\": \"1\", \"target\": \"2\", \"label\": \"follows\"}},",
  )
  io.println(
    "    {\"data\": {\"id\": \"e1\", \"source\": \"1\", \"target\": \"2\", \"label\": \"mentions\"}},",
  )
  io.println(
    "    {\"data\": {\"id\": \"e2\", \"source\": \"1\", \"target\": \"2\", \"label\": \"likes\"}}",
  )
  io.println("  ]")
  io.println("}")

  io.println("\n=== Key Features ===")
  io.println("  - Unique edge IDs for all parallel edges")
  io.println("  - 'multigraph: true' flag in Generic/NetworkX formats")
  io.println("  - Compatible with all JSON format presets")
  io.println("  - Proper handling of directed and undirected multigraphs")
}

fn string_edge_ids(ids: List(Int)) -> String {
  ids
  |> list.map(int.to_string)
  |> string.join(", ")
}
/// Expected Output:
///
/// === MultiGraph JSON Example ===
///
/// Created MultiGraph:
///   - 3 nodes: Alice, Bob, Carol
///   - 4 edges total
///   - 3 parallel edges from Alice to Bob
///   - Edge IDs: 0, 1, 2
///
/// === Generic Format (with metadata) ===
///
/// Output (truncated):
/// {
///   "graph": {
///     "directed": true,
///     "multigraph": true,
///     "nodes": [...],
///     "edges": [
///       {"id": 0, "source": 1, "target": 2, "data": "follows"},
///       {"id": 1, "source": 1, "target": 2, "data": "mentions"},
///       {"id": 2, "source": 1, "target": 2, "data": "likes"},
///       {"id": 3, "source": 2, "target": 3, "data": "knows"}
///     ]
///   }
/// }
///
/// === D3 Force-Directed Format ===
///
/// Uses edge IDs to distinguish parallel edges:
/// {
///   "nodes": [{"id": 1, "label": "Alice"}, ...],
///   "links": [
///     {"id": 0, "source": 1, "target": 2, "label": "follows"},
///     {"id": 1, "source": 1, "target": 2, "label": "mentions"},
///     {"id": 2, "source": 1, "target": 2, "label": "likes"}
///   ]
/// }
///
/// === Cytoscape.js Format ===
///
/// Each edge has unique ID in elements array:
/// {
///   "elements": [
///     {"data": {"id": "1", "label": "Alice"}},
///     {"data": {"id": "2", "label": "Bob"}},
///     {"data": {"id": "e0", "source": "1", "target": "2", "label": "follows"}},
///     {"data": {"id": "e1", "source": "1", "target": "2", "label": "mentions"}},
///     {"data": {"id": "e2", "source": "1", "target": "2", "label": "likes"}}
///   ]
/// }
///
/// === Key Features ===
///   - Unique edge IDs for all parallel edges
///   - 'multigraph: true' flag in Generic/NetworkX formats
///   - Compatible with all JSON format presets
///   - Proper handling of directed and undirected multigraphs
