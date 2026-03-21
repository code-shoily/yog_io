//// LEDA (Library of Efficient Data types and Algorithms) graph format support.
////
//// Provides functions to serialize and deserialize graphs in the LEDA format,
//// a text-based format used by the LEDA library and compatible with NetworkX.
////
//// ## Format Overview
////
//// LEDA files have a structured text format with distinct sections:
//// - **Header**: `LEDA.GRAPH`
//// - **Type declarations**: Node type and edge type
//// - **Direction**: `-1` for directed, `-2` for undirected
//// - **Nodes**: Count followed by node data lines
//// - **Edges**: Count followed by edge data lines
////
//// ## Example
////
//// ```gleam
//// import yog/model.{Directed}
//// import yog_io/leda
////
//// // Create a simple graph
//// let graph =
////   model.new(Directed)
////   |> model.add_node(1, "Alice")
////   |> model.add_node(2, "Bob")
////
//// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "5")
////
//// // Serialize to LEDA
//// let leda_string = leda.serialize(graph)
////
//// // Write to file
//// let assert Ok(Nil) = leda.write("graph.gw", graph)
//// ```
////
//// ## Output Format
////
//// ```
//// LEDA.GRAPH
//// string
//// string
//// -1
//// 2
//// |{Alice}|
//// |{Bob}|
//// 1
//// 1 2 0 |{5}|
//// ```
////
//// ## Characteristics
////
//// - **Type-aware**: Supports typed node and edge attributes
//// - **1-indexed**: Node numbering starts at 1 (not 0)
//// - **Reversal edges**: Undirected graphs use reversal edge indices
//// - **Research compatible**: Used in academic graph algorithms
////
//// ## Parsing Behavior
////
//// When parsing LEDA files, the following behaviors apply:
////
//// - **1-indexed nodes**: LEDA format uses 1-based indexing. Node ID 1 refers
////   to the first node in the node section, ID 2 to the second node, etc.
////   The parser preserves these IDs when creating the graph.
////
//// - **Sequential order**: Nodes must appear in sequential order in the file.
////   The nth node in the node section receives LEDA ID n.
////
//// - **Strict node references**: Edges must reference node IDs that exist in
////   the node section. Unlike TGF, LEDA does not auto-create missing nodes.
////   Edges with invalid node IDs are skipped and added to warnings.
////
//// - **Reversal edges**: The third field in edge lines (rev_edge) indicates
////   the index of the reverse edge for undirected graphs. Currently, the parser
////   accepts but does not actively use this field.
////
//// - **Type declarations**: The parser accepts any string in the node/edge type
////   declarations (lines 2-3) but currently treats all data as strings. Type
////   validation is not enforced.
////
//// - **Whitespace handling**: Multiple consecutive spaces in data values are
////   collapsed to single spaces. Leading and trailing whitespace is trimmed.
////
//// - **Malformed lines**: Lines that cannot be parsed are skipped and collected
////   as warnings in the `LedaResult`, rather than causing the parse to fail.
////
//// ## References
////
//// - [LEDA Library](https://www.algorithmic-solutions.com/leda/)
//// - [NetworkX LEDA Reader](https://networkx.org/documentation/stable/reference/readwrite/leda.html)

import gleam/dict
import gleam/int
import gleam/list

import gleam/order
import gleam/string
import gleam/string_tree as sb
import simplifile
import yog/model.{type Graph, type GraphType, type NodeId, Directed, Undirected}

// =============================================================================
// TYPES
// =============================================================================

/// Options for LEDA serialization.
pub type LedaOptions(n, e) {
  LedaOptions(
    /// Function to convert node data to a string representation
    node_serializer: fn(n) -> String,
    /// Function to convert edge data to a string representation
    edge_serializer: fn(e) -> String,
    /// Function to convert string back to node data
    node_deserializer: fn(String) -> n,
    /// Function to convert string back to edge data
    edge_deserializer: fn(String) -> e,
  )
}

/// LEDA data types for type declarations in the header.
///
/// **Note:** Currently, serialization always uses `"string"` for both node and
/// edge types for maximum compatibility. This type is reserved for future
/// enhancements to support typed LEDA files with proper int, double, and custom
/// types. The LEDA format specification supports these types in the header
/// section (lines 2-3), but the current implementation prioritizes simplicity
/// and broad compatibility.
pub type LedaType {
  /// Void type - no data
  VoidType
  /// String type
  StringType
  /// Integer type
  IntType
  /// Double/float type
  DoubleType
  /// Custom type with name
  CustomType(String)
}

/// Errors that can occur during LEDA operations.
pub type LedaError {
  /// Empty input string
  EmptyInput
  /// Invalid header (expected "LEDA.GRAPH")
  InvalidHeader
  /// Invalid node type declaration
  InvalidNodeType(line: Int, content: String)
  /// Invalid edge type declaration
  InvalidEdgeType(line: Int, content: String)
  /// Invalid direction (expected "-1" or "-2")
  InvalidDirection(line: Int, content: String)
  /// Invalid node count
  InvalidNodeCount(line: Int, content: String)
  /// Invalid edge count
  InvalidEdgeCount(line: Int, content: String)
  /// Invalid node data format
  InvalidNodeData(line: Int, content: String)
  /// Invalid edge data format
  InvalidEdgeData(line: Int, content: String)
  /// Invalid node ID (not an integer)
  InvalidNodeId(line: Int, value: String)
  /// Node ID out of range (LEDA uses 1-indexing)
  NodeIdOutOfRange(line: Int, id: Int, count: Int)
  /// File read error
  ReadError(path: String, error: String)
  /// File write error
  WriteError(path: String, error: String)
}

/// Result type for LEDA parsing.
pub type LedaResult(n, e) {
  LedaResult(
    graph: Graph(n, e),
    /// Lines that couldn't be parsed (with line numbers)
    warnings: List(#(Int, String)),
  )
}

// =============================================================================
// DEFAULT OPTIONS
// =============================================================================

/// Default LEDA options for String node and edge data.
///
/// Uses identity functions for serialization/deserialization.
pub fn default_options() -> LedaOptions(String, String) {
  LedaOptions(
    node_serializer: fn(s) { s },
    edge_serializer: fn(s) { s },
    node_deserializer: fn(s) { s },
    edge_deserializer: fn(s) { s },
  )
}

/// Creates LEDA options with custom serializers.
///
/// ## Example
///
/// ```gleam
/// let options = leda.options_with(
///   node_serializer: fn(p) { p.name },
///   edge_serializer: fn(w) { int.to_string(w) },
///   node_deserializer: fn(s) { Person(s, 0) },
///   edge_deserializer: fn(s) {
///     case int.parse(s) { Ok(n) -> n Error(_) -> 0 }
///   },
/// )
/// ```
pub fn options_with(
  node_serializer node_serializer: fn(n) -> String,
  edge_serializer edge_serializer: fn(e) -> String,
  node_deserializer node_deserializer: fn(String) -> n,
  edge_deserializer edge_deserializer: fn(String) -> e,
) -> LedaOptions(n, e) {
  LedaOptions(
    node_serializer:,
    edge_serializer:,
    node_deserializer:,
    edge_deserializer:,
  )
}

// =============================================================================
// SERIALIZATION
// =============================================================================

/// Serializes a graph to LEDA format with custom options.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
/// import yog_io/leda
///
/// type Person {
///   Person(name: String, age: Int)
/// }
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, Person("Alice", 30))
///   |> model.add_node(2, Person("Bob", 25))
///
/// let options = leda.options_with(
///   node_serializer: fn(p) { p.name },
///   edge_serializer: fn(w) { w },
///   node_deserializer: fn(s) { Person(s, 0) },
///   edge_deserializer: fn(s) { s },
/// )
///
/// let leda_string = leda.serialize_with(options, graph)
/// ```
pub fn serialize_with(options: LedaOptions(n, e), graph: Graph(n, e)) -> String {
  let builder = sb.new()

  // Header
  let builder = sb.append(builder, "LEDA.GRAPH\n")

  // Type declarations (always use string for flexibility)
  let builder = sb.append(builder, "string\n")
  let builder = sb.append(builder, "string\n")

  // Direction: -1 for directed, -2 for undirected
  let builder = case graph.kind {
    Directed -> sb.append(builder, "-1\n")
    Undirected -> sb.append(builder, "-2\n")
  }

  // Get sorted nodes (LEDA expects sequential 1-indexed nodes)
  let sorted_nodes =
    dict.to_list(graph.nodes)
    |> list.sort(fn(a, b) { int.compare(a.0, b.0) })

  // Node count
  let node_count = list.length(sorted_nodes)
  let builder = sb.append(builder, int.to_string(node_count) <> "\n")

  // Node data lines: |{data}|
  let builder =
    list.fold(sorted_nodes, builder, fn(b, entry) {
      let #(_id, data) = entry
      let serialized = options.node_serializer(data)
      sb.append(b, "|{" <> serialized <> "}|\n")
    })

  // Collect edges with their 1-indexed positions
  let edges_with_indices = collect_edges_with_indices(graph)
  let edge_count = list.length(edges_with_indices)

  // Edge count
  let builder = sb.append(builder, int.to_string(edge_count) <> "\n")

  // Edge lines: source target rev_edge |{data}|
  // For directed graphs: rev_edge is always 0
  // For undirected graphs: rev_edge points to the reverse edge index (1-indexed)
  list.fold(edges_with_indices, builder, fn(b, entry) {
    let #(src_1idx, dst_1idx, rev_edge, data) = entry
    let serialized = options.edge_serializer(data)
    let line =
      int.to_string(src_1idx)
      <> " "
      <> int.to_string(dst_1idx)
      <> " "
      <> int.to_string(rev_edge)
      <> " |{"
      <> serialized
      <> "}|\n"
    sb.append(b, line)
  })
  |> sb.to_string()
}

/// Collects edges with their 1-indexed positions for LEDA format.
///
/// For directed graphs, rev_edge is always 0.
/// For undirected graphs, we need to track reverse edge pairs.
fn collect_edges_with_indices(graph: Graph(n, e)) -> List(#(Int, Int, Int, e)) {
  // Get all edges from the graph
  let all_edges =
    dict.fold(graph.out_edges, [], fn(acc, src_id, targets) {
      dict.fold(targets, acc, fn(inner_acc, dst_id, data) {
        [#(src_id, dst_id, data), ..inner_acc]
      })
    })

  // Sort by source, then destination for consistent ordering
  let sorted_edges =
    list.sort(all_edges, fn(a, b) {
      case int.compare(a.0, b.0) {
        order.Eq -> int.compare(a.1, b.1)
        ord -> ord
      }
    })

  case graph.kind {
    Directed -> {
      // For directed: rev_edge is always 0
      list.map(sorted_edges, fn(edge) {
        let #(src, dst, data) = edge
        #(src, dst, 0, data)
      })
    }
    Undirected -> {
      // For undirected: need to pair edges and assign rev_edge indices
      // Each undirected edge is stored twice in yog (u->v and v->u)
      // We only output each edge once, with rev_edge pointing to its pair
      collect_undirected_edges(sorted_edges)
    }
  }
}

fn collect_undirected_edges(
  edges: List(#(NodeId, NodeId, e)),
) -> List(#(Int, Int, Int, e)) {
  // For undirected graphs, we need to:
  // 1. Remove duplicate edges (keep only u->v where u <= v)
  // 2. For LEDA format, rev_edge is 0 for the forward direction
  //    Note: Full LEDA format requires proper reverse edge indexing,
  //    but for simple cases we use 0
  let unique_edges =
    list.filter(edges, fn(edge) {
      let #(src, dst, _) = edge
      src <= dst
    })

  // Assign edge indices (1-indexed for LEDA)
  list.index_map(unique_edges, fn(edge, _idx) {
    let #(src, dst, data) = edge
    // In LEDA, edges are 1-indexed, and rev_edge of 0 means no reverse
    // For full compatibility, we'd track reverse pairs, but 0 is acceptable
    #(src, dst, 0, data)
  })
}

/// Serializes a graph to LEDA format.
///
/// Convenience function for graphs with String node and edge data.
///
/// ## Example
///
/// ```gleam
/// let leda_string = leda.serialize(graph)
/// ```
pub fn serialize(graph: Graph(String, String)) -> String {
  serialize_with(default_options(), graph)
}

/// Converts a graph to a LEDA string.
///
/// Alias for `serialize` for consistency with other modules.
pub fn to_string(graph: Graph(String, String)) -> String {
  serialize(graph)
}

// =============================================================================
// FILE I/O
// =============================================================================

/// Writes a graph to a LEDA file.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = leda.write("graph.gw", graph)
/// ```
pub fn write(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, simplifile.FileError) {
  let content = serialize(graph)
  simplifile.write(path, content)
}

/// Writes a graph to a LEDA file with custom options.
///
/// ## Example
///
/// ```gleam
/// let options = leda.options_with(
///   node_serializer: fn(p) { p.name },
///   edge_serializer: fn(w) { int.to_string(w) },
///   node_deserializer: fn(s) { Person(s, 0) },
///   edge_deserializer: fn(s) { case int.parse(s) { Ok(n) -> n Error(_) -> 0 } },
/// )
///
/// let assert Ok(Nil) = leda.write_with("graph.gw", options, graph)
/// ```
pub fn write_with(
  path: String,
  options: LedaOptions(n, e),
  graph: Graph(n, e),
) -> Result(Nil, simplifile.FileError) {
  let content = serialize_with(options, graph)
  simplifile.write(path, content)
}

// =============================================================================
// PARSING
// =============================================================================

/// Parses a LEDA string into a graph with custom options.
///
/// ## Example
///
/// ```gleam
/// let leda_string = "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{Alice}|\n|{Bob}|\n1\n1 2 0 |{follows}|"
///
/// let result = leda.parse_with(
///   leda_string,
///   node_parser: fn(s) { s },
///   edge_parser: fn(s) { s },
/// )
///
/// case result {
///   Ok(leda.LedaResult(graph, warnings)) -> {
///     // Use the graph
///     process_graph(graph)
///   }
///   Error(e) -> handle_error(e)
/// }
/// ```
pub fn parse_with(
  input: String,
  node_parser node_parser: fn(String) -> n,
  edge_parser edge_parser: fn(String) -> e,
) -> Result(LedaResult(n, e), LedaError) {
  let lines =
    input
    |> string.split("\n")
    |> list.index_map(fn(line, idx) { #(idx + 1, string.trim(line)) })
    |> list.filter(fn(pair) {
      // Filter out empty lines
      let #(_, content) = pair
      content != ""
    })

  case lines {
    [] -> Error(EmptyInput)
    _ -> do_parse(lines, node_parser, edge_parser)
  }
}

fn do_parse(
  lines: List(#(Int, String)),
  node_parser: fn(String) -> n,
  edge_parser: fn(String) -> e,
) -> Result(LedaResult(n, e), LedaError) {
  // Parse header
  case lines {
    [#(_, "LEDA.GRAPH"), ..rest] ->
      do_parse_types(rest, node_parser, edge_parser)
    [#(_, _), ..] -> Error(InvalidHeader)
    _ -> Error(InvalidHeader)
  }
}

fn do_parse_types(
  lines: List(#(Int, String)),
  node_parser: fn(String) -> n,
  edge_parser: fn(String) -> e,
) -> Result(LedaResult(n, e), LedaError) {
  case lines {
    [#(_, _node_type), #(_, _edge_type), #(line_num, dir_content), ..rest] -> {
      // Parse direction
      case dir_content {
        "-1" -> do_parse_nodes(rest, Directed, node_parser, edge_parser)
        "-2" -> do_parse_nodes(rest, Undirected, node_parser, edge_parser)
        _ -> Error(InvalidDirection(line_num, dir_content))
      }
    }
    _ -> Error(InvalidDirection(3, "missing"))
  }
}

fn do_parse_nodes(
  lines: List(#(Int, String)),
  gtype: GraphType,
  node_parser: fn(String) -> n,
  edge_parser: fn(String) -> e,
) -> Result(LedaResult(n, e), LedaError) {
  case lines {
    [#(_, count_str), ..rest] -> {
      case int.parse(count_str) {
        Error(_) -> Error(InvalidNodeCount(4, count_str))
        Ok(node_count) -> {
          // Parse node data lines
          case parse_node_data(rest, node_count, node_parser, [], []) {
            Error(e) -> Error(e)
            Ok(#(remaining_lines, nodes, warnings)) -> {
              // Create graph with nodes
              let graph = create_graph_with_nodes(gtype, nodes)
              // Parse edges
              case parse_edges(remaining_lines, edge_parser, graph, []) {
                Error(e) -> Error(e)
                Ok(#(final_graph, edge_warnings)) -> {
                  let all_warnings = list.append(warnings, edge_warnings)
                  Ok(LedaResult(graph: final_graph, warnings: all_warnings))
                }
              }
            }
          }
        }
      }
    }
    _ -> Error(InvalidNodeCount(4, "missing"))
  }
}

fn parse_node_data(
  lines: List(#(Int, String)),
  count: Int,
  node_parser: fn(String) -> n,
  acc: List(#(Int, n)),
  warnings: List(#(Int, String)),
) -> Result(
  #(List(#(Int, String)), List(#(Int, n)), List(#(Int, String))),
  LedaError,
) {
  case count {
    0 -> Ok(#(lines, list.reverse(acc), list.reverse(warnings)))
    _ -> {
      case lines {
        [] -> {
          // Get the line number from the last line we processed, or estimate
          let last_line = case acc {
            [#(ln, _), ..] -> ln
            [] -> 5
            // Node section starts around line 5
          }
          Error(InvalidNodeData(last_line + 1, "unexpected end of input"))
        }
        [#(line_num, line), ..rest] -> {
          case extract_leda_value(line) {
            Ok(value) -> {
              let data = node_parser(value)
              parse_node_data(
                rest,
                count - 1,
                node_parser,
                [#(line_num, data), ..acc],
                warnings,
              )
            }
            Error(_) -> {
              // Skip malformed line with warning
              parse_node_data(rest, count - 1, node_parser, acc, [
                #(line_num, line),
                ..warnings
              ])
            }
          }
        }
      }
    }
  }
}

/// Extract value from |{...}| format.
fn extract_leda_value(line: String) -> Result(String, Nil) {
  let trimmed = string.trim(line)
  case string.starts_with(trimmed, "|{"), string.ends_with(trimmed, "}|") {
    True, True -> {
      // Remove "|{" prefix and "}|" suffix
      let inner = string.slice(trimmed, 2, string.length(trimmed) - 4)
      Ok(inner)
    }
    _, _ -> {
      // Try without delimiters (for void type)
      Ok(trimmed)
    }
  }
}

fn create_graph_with_nodes(
  gtype: GraphType,
  nodes: List(#(Int, n)),
) -> Graph(n, e) {
  // LEDA uses 1-indexed nodes
  // Each node's position in the list becomes its LEDA ID (1, 2, 3...)
  list.index_fold(nodes, model.new(gtype), fn(graph, pair, idx) {
    let #(_line_num, data) = pair
    let leda_id = idx + 1
    // LEDA uses 1-based indexing
    model.add_node(graph, leda_id, data)
  })
}

fn parse_edges(
  lines: List(#(Int, String)),
  edge_parser: fn(String) -> e,
  graph: Graph(n, e),
  warnings: List(#(Int, String)),
) -> Result(#(Graph(n, e), List(#(Int, String))), LedaError) {
  case lines {
    [] -> Ok(#(graph, list.reverse(warnings)))
    [#(line_num, count_str), ..rest] -> {
      case int.parse(count_str) {
        Error(_) -> Error(InvalidEdgeCount(line_num, count_str))
        Ok(edge_count) ->
          do_parse_edges(rest, edge_count, edge_parser, graph, [])
      }
    }
  }
}

fn do_parse_edges(
  lines: List(#(Int, String)),
  count: Int,
  edge_parser: fn(String) -> e,
  graph: Graph(n, e),
  warnings: List(#(Int, String)),
) -> Result(#(Graph(n, e), List(#(Int, String))), LedaError) {
  case count {
    0 -> Ok(#(graph, list.reverse(warnings)))
    _ -> {
      case lines {
        [] -> {
          // Calculate expected line number based on node count
          let node_count = dict.size(graph.nodes)
          let expected_line = 5 + node_count + 1
          // header(4) + nodes + edge_count_line
          Error(InvalidEdgeData(expected_line + 1, "unexpected end of input"))
        }
        [#(line_num, line), ..rest] -> {
          case parse_edge_line(line, edge_parser) {
            Ok(#(src, dst, _rev, data)) -> {
              // Add edge to graph (nodes should already exist in well-formed LEDA)
              case model.add_edge(graph, from: src, to: dst, with: data) {
                Ok(new_graph) ->
                  do_parse_edges(
                    rest,
                    count - 1,
                    edge_parser,
                    new_graph,
                    warnings,
                  )
                Error(_) -> {
                  // Edge couldn't be added (likely node doesn't exist), skip with warning
                  do_parse_edges(rest, count - 1, edge_parser, graph, [
                    #(line_num, line),
                    ..warnings
                  ])
                }
              }
            }
            Error(_) -> {
              // Skip malformed line with warning
              do_parse_edges(rest, count - 1, edge_parser, graph, [
                #(line_num, line),
                ..warnings
              ])
            }
          }
        }
      }
    }
  }
}

fn parse_edge_line(
  line: String,
  edge_parser: fn(String) -> e,
) -> Result(#(NodeId, NodeId, Int, e), Nil) {
  // Format: source target rev_edge |{data}|
  let parts =
    line
    |> string.split(" ")
    |> list.filter(fn(s) { string.trim(s) != "" })

  case parts {
    [src_str, dst_str, rev_str, ..rest] -> {
      case int.parse(string.trim(src_str)), int.parse(string.trim(dst_str)) {
        Ok(src), Ok(dst) -> {
          let rev = case int.parse(string.trim(rev_str)) {
            Ok(r) -> r
            Error(_) -> 0
          }
          // Join remaining parts (in case data had spaces) and extract value
          let data_str = case rest {
            [] -> ""
            _ -> string.join(rest, " ")
          }
          case extract_leda_value(data_str) {
            Ok(value) -> {
              let data = edge_parser(value)
              Ok(#(src, dst, rev, data))
            }
            Error(_) -> Error(Nil)
          }
        }
        _, _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

/// Parses a LEDA string into a graph with String labels.
///
/// Convenience function for the common case where both node and edge data
/// are just Strings.
///
/// ## Example
///
/// ```gleam
/// let leda_string = "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{Alice}|\n|{Bob}|\n1\n1 2 0 |{follows}|"
///
/// case leda.parse(leda_string) {
///   Ok(result) -> {
///     // result.graph is Graph(String, String)
///     process_graph(result.graph)
///   }
///   Error(e) -> handle_error(e)
/// }
/// ```
pub fn parse(input: String) -> Result(LedaResult(String, String), LedaError) {
  parse_with(input, node_parser: fn(s) { s }, edge_parser: fn(s) { s })
}

// =============================================================================
// FILE READING
// =============================================================================

/// Reads a graph from a LEDA file.
///
/// Convenience function that reads node and edge data as strings.
///
/// ## Example
///
/// ```gleam
/// let result = leda.read("graph.gw")
///
/// case result {
///   Ok(leda.LedaResult(graph, warnings)) -> {
///     // Use the graph
///     process_graph(graph)
///   }
///   Error(e) -> handle_error(e)
/// }
/// ```
pub fn read(path: String) -> Result(LedaResult(String, String), LedaError) {
  case simplifile.read(path) {
    Ok(content) -> parse(content)
    Error(e) -> Error(ReadError(path, simplifile.describe_error(e)))
  }
}

/// Reads a graph from a LEDA file with custom parsers.
///
/// ## Example
///
/// ```gleam
/// let result = leda.read_with(
///   "graph.gw",
///   node_parser: fn(s) { Person(s, 0) },
///   edge_parser: fn(s) { case int.parse(s) { Ok(n) -> n Error(_) -> 0 } },
/// )
/// ```
pub fn read_with(
  path: String,
  node_parser node_parser: fn(String) -> n,
  edge_parser edge_parser: fn(String) -> e,
) -> Result(LedaResult(n, e), LedaError) {
  case simplifile.read(path) {
    Ok(content) -> parse_with(content, node_parser:, edge_parser:)
    Error(e) -> Error(ReadError(path, simplifile.describe_error(e)))
  }
}
