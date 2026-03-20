//// GDF (GUESS Graph Format) serialization support.
////
//// Provides functions to serialize and deserialize graphs in GDF format,
//// a simple text-based format used by Gephi and other graph visualization tools.
//// GDF uses a column-based format similar to CSV with separate sections for nodes and edges.
////
//// ## Format Overview
////
//// GDF files consist of two sections:
//// - **nodedef>** - Defines node columns and data
//// - **edgedef>** - Defines edge columns and data
////
//// ## Example
////
//// ```gleam
//// import yog/model.{Directed}
//// import yog_io/gdf
////
//// // Create a simple graph
//// let graph =
////   model.new(Directed)
////   |> model.add_node(1, "Alice")
////   |> model.add_node(2, "Bob")
////
//// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "5")
////
//// // Serialize to GDF
//// let gdf_string = gdf.serialize(graph)
////
//// // Write to file
//// let assert Ok(Nil) = gdf.write("graph.gdf", graph)
//// ```
////
//// ## Output Format
////
//// ```
//// nodedef>name VARCHAR,label VARCHAR
//// 1,Alice
//// 2,Bob
//// edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,weight VARCHAR
//// 1,2,true,5
//// ```
////
//// ## References
////
//// - [GDF Format Specification](https://gephi.org/users/supported-graph-formats/gdf-format/)
//// - [GUESS Visualization Tool](https://graphexploration.cond.org/)

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/string_tree as sb
import simplifile
import yog/model.{type Graph, type NodeId, Directed, Undirected}

// =============================================================================
// TYPES
// =============================================================================

/// Options for GDF serialization.
pub type GdfOptions {
  GdfOptions(
    /// Column separator (default: comma)
    separator: String,
    /// Include type annotations in header (default: True)
    include_types: Bool,
    /// Include the 'directed' column for edges (default: auto-detect from graph type)
    include_directed: Option(Bool),
  )
}

/// Default GDF serialization options.
pub fn default_options() -> GdfOptions {
  GdfOptions(separator: ",", include_types: True, include_directed: None)
}

/// Attributes for a node as a dictionary of string key-value pairs.
pub type NodeAttributes =
  Dict(String, String)

/// Attributes for an edge as a dictionary of string key-value pairs.
pub type EdgeAttributes =
  Dict(String, String)

/// A graph with string-based attributes for nodes and edges.
pub type AttributedGraph =
  Graph(NodeAttributes, EdgeAttributes)

// =============================================================================
// SERIALIZATION
// =============================================================================

/// Serializes a graph to GDF format with custom attribute mappers and options.
///
/// This function allows you to control how node and edge data are converted
/// to GDF attributes, and customize the output format.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import gleam/dict
/// import yog/model.{Directed}
/// import yog_io/gdf
///
/// type Person {
///   Person(name: String, age: Int)
/// }
///
/// type Connection {
///   Connection(weight: Int, relation: String)
/// }
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, Person("Alice", 30))
///   |> model.add_node(2, Person("Bob", 25))
///
/// let node_attrs = fn(p: Person) {
///   dict.from_list([#("label", p.name), #("age", int.to_string(p.age))])
/// }
///
/// let edge_attrs = fn(c: Connection) {
///   dict.from_list([#("weight", int.to_string(c.weight)), #("type", c.relation)])
/// }
///
/// let gdf = gdf.serialize_with(node_attrs, edge_attrs, gdf.default_options(), graph)
/// ```
pub fn serialize_with(
  node_attr: fn(n) -> NodeAttributes,
  edge_attr: fn(e) -> EdgeAttributes,
  options: GdfOptions,
  graph: Graph(n, e),
) -> String {
  let nodes_list = dict.to_list(graph.nodes)

  // Determine node attribute columns from first node (if any)
  let node_attr_columns = case list.first(nodes_list) {
    Ok(#(_, first_node_data)) -> dict.keys(node_attr(first_node_data))
    Error(_) -> []
  }

  // Collect edges
  let edges_list =
    dict.to_list(graph.out_edges)
    |> list.flat_map(fn(entry) {
      let #(src, targets) = entry
      dict.to_list(targets)
      |> list.map(fn(target_entry) {
        let #(dst, weight) = target_entry
        #(src, dst, weight)
      })
    })

  // Determine edge attribute columns from first edge (if any)
  let edge_attr_columns = case list.first(edges_list) {
    Ok(#(_, _, first_edge_data)) -> dict.keys(edge_attr(first_edge_data))
    Error(_) -> []
  }

  // Determine if we should include directed column (default is true for all graphs)
  let include_directed_col = case options.include_directed {
    Some(flag) -> flag
    None -> True
  }

  let builder = sb.new()

  // Build node header
  let builder = sb.append(builder, "nodedef>name")
  let builder = case options.include_types {
    True -> sb.append(builder, " VARCHAR")
    False -> builder
  }

  let builder =
    list.fold(node_attr_columns, builder, fn(b, col) {
      sb.append(b, options.separator)
      |> sb.append(col)
      |> fn(b2) {
        case options.include_types {
          True -> sb.append(b2, " VARCHAR")
          False -> b2
        }
      }
    })

  let builder = sb.append(builder, "\n")

  // Build node rows
  let builder =
    list.fold(nodes_list, builder, fn(b, entry) {
      let #(id, data) = entry
      let attrs = node_attr(data)

      let b = sb.append(b, escape_value(options.separator, int.to_string(id)))

      let b =
        list.fold(node_attr_columns, b, fn(b2, col) {
          sb.append(b2, options.separator)
          |> sb.append(escape_value(
            options.separator,
            dict.get(attrs, col) |> result.unwrap(""),
          ))
        })

      sb.append(b, "\n")
    })

  // Build edge header
  let builder = sb.append(builder, "edgedef>node1")
  let builder = case options.include_types {
    True -> sb.append(builder, " VARCHAR")
    False -> builder
  }

  let builder = sb.append(builder, options.separator) |> sb.append("node2")
  let builder = case options.include_types {
    True -> sb.append(builder, " VARCHAR")
    False -> builder
  }

  // Add directed column if needed
  let builder = case include_directed_col {
    True -> {
      let b = sb.append(builder, options.separator) |> sb.append("directed")
      case options.include_types {
        True -> sb.append(b, " BOOLEAN")
        False -> b
      }
    }
    False -> builder
  }

  // Add edge attribute columns
  let builder =
    list.fold(edge_attr_columns, builder, fn(b, col) {
      sb.append(b, options.separator)
      |> sb.append(col)
      |> fn(b2) {
        case options.include_types {
          True -> sb.append(b2, " VARCHAR")
          False -> b2
        }
      }
    })

  let builder = sb.append(builder, "\n")

  // For undirected graphs, we need to avoid duplicate edges
  let edges_to_output = case graph.kind {
    Directed -> edges_list
    Undirected ->
      list.filter(edges_list, fn(entry) {
        let #(src, dst, _) = entry
        src <= dst
      })
  }

  // Build edge rows
  let builder =
    list.fold(edges_to_output, builder, fn(b, entry) {
      let #(src, dst, data) = entry
      let attrs = edge_attr(data)

      let b =
        sb.append(b, escape_value(options.separator, int.to_string(src)))
        |> sb.append(options.separator)
        |> sb.append(escape_value(options.separator, int.to_string(dst)))

      // Add directed value if needed
      let b = case include_directed_col {
        True ->
          sb.append(b, options.separator)
          |> sb.append(case graph.kind {
            Directed -> "true"
            Undirected -> "false"
          })
        False -> b
      }

      // Add edge attributes
      let b =
        list.fold(edge_attr_columns, b, fn(b2, col) {
          sb.append(b2, options.separator)
          |> sb.append(escape_value(
            options.separator,
            dict.get(attrs, col) |> result.unwrap(""),
          ))
        })

      sb.append(b, "\n")
    })

  sb.to_string(builder)
}

/// Serializes a graph to GDF format where node and edge data are strings.
///
/// This is a simplified version of `serialize_with` for graphs where
/// node data and edge data are already strings. The string data is used
/// as the "label" attribute for both nodes and edges.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
/// import yog_io/gdf
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "friend")
///
/// let gdf = gdf.serialize(graph)
/// // nodedef>name VARCHAR,label VARCHAR
/// // 1,Alice
/// // 2,Bob
/// // edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR
/// // 1,2,true,friend
/// ```
pub fn serialize(graph: Graph(String, String)) -> String {
  serialize_with(
    fn(label) { dict.from_list([#("label", label)]) },
    fn(label) { dict.from_list([#("label", label)]) },
    default_options(),
    graph,
  )
}

/// Serializes a graph to GDF format with integer edge weights.
///
/// This is a convenience function for the common case of graphs with
/// integer weights. Node data is used as labels, and edge weights are
/// serialized to the "weight" column.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
/// import yog_io/gdf
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: 5)
///
/// let gdf = gdf.serialize_weighted(graph)
/// ```
pub fn serialize_weighted(graph: Graph(String, Int)) -> String {
  serialize_with(
    fn(label) { dict.from_list([#("label", label)]) },
    fn(weight) { dict.from_list([#("weight", int.to_string(weight))]) },
    default_options(),
    graph,
  )
}

/// Writes a graph to a GDF file.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
/// import yog_io/gdf
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Start")
///   |> model.add_node(2, "End")
///
/// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "connection")
///
/// let assert Ok(Nil) = gdf.write("mygraph.gdf", graph)
/// ```
pub fn write(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, simplifile.FileError) {
  let content = serialize(graph)
  simplifile.write(path, content)
}

/// Writes a graph to a GDF file with custom attribute mappers.
pub fn write_with(
  path: String,
  node_attr: fn(n) -> NodeAttributes,
  edge_attr: fn(e) -> EdgeAttributes,
  options: GdfOptions,
  graph: Graph(n, e),
) -> Result(Nil, simplifile.FileError) {
  let content = serialize_with(node_attr, edge_attr, options, graph)
  simplifile.write(path, content)
}

// =============================================================================
// DESERIALIZATION
// =============================================================================

/// Deserializes a GDF string into a graph with custom data mappers.
///
/// This function allows you to control how GDF columns are converted
/// to your node and edge data types. Use `deserialize` for simple cases
/// where you want node/edge data as string dictionaries.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import gleam/dict
/// import yog_io/gdf
///
/// type Person {
///   Person(name: String, age: Int)
/// }
///
/// let node_folder = fn(attrs: dict.Dict(String, String)) {
///   let name = dict.get(attrs, "label") |> result.unwrap("")
///   let age = dict.get(attrs, "age") |> result.unwrap("0") |> int.parse |> result.unwrap(0)
///   Person(name, age)
/// }
///
/// let gdf = "..."
/// let assert Ok(graph) = gdf.deserialize_with(node_folder, fn(attrs) {
///   dict.get(attrs, "weight") |> result.unwrap("")
/// }, gdf)
/// ```
pub fn deserialize_with(
  node_folder: fn(NodeAttributes) -> n,
  edge_folder: fn(EdgeAttributes) -> e,
  gdf: String,
) -> Result(Graph(n, e), String) {
  let lines = string.split(gdf, "\n")

  // Find node and edge sections
  let node_def_idx = find_line_index(lines, "nodedef>")
  let edge_def_idx = find_line_index(lines, "edgedef>")

  case node_def_idx {
    Error(_) -> Error("Missing nodedef> section")
    Ok(node_idx) -> {
      let edge_idx = case edge_def_idx {
        Ok(idx) -> idx
        Error(_) -> list.length(lines)
      }

      // Parse node section
      let node_header_line = case list.drop(lines, node_idx) |> list.first() {
        Ok(line) -> line
        Error(_) -> "nodedef>name"
      }

      let node_columns = parse_header(node_header_line)
      let node_data_lines =
        lines
        |> list.drop(node_idx + 1)
        |> list.take(edge_idx - node_idx - 1)
        |> list.filter(fn(line) { !string.is_empty(string.trim(line)) })

      // Parse edge section (if exists)
      let #(edge_columns, edge_data_lines, is_directed) = case edge_def_idx {
        Ok(e_idx) -> {
          let edge_header_line = case list.drop(lines, e_idx) |> list.first() {
            Ok(line) -> line
            Error(_) -> "edgedef>node1,node2"
          }
          let e_columns = parse_header(edge_header_line)
          let e_data_lines =
            lines
            |> list.drop(e_idx + 1)
            |> list.filter(fn(line) { !string.is_empty(string.trim(line)) })

          // Check if directed column is present
          let has_directed = list.contains(e_columns, "directed")

          #(e_columns, e_data_lines, has_directed)
        }
        Error(_) -> #([], [], False)
      }

      // Determine graph type from edge header or data
      let graph_type = case edge_def_idx {
        Ok(e_idx) -> {
          let edge_header = case list.drop(lines, e_idx) |> list.first() {
            Ok(line) -> line
            Error(_) -> ""
          }
          case string.contains(edge_header, "directed") {
            True -> {
              // Check the first edge data line for directed value
              case list.first(edge_data_lines) {
                Ok(first_edge) -> {
                  let parts = parse_csv_line(first_edge)
                  let dir_idx = find_column_index(edge_columns, "directed")
                  let parts_length = list.length(parts)
                  case dir_idx {
                    Ok(idx) -> {
                      case idx < parts_length {
                        True -> {
                          case list.drop(parts, idx) |> list.first() {
                            Ok("true") -> Directed
                            Ok("True") -> Directed
                            Ok("TRUE") -> Directed
                            _ -> Undirected
                          }
                        }
                        False -> Undirected
                      }
                    }
                    _ -> Undirected
                  }
                }
                Error(_) -> Undirected
              }
            }
            False -> Undirected
          }
        }
        Error(_) -> Undirected
      }

      // Start building the graph
      let graph = model.new(graph_type)

      // Parse and add nodes
      let graph =
        list.fold(node_data_lines, graph, fn(g, line) {
          let values = parse_csv_line(line)
          case list.first(values) {
            Ok(id_str) -> {
              case int.parse(string.trim(id_str)) {
                Ok(id) -> {
                  // Build attribute dict from all columns (including first)
                  // The first column value is the ID, but we include it in attrs too
                  // because GDF convention puts node name/label as first column
                  let attrs =
                    list.zip(node_columns, values)
                    |> dict.from_list()

                  let node_data = node_folder(attrs)
                  model.add_node(g, id, node_data)
                }
                Error(_) -> g
              }
            }
            Error(_) -> g
          }
        })

      // Parse and add edges
      let graph =
        list.fold(edge_data_lines, graph, fn(g, line) {
          let values = parse_csv_line(line)

          // Get source and target (always first two columns)
          case list.first(values), list.drop(values, 1) |> list.first() {
            Ok(src_str), Ok(tgt_str) -> {
              case
                int.parse(string.trim(src_str)),
                int.parse(string.trim(tgt_str))
              {
                Ok(src), Ok(tgt) -> {
                  // Build attribute dict from remaining columns
                  let skip_count = case is_directed {
                    True -> 3
                    // node1, node2, directed
                    False -> 2
                    // node1, node2
                  }

                  let remaining_values = list.drop(values, skip_count)
                  let remaining_columns =
                    list.drop(edge_columns, skip_count)
                    |> list.filter(fn(col) { col != "directed" })

                  let attrs =
                    list.zip(remaining_columns, remaining_values)
                    |> dict.from_list()

                  let edge_data = edge_folder(attrs)

                  // Add edge (ensure nodes exist first)
                  let g_with_src = case dict.has_key(g.nodes, src) {
                    True -> g
                    False -> model.add_node(g, src, node_folder(dict.new()))
                  }

                  let g_with_both = case dict.has_key(g_with_src.nodes, tgt) {
                    True -> g_with_src
                    False ->
                      model.add_node(g_with_src, tgt, node_folder(dict.new()))
                  }

                  add_edge_unchecked(g_with_both, src, tgt, edge_data)
                }
                _, _ -> g
              }
            }
            _, _ -> g
          }
        })

      Ok(graph)
    }
  }
}

/// Deserializes a GDF string to a graph.
///
/// This is a simplified version of `deserialize_with` for graphs where
/// you want node data and edge data as string dictionaries containing all attributes.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import yog_io/gdf
///
/// let gdf_string = "..."
/// let assert Ok(graph) = gdf.deserialize(gdf_string)
///
/// // Access node data
/// let node1_data = dict.get(graph.nodes, 1)  // Dict(String, String)
/// let label = dict.get(node1_data, "label")
/// ```
pub fn deserialize(gdf: String) -> Result(AttributedGraph, String) {
  deserialize_with(fn(attrs) { attrs }, fn(attrs) { attrs }, gdf)
}

/// Reads a graph from a GDF file.
///
/// ## Example
///
/// ```gleam
/// import yog_io/gdf
///
/// let assert Ok(graph) = gdf.read("graph.gdf")
/// ```
pub fn read(path: String) -> Result(AttributedGraph, String) {
  case simplifile.read(path) {
    Ok(content) -> deserialize(content)
    Error(e) -> Error("Failed to read file: " <> simplifile.describe_error(e))
  }
}

/// Reads a graph from a GDF file with custom data mappers.
pub fn read_with(
  path: String,
  node_folder: fn(NodeAttributes) -> n,
  edge_folder: fn(EdgeAttributes) -> e,
) -> Result(Graph(n, e), String) {
  case simplifile.read(path) {
    Ok(content) -> deserialize_with(node_folder, edge_folder, content)
    Error(e) -> Error("Failed to read file: " <> simplifile.describe_error(e))
  }
}

// =============================================================================
// INTERNAL HELPERS
// =============================================================================

fn find_line_index(lines: List(String), prefix: String) -> Result(Int, Nil) {
  find_line_index_loop(lines, prefix, 0)
}

fn find_line_index_loop(
  lines: List(String),
  prefix: String,
  idx: Int,
) -> Result(Int, Nil) {
  case lines {
    [] -> Error(Nil)
    [first, ..rest] -> {
      let trimmed = string.trim(first)
      case string.starts_with(trimmed, prefix) {
        True -> Ok(idx)
        False -> find_line_index_loop(rest, prefix, idx + 1)
      }
    }
  }
}

fn parse_header(line: String) -> List(String) {
  // Remove prefix (nodedef> or edgedef>)
  let without_prefix = case string.split(line, ">") {
    [_, rest] -> rest
    _ -> line
  }

  // Split by separator and clean up
  without_prefix
  |> string.split(",")
  |> list.map(fn(part) {
    // Remove type annotations (e.g., "name VARCHAR" -> "name")
    case string.split(part, " ") {
      [first, ..] -> string.trim(first)
      _ -> string.trim(part)
    }
  })
  |> list.filter(fn(col) { !string.is_empty(col) })
}

fn parse_csv_line(line: String) -> List(String) {
  parse_csv_line_loop(string.to_graphemes(line), [], [], False)
}

fn parse_csv_line_loop(
  chars: List(String),
  current: List(String),
  fields: List(String),
  in_quotes: Bool,
) -> List(String) {
  case chars {
    [] -> {
      let field = string.concat(list.reverse(current)) |> string.trim()
      list.reverse([field, ..fields])
    }
    ["\"", ..rest] -> {
      case in_quotes {
        True -> {
          // Check for escaped quote ("")
          case rest {
            ["\"", ..rest2] -> {
              // Escaped quote - add single quote and continue
              parse_csv_line_loop(rest2, ["\"", ..current], fields, True)
            }
            _ -> {
              // End of quoted field
              let field = string.concat(list.reverse(current))
              parse_csv_line_loop(rest, [], [field, ..fields], False)
            }
          }
        }
        False -> {
          // Start of quoted field
          parse_csv_line_loop(rest, current, fields, True)
        }
      }
    }
    [",", ..rest] -> {
      case in_quotes {
        True -> {
          // Comma inside quotes - include it
          parse_csv_line_loop(rest, [",", ..current], fields, True)
        }
        False -> {
          // End of field
          let field = string.concat(list.reverse(current)) |> string.trim()
          parse_csv_line_loop(rest, [], [field, ..fields], False)
        }
      }
    }
    [c, ..rest] -> {
      parse_csv_line_loop(rest, [c, ..current], fields, in_quotes)
    }
  }
}

fn find_column_index(columns: List(String), name: String) -> Result(Int, Nil) {
  find_column_index_loop(columns, name, 0)
}

fn find_column_index_loop(
  columns: List(String),
  name: String,
  idx: Int,
) -> Result(Int, Nil) {
  case columns {
    [] -> Error(Nil)
    [first, ..rest] -> {
      case first == name {
        True -> Ok(idx)
        False -> find_column_index_loop(rest, name, idx + 1)
      }
    }
  }
}

fn escape_value(separator: String, value: String) -> String {
  // Escape if contains separator, newline, or quote
  case
    string.contains(value, separator)
    || string.contains(value, "\n")
    || string.contains(value, "\r")
    || string.contains(value, "\"")
  {
    True -> {
      "\"" <> string.replace(value, "\"", "\"\"") <> "\""
    }
    False -> value
  }
}

fn add_edge_unchecked(
  graph: model.Graph(n, e),
  src: NodeId,
  dst: NodeId,
  weight: e,
) -> model.Graph(n, e) {
  // Get current outgoing edges for src
  let out_update = case dict.get(graph.out_edges, src) {
    Ok(edges) -> dict.insert(edges, dst, weight)
    Error(_) -> dict.from_list([#(dst, weight)])
  }

  // Get current incoming edges for dst
  let in_update = case dict.get(graph.in_edges, dst) {
    Ok(edges) -> dict.insert(edges, src, weight)
    Error(_) -> dict.from_list([#(src, weight)])
  }

  let new_out = dict.insert(graph.out_edges, src, out_update)
  let new_in = dict.insert(graph.in_edges, dst, in_update)

  // For undirected graphs, also add the reverse edge
  case graph.kind {
    Directed -> model.Graph(..graph, out_edges: new_out, in_edges: new_in)
    Undirected -> {
      let out_update_rev = case dict.get(graph.out_edges, dst) {
        Ok(edges) -> dict.insert(edges, src, weight)
        Error(_) -> dict.from_list([#(src, weight)])
      }
      let in_update_rev = case dict.get(graph.in_edges, src) {
        Ok(edges) -> dict.insert(edges, dst, weight)
        Error(_) -> dict.from_list([#(dst, weight)])
      }
      model.Graph(
        ..graph,
        out_edges: dict.insert(new_out, dst, out_update_rev),
        in_edges: dict.insert(new_in, src, in_update_rev),
      )
    }
  }
}
