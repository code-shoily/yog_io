//// Adjacency Matrix format support.
////
//// This module provides functions to convert between graphs and adjacency
//// matrices. Adjacency matrices are dense representations where `matrix[i][j]`
//// represents the edge from node `i` to node `j`.
////
//// ## Format Overview
////
//// The file representation is a space-separated text file where each row
//// corresponds to a row in the matrix.
////
//// ## Example
////
//// ```
//// 0.0 1.0 0.5
//// 1.0 0.0 0.0
//// 0.0 0.0 0.0
//// ```
////
//// ## Usage
////
//// ```gleam
//// import yog/model.{Undirected}
//// import yog_io/matrix as matrix_io
////
//// pub fn main() {
////   let assert Ok(graph) = matrix_io.read("graph.mat", Undirected)
//// }
//// ```

import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import simplifile
import yog/model.{type Graph, type GraphType, Directed, Undirected}

/// Errors that can occur during Matrix operations
pub type MatrixError {
  /// Matrix is not square (n x n)
  NotSquare(rows: Int, cols: Int)
  /// File not found or couldn't be read
  ReadError(path: String, error: String)
  /// File couldn't be written
  WriteError(path: String, error: String)
}

/// Creates a graph from an adjacency matrix.
///
/// An adjacency matrix is a square matrix where `matrix[i][j]` represents
/// the weight of the edge from node `i` to node `j`. A value of `0.0`
/// indicates no edge.
pub fn from_matrix(
  graph_type: GraphType,
  matrix: List(List(Float)),
) -> Result(Graph(Nil, Float), MatrixError) {
  let n = list.length(matrix)
  case n == 0 {
    True -> Ok(model.new(graph_type))
    False -> {
      let is_square = list.all(matrix, fn(row) { list.length(row) == n })
      case is_square {
        False -> Error(NotSquare(n, 0))
        True -> {
          let graph = model.new(graph_type)
          let graph =
            int.range(from: 0, to: n, with: graph, run: fn(g, i) {
              model.add_node(g, i, Nil)
            })

          let edges = case graph_type {
            Undirected -> {
              list.index_fold(matrix, [], fn(acc, row, i) {
                list.index_fold(row, acc, fn(acc2, weight, j) {
                  case j > i && weight != 0.0 {
                    True -> [#(i, j, weight), ..acc2]
                    False -> acc2
                  }
                })
              })
            }
            Directed -> {
              list.index_fold(matrix, [], fn(acc, row, i) {
                list.index_fold(row, acc, fn(acc2, weight, j) {
                  case i != j && weight != 0.0 {
                    True -> [#(i, j, weight), ..acc2]
                    False -> acc2
                  }
                })
              })
            }
          }

          list.try_fold(edges, graph, fn(g, e) {
            let #(from, to, weight) = e
            model.add_edge(g, from: from, to: to, with: weight)
            |> result.replace_error(NotSquare(n, n))
          })
        }
      }
    }
  }
}

/// Exports a graph to an adjacency matrix representation.
///
/// Returns a tuple `#(nodes, matrix)` where:
/// - `nodes` is a list of node IDs in the order they appear in the matrix
/// - `matrix` is the adjacency matrix (list of lists of weights)
pub fn to_matrix(graph: Graph(n, Float)) -> #(List(Int), List(List(Float))) {
  let nodes = dict.keys(graph.nodes) |> list.sort(by: int.compare)

  let matrix =
    list.map(nodes, fn(i) {
      list.map(nodes, fn(j) {
        case i == j {
          True -> 0.0
          False -> {
            let weight =
              dict.get(graph.out_edges, i)
              |> result.try(dict.get(_, j))
              |> result.unwrap(0.0)
            weight
          }
        }
      })
    })

  #(nodes, matrix)
}

/// Reads an adjacency matrix from a file.
pub fn read(
  path: String,
  graph_type: GraphType,
) -> Result(Graph(Nil, Float), MatrixError) {
  simplifile.read(path)
  |> result.map_error(fn(err) { ReadError(path, string.inspect(err)) })
  |> result.try(from_string)
  |> result.try(from_matrix(graph_type, _))
}

/// Writes an adjacency matrix to a file.
pub fn write(path: String, graph: Graph(n, Float)) -> Result(Nil, MatrixError) {
  let #(_, matrix) = to_matrix(graph)
  let content = serialize(matrix)
  simplifile.write(path, content)
  |> result.map_error(fn(err) { WriteError(path, string.inspect(err)) })
}

/// Parses an adjacency matrix from a string.
pub fn from_string(content: String) -> Result(List(List(Float)), MatrixError) {
  let lines =
    string.split(content, "\n")
    |> list.map(string.trim)
    |> list.filter(fn(l) { l != "" })

  list.try_map(lines, fn(line) {
    let parts =
      string.split(line, " ")
      |> list.filter(fn(p) { p != "" })

    list.try_map(parts, fn(p) {
      float.parse(p)
      |> result.lazy_or(fn() { int.parse(p) |> result.map(int.to_float) })
    })
    |> result.replace_error(ReadError("", "Invalid record in matrix: " <> line))
  })
}

/// Converts a matrix to a space-separated string.
pub fn serialize(matrix: List(List(Float))) -> String {
  list.map(matrix, fn(row) {
    list.map(row, float.to_string)
    |> string.join(" ")
  })
  |> string.join("\n")
}
