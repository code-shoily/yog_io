import gleam/io
import yog/model
import yog_io/leda

/// Example demonstrating LEDA format export
///
/// LEDA is a format from the LEDA graph algorithms library.
/// Structure:
/// - Header: LEDA.GRAPH
/// - Node type: string
/// - Edge type: string
/// - Direction: -1 (directed) or -2 (undirected)
/// - Node count
/// - Node list: |{label}|
/// - Edge count
/// - Edge list: source target rev_edge |{data}|
pub fn main() {
  io.println("=== LEDA Format Example ===\n")

  // Create a directed graph
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
    |> model.add_node(3, "Carol")

  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "follows")
  let assert Ok(graph) = model.add_edge(graph, from: 2, to: 3, with: "knows")

  // Export to LEDA
  let leda_string = leda.serialize(graph)

  io.println("Directed Graph Output:")
  io.println(leda_string)
  io.println("\nFormat:")
  io.println("  Line 1: LEDA.GRAPH header")
  io.println("  Line 2-3: Node and edge types (string)")
  io.println("  Line 4: Direction (-1 = directed, -2 = undirected)")
  io.println("  Line 5: Node count (3)")
  io.println("  Lines 6-8: Nodes in |{label}| format")
  io.println("  Line 9: Edge count (2)")
  io.println("  Lines 10-11: Edges as 'src tgt rev |{label}|'")

  // Example with undirected graph
  io.println("\n=== LEDA Undirected Graph ===\n")

  let graph2 =
    model.new(model.Undirected)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")

  let assert Ok(graph2) =
    model.add_edge(graph2, from: 1, to: 2, with: "connection")

  let leda_string2 = leda.serialize(graph2)
  io.println("Output:")
  io.println(leda_string2)
  io.println("\nNote: Direction is -2 for undirected graphs")
}
/// Expected Output:
///
/// === LEDA Format Example ===
///
/// Directed Graph Output:
/// LEDA.GRAPH
/// string
/// string
/// -1
/// 3
/// |{Alice}|
/// |{Bob}|
/// |{Carol}|
/// 2
/// 1 2 0 |{follows}|
/// 2 3 0 |{knows}|
///
/// Format:
///   Line 1: LEDA.GRAPH header
///   Line 2-3: Node and edge types (string)
///   Line 4: Direction (-1 = directed, -2 = undirected)
///   Line 5: Node count (3)
///   Lines 6-8: Nodes in |{label}| format
///   Line 9: Edge count (2)
///   Lines 10-11: Edges as 'src tgt rev |{label}|'
///
/// === LEDA Undirected Graph ===
///
/// Output:
/// LEDA.GRAPH
/// string
/// string
/// -2
/// 2
/// |{A}|
/// |{B}|
/// 1
/// 1 2 0 |{connection}|
///
/// Note: Direction is -2 for undirected graphs
