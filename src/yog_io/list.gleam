//// Adjacency List format support.
////
//// This module provides functions to serialize and deserialize graphs in
//// adjacency list format (`.list`). This format is simple and human-readable,
//// where each line represents a node and its successors.
////
//// ## Format Overview
////
//// Each line starts with a node ID, followed by a delimiter (default: `:`),
//// and then a space-separated list of successor node IDs.
////
//// For weighted graphs, successors are represented as `id,weight`.
////
//// ## Example (Unweighted)
////
//// ```
//// 1: 2 3
//// 2: 3
//// 3:
//// ```
////
//// ## Example (Weighted)
////
//// ```
//// 1: 2,0.5 3,1.2
//// 2: 3,0.8
//// 3:
//// ```
////
//// ## Usage
////
//// ```gleam
//// import yog/model.{Directed}
//// import yog_io/list as list_io
////
//// pub fn main() {
////   let assert Ok(graph) = list_io.read("graph.list", Directed)
//// }
//// ```

import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import simplifile
import yog/model.{type Graph, type GraphType, Directed, Undirected}

/// Errors that can occur during Adjacency List operations
pub type ListError {
  /// File not found or couldn't be read
  ReadError(path: String, error: String)
  /// File couldn't be written
  WriteError(path: String, error: String)
  /// Invalid line format
  ParseError(line: Int, content: String)
}

/// Options for Adjacency List import/export
pub type ListOptions {
  ListOptions(
    /// Whether neighbors include weights (e.g., "neighbor,weight")
    weighted: Bool,
    /// Delimiter between node and neighbors (default: ":")
    delimiter: String,
  )
}

/// Returns default options for unweighted adjacency lists
pub fn default_options() -> ListOptions {
  ListOptions(weighted: False, delimiter: ":")
}

/// Reads a graph from an adjacency list file.
pub fn read(
  path: String,
  graph_type: GraphType,
) -> Result(Graph(Nil, Float), ListError) {
  read_with(path, graph_type, default_options())
}

/// Reads a graph from an adjacency list file with custom options.
pub fn read_with(
  path: String,
  graph_type: GraphType,
  options: ListOptions,
) -> Result(Graph(Nil, Float), ListError) {
  simplifile.read(path)
  |> result.map_error(fn(err) { ReadError(path, string.inspect(err)) })
  |> result.try(fn(content) { from_string(content, graph_type, options) })
}

/// Parses an adjacency list from a string into a graph.
pub fn from_string(
  content: String,
  graph_type: GraphType,
  options: ListOptions,
) -> Result(Graph(Nil, Float), ListError) {
  let lines = string.split(content, "\n")

  let initial_graph = model.new(graph_type)

  list.index_fold(lines, Ok(initial_graph), fn(res_graph, line, idx) {
    use graph <- result.try(res_graph)
    let line = string.trim(line)
    let line_no = idx + 1

    case line == "" || string.starts_with(line, "#") {
      True -> Ok(graph)
      False -> {
        case string.split_once(line, options.delimiter) {
          Ok(#(node_id_str, neighbors_str)) -> {
            let node_id = parse_id(node_id_str)
            let graph = model.add_node(graph, node_id, Nil)

            let neighbor_parts =
              string.split(string.trim(neighbors_str), " ")
              |> list.filter(fn(s) { s != "" })

            list.try_fold(neighbor_parts, graph, fn(g, part) {
              let #(target_id, weight) = parse_neighbor(part, options.weighted)
              let g = case dict.has_key(g.nodes, target_id) {
                True -> g
                False -> model.add_node(g, target_id, Nil)
              }
              model.add_edge(g, from: node_id, to: target_id, with: weight)
              |> result.replace_error(ParseError(line_no, line))
            })
          }
          Error(Nil) -> {
            let node_id = parse_id(line)
            Ok(model.add_node(graph, node_id, Nil))
          }
        }
      }
    }
  })
}

fn parse_id(str: String) -> Int {
  case int.parse(string.trim(str)) {
    Ok(i) -> i
    Error(Nil) -> 0
  }
}

fn parse_neighbor(str: String, weighted: Bool) -> #(Int, Float) {
  case weighted {
    True -> {
      case string.split_once(str, ",") {
        Ok(#(id_str, weight_str)) -> {
          #(parse_id(id_str), parse_float(weight_str))
        }
        Error(Nil) -> #(parse_id(str), 1.0)
      }
    }
    False -> #(parse_id(str), 1.0)
  }
}

fn parse_float(str: String) -> Float {
  let trimmed = string.trim(str)
  case float.parse(trimmed) {
    Ok(f) -> f
    Error(Nil) -> {
      case int.parse(trimmed) {
        Ok(i) -> int.to_float(i)
        Error(Nil) -> 1.0
      }
    }
  }
}

/// Writes a graph to an adjacency list file.
pub fn write(path: String, graph: Graph(n, Float)) -> Result(Nil, ListError) {
  write_with(path, graph, default_options())
}

/// Writes a graph to an adjacency list file with custom options.
pub fn write_with(
  path: String,
  graph: Graph(n, Float),
  options: ListOptions,
) -> Result(Nil, ListError) {
  let content = serialize(graph, options)
  simplifile.write(path, content)
  |> result.map_error(fn(err) { WriteError(path, string.inspect(err)) })
}

/// Converts a graph to an adjacency list string.
pub fn serialize(graph: Graph(n, Float), options: ListOptions) -> String {
  let nodes = dict.keys(graph.nodes) |> list.sort(by: int.compare)

  list.map(nodes, fn(node_id) {
    let neighbors =
      model.successors(graph, node_id)
      |> list.sort(by: fn(a, b) { int.compare(a.0, b.0) })

    let neighbor_strs =
      list.map(neighbors, fn(neighbor) {
        let #(target_id, weight) = neighbor
        case options.weighted {
          True -> int.to_string(target_id) <> "," <> float.to_string(weight)
          False -> int.to_string(target_id)
        }
      })

    let neighbor_str = case neighbor_strs {
      [] -> ""
      _ -> " " <> string.join(neighbor_strs, " ")
    }

    int.to_string(node_id) <> options.delimiter <> neighbor_str
  })
  |> string.join("\n")
}
