//// Adjacency List format example.
////
//// Demonstrates reading and writing graphs in adjacency list format (.list).
//// This format is simple and human-readable, where each line represents
//// a node and its successors.
////
//// Example format:
//// ```
//// 1: 2 3
//// 2: 3
//// 3:
//// ```

import gleam/int
import gleam/io
import yog/model.{Directed, Undirected}
import yog_io/list as list_io

pub fn main() {
  io.println("=== Adjacency List Format Example ===\n")

  // Create a directed graph
  let graph =
    model.new(Directed)
    |> model.add_node(1, Nil)
    |> model.add_node(2, Nil)
    |> model.add_node(3, Nil)
    |> model.add_node(4, Nil)

  let assert Ok(graph) =
    model.add_edges(graph, [
      #(1, 2, 1.0),
      #(1, 3, 1.0),
      #(2, 3, 1.0),
      #(3, 4, 1.0),
    ])

  // Serialize to adjacency list string
  let list_string = list_io.serialize(graph, list_io.default_options())
  io.println("1. Directed graph as adjacency list:")
  io.println(list_string)
  io.println("")

  // Write to file
  let path = "output/graph.list"
  let assert Ok(Nil) = list_io.write(path, graph)
  io.println("✓ Saved to " <> path)
  io.println("")

  // Read back from file
  let assert Ok(loaded) = list_io.read(path, Directed)
  io.println("2. Loaded graph info:")
  io.println("   Nodes: " <> int.to_string(model.node_count(loaded)))
  io.println("   Edges: " <> int.to_string(model.edge_count(loaded)))
  io.println("")

  // Demonstrate weighted format
  io.println("3. Weighted adjacency list format:")
  let weighted_string =
    list_io.serialize(
      graph,
      list_io.ListOptions(weighted: True, delimiter: ":"),
    )
  io.println(weighted_string)
  io.println("(Format: node: neighbor,weight neighbor,weight)")
  io.println("")

  // Demonstrate undirected graph
  let undirected_graph =
    model.new(Undirected)
    |> model.add_node(1, Nil)
    |> model.add_node(2, Nil)
    |> model.add_node(3, Nil)

  let assert Ok(undirected_graph) =
    model.add_edge(undirected_graph, from: 1, to: 2, with: 1.0)
  let assert Ok(undirected_graph) =
    model.add_edge(undirected_graph, from: 2, to: 3, with: 1.0)

  let undirected_string =
    list_io.serialize(undirected_graph, list_io.default_options())
  io.println("4. Undirected graph (edges appear in both directions):")
  io.println(undirected_string)

  io.println("\n=== Example Complete ===")
}
