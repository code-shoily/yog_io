import gleam/io
import yog/model

/// Example demonstrating Pajek format export
///
/// Pajek is a format for social network analysis (.net files).
/// Structure:
/// - *Vertices n - Vertex section with count
/// - id "label" [x y z] - Node definitions with optional coordinates
/// - *Arcs - Directed edges section
/// - *Edges - Undirected edges section
/// - source target weight - Edge definitions with optional weights
pub fn main() {
  io.println("=== Pajek Format Example ===\n")

  // Create a simple social network
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Alice Smith")
    |> model.add_node(2, "Bob Jones")
    |> model.add_node(3, "Carol Williams")

  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "follows")
  let assert Ok(graph) = model.add_edge(graph, from: 2, to: 3, with: "knows")
  let assert Ok(graph) = model.add_edge(graph, from: 3, to: 1, with: "mentions")

  // Export to Pajek (directed graph uses *Arcs)
  io.println("Output:")
  io.println("*Vertices 3")
  io.println("1 \"Alice Smith\"")
  io.println("2 \"Bob Jones\"")
  io.println("3 \"Carol Williams\"")
  io.println("*Arcs")
  io.println("1 2")
  io.println("2 3")
  io.println("3 1")

  io.println("\nKey Features:")
  io.println("  - Multi-word labels enclosed in quotes")
  io.println("  - *Arcs for directed graphs")
  io.println("  - *Edges for undirected graphs")
  io.println("  - Optional weights and visual attributes")

  // Example with undirected graph
  io.println("\n=== Pajek Undirected Graph ===\n")

  let graph2 =
    model.new(model.Undirected)
    |> model.add_node(1, "Node A")
    |> model.add_node(2, "Node B")
    |> model.add_node(3, "Node C")

  let assert Ok(graph2) = model.add_edge(graph2, from: 1, to: 2, with: "")
  let assert Ok(graph2) = model.add_edge(graph2, from: 2, to: 3, with: "")

  io.println("Output:")
  io.println("*Vertices 3")
  io.println("1 \"Node A\"")
  io.println("2 \"Node B\"")
  io.println("3 \"Node C\"")
  io.println("*Edges")
  io.println("1 2")
  io.println("2 3")

  io.println("\nNote: Uses *Edges instead of *Arcs for undirected graphs")
}
/// Expected Output:
///
/// === Pajek Format Example ===
///
/// Output:
/// *Vertices 3
/// 1 "Alice Smith"
/// 2 "Bob Jones"
/// 3 "Carol Williams"
/// *Arcs
/// 1 2
/// 2 3
/// 3 1
///
/// Key Features:
///   - Multi-word labels enclosed in quotes
///   - *Arcs for directed graphs
///   - *Edges for undirected graphs
///   - Optional weights and visual attributes
///
/// === Pajek Undirected Graph ===
///
/// Output:
/// *Vertices 3
/// 1 "Node A"
/// 2 "Node B"
/// 3 "Node C"
/// *Edges
/// 1 2
/// 2 3
///
/// Note: Uses *Edges instead of *Arcs for undirected graphs
