//// Adjacency Matrix format example.
////
//// Demonstrates converting between graphs and adjacency matrices.
//// Adjacency matrices are dense representations where matrix[i][j]
//// represents the edge weight from node i to node j.
////
//// Example format:
//// ```
//// 0.0 1.0 0.5
//// 1.0 0.0 0.0
//// 0.0 0.0 0.0
//// ```

import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import yog/model.{Directed, Undirected}
import yog_io/matrix as matrix_io

pub fn main() {
  io.println("=== Adjacency Matrix Format Example ===\n")

  // Create a weighted directed graph
  let graph =
    model.new(Directed)
    |> model.add_node(0, Nil)
    |> model.add_node(1, Nil)
    |> model.add_node(2, Nil)

  let assert Ok(graph) = model.add_edge(graph, from: 0, to: 1, with: 5.0)
  let assert Ok(graph) = model.add_edge(graph, from: 0, to: 2, with: 3.0)
  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: 2.0)

  // Convert to adjacency matrix
  let #(nodes, matrix) = matrix_io.to_matrix(graph)
  io.println("1. Graph as adjacency matrix:")
  io.println("   Nodes: " <> format_int_list(nodes))
  io.println("")
  print_matrix(matrix)
  io.println("")

  // Serialize to string
  let matrix_string = matrix_io.serialize(matrix)
  io.println("2. Matrix as string:")
  io.println(matrix_string)

  // Write to file
  let path = "output/graph.mat"
  let assert Ok(Nil) = matrix_io.write(path, graph)
  io.println("✓ Saved to " <> path)
  io.println("")

  // Read back from file
  let assert Ok(loaded) = matrix_io.read(path, Directed)
  io.println("3. Loaded graph from matrix:")
  io.println("   Nodes: " <> int.to_string(model.node_count(loaded)))
  io.println("   Edges: " <> int.to_string(model.edge_count(loaded)))
  io.println("")

  // Demonstrate undirected matrix (symmetric)
  let undirected_graph =
    model.new(Undirected)
    |> model.add_node(0, Nil)
    |> model.add_node(1, Nil)
    |> model.add_node(2, Nil)

  let assert Ok(undirected_graph) =
    model.add_edge(undirected_graph, from: 0, to: 1, with: 4.0)
  let assert Ok(undirected_graph) =
    model.add_edge(undirected_graph, from: 1, to: 2, with: 6.0)

  let #(_, undirected_matrix) = matrix_io.to_matrix(undirected_graph)
  io.println("4. Undirected graph matrix (symmetric):")
  print_matrix(undirected_matrix)
  io.println("   Note: matrix[i][j] == matrix[j][i] for undirected graphs")
  io.println("")

  // Create graph from matrix
  let matrix_data = [
    [0.0, 1.0, 0.0],
    [0.0, 0.0, 1.0],
    [1.0, 0.0, 0.0],
  ]
  let assert Ok(from_matrix) = matrix_io.from_matrix(Directed, matrix_data)
  io.println("5. Graph created from matrix:")
  io.println("   Nodes: " <> int.to_string(model.node_count(from_matrix)))
  io.println("   Edges: " <> int.to_string(model.edge_count(from_matrix)))

  io.println("\n=== Example Complete ===")
}

fn print_matrix(matrix: List(List(Float))) {
  list.each(matrix, fn(row) {
    let row_str =
      list.map(row, fn(val) {
        case val {
          v if v == 0.0 -> "0.0  "
          v -> format_float(v) <> " "
        }
      })
      |> list.fold("", fn(acc, s) { acc <> s })
    io.println("   " <> row_str)
  })
}

fn format_int_list(nodes: List(Int)) -> String {
  nodes
  |> list.map(int.to_string)
  |> list.fold("", fn(acc, s) { acc <> s <> " " })
}

fn format_float(f: Float) -> String {
  let s = float.to_string(f)
  case string.length(s) {
    n if n < 4 -> s <> string.repeat(" ", 4 - n)
    _ -> s
  }
}
