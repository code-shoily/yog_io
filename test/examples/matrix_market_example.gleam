//// Matrix Market format example.
////
//// Demonstrates reading and writing graphs in Matrix Market coordinate format.
//// This is a popular sparse matrix format used in scientific computing.
////
//// Format structure:
//// ```
//// %%MatrixMarket matrix coordinate real general
//// % Comments start with %
//// rows cols entries
//// row col value
//// ...
//// ```

import gleam/int
import gleam/io
import yog/model.{Directed, Undirected}
import yog_io/matrix_market as mtx_io

pub fn main() {
  io.println("=== Matrix Market Format Example ===\n")

  // Create a sparse directed graph
  let graph =
    model.new(Directed)
    |> model.add_node(1, Nil)
    |> model.add_node(2, Nil)
    |> model.add_node(3, Nil)
    |> model.add_node(4, Nil)
    |> model.add_node(5, Nil)

  // Add a few edges (sparse: only 3 edges out of 25 possible)
  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: 1.0)
  let assert Ok(graph) = model.add_edge(graph, from: 2, to: 3, with: 1.0)
  let assert Ok(graph) = model.add_edge(graph, from: 3, to: 4, with: 1.0)

  // Serialize to Matrix Market format
  let mtx_string = mtx_io.serialize(graph)
  io.println("1. Sparse graph as Matrix Market format:")
  io.println(mtx_string)

  // Write to file
  let path = "output/graph.mtx"
  let assert Ok(Nil) = mtx_io.write(path, graph)
  io.println("✓ Saved to " <> path)
  io.println("")

  // Read back from file
  let assert Ok(result) = mtx_io.read(path)
  let loaded = result.graph
  io.println("2. Loaded graph from Matrix Market file:")
  io.println("   Nodes: " <> int.to_string(model.node_count(loaded)))
  io.println("   Edges: " <> int.to_string(model.edge_count(loaded)))
  io.println("")

  // Demonstrate symmetric (undirected) format
  let undirected_graph =
    model.new(Undirected)
    |> model.add_node(1, Nil)
    |> model.add_node(2, Nil)
    |> model.add_node(3, Nil)

  let assert Ok(undirected_graph) =
    model.add_edge(undirected_graph, from: 1, to: 2, with: 2.5)
  let assert Ok(undirected_graph) =
    model.add_edge(undirected_graph, from: 2, to: 3, with: 3.5)

  let symmetric_string = mtx_io.serialize(undirected_graph)
  io.println("3. Undirected graph (symmetric format):")
  io.println(symmetric_string)
  io.println(
    "   Note: Uses 'symmetric' instead of 'general' for undirected graphs",
  )
  io.println("")

  // Parse from string
  let mtx_input =
    "%%MatrixMarket matrix coordinate real general\n"
    <> "% This is a comment\n"
    <> "3 3 2\n"
    <> "1 2 1.5\n"
    <> "2 3 2.5\n"

  let assert Ok(parsed_result) = mtx_io.from_string(mtx_input)
  let parsed = parsed_result.graph
  io.println("4. Parsed graph from string:")
  io.println("   Nodes: " <> int.to_string(model.node_count(parsed)))
  io.println("   Edges: " <> int.to_string(model.edge_count(parsed)))

  io.println("\n=== Example Complete ===")
}
