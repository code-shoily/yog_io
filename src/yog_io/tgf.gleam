//// Trivial Graph Format (TGF) serialization support.
////
//// Provides functions to serialize and deserialize graphs in TGF format,
//// a very simple text-based format suitable for quick graph exchange and debugging.
////
//// ## Format Overview
////
//// TGF consists of three parts:
//// 1. **Node section**: Each line is `node_id node_label`
//// 2. **Separator**: A single `#` character on its own line
//// 3. **Edge section**: Each line is `source_id target_id [edge_label]`
////
//// ## Example
////
//// ```gleam
//// import yog/model.{Directed}
//// import yog_io/tgf
////
//// // Create a simple graph
//// let graph =
////   model.new(Directed)
////   |> model.add_node(1, "Alice")
////   |> model.add_node(2, "Bob")
////
//// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "follows")
////
//// // Serialize to TGF
//// let tgf_string = tgf.serialize(graph)
////
//// // Write to file
//// let assert Ok(Nil) = tgf.write("graph.tgf", graph)
//// ```
////
//// ## Output Format
////
//// ```
//// 1 Alice
//// 2 Bob
//// #
//// 1 2 follows
//// ```
////
//// ## Characteristics
////
//// - **Human-readable**: Simple text format, easy to understand
//// - **Compact**: Minimal syntax overhead
//// - **No metadata**: Does not preserve graph type (directed/undirected)
//// - **Line-oriented**: One element per line
////
//// ## Parsing Behavior
////
//// When parsing TGF files, the following behaviors apply:
////
//// - **Auto-node creation**: If an edge references a node ID that was not declared
////   in the node section, a node is automatically created with the ID as its label.
////   This provides a lenient parsing mode that accepts minimal TGF files.
////
//// - **Empty labels**: Nodes without labels default to using their ID as the label
////   string. Edges without labels receive an empty string `""` which is passed to
////   the edge parser.
////
//// - **Whitespace handling**: Multiple consecutive spaces in labels are collapsed
////   to single spaces. Leading and trailing whitespace on lines is trimmed.
////
//// - **Malformed lines**: Lines that cannot be parsed are skipped and collected
////   as warnings in the `TgfResult`, rather than causing the entire parse to fail.
////
//// ## References
////
//// - [TGF on Wikipedia](https://en.wikipedia.org/wiki/Trivial_Graph_Format)
//// - [yEd TGF Import](https://yed.yworks.com/support/manual/tgf.html)

import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/string_tree as sb
import simplifile
import yog/model.{type Graph, type NodeId, Undirected}

// =============================================================================
// TYPES
// =============================================================================

/// Options for TGF serialization.
pub type TgfOptions(n, e) {
  TgfOptions(
    /// Function to convert node data to a label string
    node_label: fn(n) -> String,
    /// Function to convert edge data to an optional label string
    /// Returns None for no label (just source and target)
    edge_label: fn(e) -> Option(String),
  )
}

/// Default TGF serialization options.
///
/// Default configuration:
/// - Node labels: Uses the node data's string representation
/// - Edge labels: None (edges are just `source target`)
pub fn default_options() -> TgfOptions(String, String) {
  TgfOptions(node_label: fn(data: String) { data }, edge_label: fn(_: String) { None })
}

/// Creates TGF options with custom node and edge label functions.
///
/// ## Example
///
/// ```gleam
/// let options = tgf.options_with(
///   node_label: fn(person) { person.name },
///   edge_label: fn(weight) { Some(int.to_string(weight)) },
/// )
/// ```
pub fn options_with(
  node_label node_label: fn(n) -> String,
  edge_label edge_label: fn(e) -> Option(String),
) -> TgfOptions(n, e) {
  TgfOptions(node_label:, edge_label:)
}

/// Errors that can occur during TGF parsing.
pub type TgfError {
  /// Empty input string
  EmptyInput
  /// Invalid node line format
  InvalidNodeLine(line: Int, content: String)
  /// Invalid edge line format
  InvalidEdgeLine(line: Int, content: String)
  /// Invalid node ID (not an integer)
  InvalidNodeId(line: Int, value: String)
  /// Invalid edge endpoint (not an integer)
  InvalidEdgeEndpoint(line: Int, value: String)
  /// Duplicate node ID encountered
  DuplicateNodeId(line: Int, id: NodeId)
  /// File read error
  ReadError(path: String, error: String)
  /// File write error
  WriteError(path: String, error: String)
}

/// Result type for TGF parsing.
pub type TgfResult(n, e) {
  TgfResult(
    graph: Graph(n, e),
    /// Lines that couldn't be parsed (with line numbers)
    warnings: List(#(Int, String)),
  )
}

// =============================================================================
// SERIALIZATION
// =============================================================================

/// Serializes a graph to TGF format with custom label functions.
///
/// This function allows you to control how node and edge data are converted
/// to TGF labels.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
/// import yog_io/tgf
///
/// type Person {
///   Person(name: String, age: Int)
/// }
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, Person("Alice", 30))
///   |> model.add_node(2, Person("Bob", 25))
///   |> model.add_edge(from: 1, to: 2, with: "follows")
///
/// let options = tgf.options_with(
///   node_label: fn(p) { p.name },
///   edge_label: fn(label) { Some(label) },
/// )
///
/// let tgf_string = tgf.serialize_with(options, graph)
/// ```
pub fn serialize_with(options: TgfOptions(n, e), graph: Graph(n, e)) -> String {
  let builder = sb.new()

  // Generate node lines: "id label"
  let builder =
    dict.fold(graph.nodes, builder, fn(b, id, data) {
      let label = options.node_label(data)
      b
      |> sb.append(int.to_string(id))
      |> sb.append(" ")
      |> sb.append(label)
      |> sb.append("\n")
    })

  // Add separator
  let builder = sb.append(builder, "#\n")

  // Generate edge lines: "source target [label]"
  let builder =
    dict.fold(graph.out_edges, builder, fn(b, from_id, targets) {
      dict.fold(targets, b, fn(inner_b, to_id, weight) {
        // For undirected graphs, only output each edge once
        case graph.kind {
          Undirected if from_id > to_id -> inner_b
          _ -> {
            let base =
              int.to_string(from_id) <> " " <> int.to_string(to_id)
            let line = case options.edge_label(weight) {
              Some(label) -> base <> " " <> label <> "\n"
              None -> base <> "\n"
            }
            sb.append(inner_b, line)
          }
        }
      })
    })

  sb.to_string(builder)
}

/// Serializes a graph to TGF format.
///
/// Convenience function for graphs with String node and edge data.
///
/// ## Example
///
/// ```gleam
/// let tgf_string = tgf.serialize(graph)
/// ```
pub fn serialize(graph: Graph(String, String)) -> String {
  serialize_with(default_options(), graph)
}

/// Converts a graph to a TGF string.
///
/// Alias for `serialize` for consistency with other modules.
pub fn to_string(graph: Graph(String, String)) -> String {
  serialize(graph)
}

// =============================================================================
// FILE I/O
// =============================================================================

/// Writes a graph to a TGF file.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = tgf.write("graph.tgf", graph)
/// ```
pub fn write(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, simplifile.FileError) {
  let content = serialize(graph)
  simplifile.write(path, content)
}

/// Writes a graph to a TGF file with custom label functions.
///
/// ## Example
///
/// ```gleam
/// let options = tgf.options_with(
///   node_label: fn(p) { p.name },
///   edge_label: fn(w) { Some(int.to_string(w)) },
/// )
///
/// let assert Ok(Nil) = tgf.write_with("graph.tgf", options, graph)
/// ```
pub fn write_with(
  path: String,
  options: TgfOptions(n, e),
  graph: Graph(n, e),
) -> Result(Nil, simplifile.FileError) {
  let content = serialize_with(options, graph)
  simplifile.write(path, content)
}

// =============================================================================
// PARSING
// =============================================================================

/// Parses a TGF string into a graph with custom parsers.
///
/// The graph type (directed/undirected) must be specified since TGF
/// doesn't encode this information.
///
/// ## Example
///
/// ```gleam
/// let tgf_string = "1 Alice\n2 Bob\n#\n1 2 follows"
///
/// let result = tgf.parse_with(
///   tgf_string,
///   graph_type: Directed,
///   node_parser: fn(id, label) { label },
///   edge_parser: fn(label) { label },
/// )
///
/// case result {
///   Ok(tgf.TgfResult(graph, warnings)) -> {
///     // Use the graph
///     process_graph(graph)
///   }
///   Error(e) -> handle_error(e)
/// }
/// ```
pub fn parse_with(
  input: String,
  graph_type gtype: model.GraphType,
  node_parser node_parser: fn(NodeId, String) -> n,
  edge_parser edge_parser: fn(String) -> e,
) -> Result(TgfResult(n, e), TgfError) {
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
    _ -> do_parse(lines, gtype, node_parser, edge_parser)
  }
}

fn do_parse(
  lines: List(#(Int, String)),
  gtype: model.GraphType,
  node_parser: fn(NodeId, String) -> n,
  edge_parser: fn(String) -> e,
) -> Result(TgfResult(n, e), TgfError) {
  // Split into node section and edge section at the separator
  let #(node_lines, edge_lines) = split_at_separator(lines)

  // Parse nodes first
  case parse_nodes(node_lines, node_parser) {
    Error(e) -> Error(e)
    Ok(#(nodes, node_warnings)) -> {
      // Create base graph with parsed nodes
      let graph = create_graph_with_nodes(gtype, nodes)

      // Parse edges and add to graph
      case parse_edges(edge_lines, edge_parser, graph, node_parser) {
        Error(e) -> Error(e)
        Ok(#(final_graph, edge_warnings)) -> {
          let all_warnings = list.append(node_warnings, edge_warnings)
          Ok(TgfResult(graph: final_graph, warnings: all_warnings))
        }
      }
    }
  }
}

/// Split lines into node section and edge section at the # separator.
fn split_at_separator(
  lines: List(#(Int, String)),
) -> #(List(#(Int, String)), List(#(Int, String))) {
  do_split(lines, [])
}

fn do_split(
  lines: List(#(Int, String)),
  acc: List(#(Int, String)),
) -> #(List(#(Int, String)), List(#(Int, String))) {
  case lines {
    [] -> #(list.reverse(acc), [])
    [#(_, "#"), ..rest] -> #(list.reverse(acc), rest)
    [line, ..rest] -> do_split(rest, [line, ..acc])
  }
}

/// Parse node lines: "id label"
fn parse_nodes(
  lines: List(#(Int, String)),
  node_parser: fn(NodeId, String) -> n,
) -> Result(#(List(#(NodeId, n)), List(#(Int, String))), TgfError) {
  do_parse_nodes(lines, node_parser, [], [])
}

fn do_parse_nodes(
  lines: List(#(Int, String)),
  node_parser: fn(NodeId, String) -> n,
  acc: List(#(NodeId, n)),
  warnings: List(#(Int, String)),
) -> Result(#(List(#(NodeId, n)), List(#(Int, String))), TgfError) {
  case lines {
    [] -> Ok(#(acc, warnings))
    [#(line_num, line), ..rest] -> {
      case parse_node_line(line, line_num, node_parser) {
        Ok(#(id, data)) -> {
          // Check for duplicate IDs
          case list.any(acc, fn(pair) { pair.0 == id }) {
            True -> Error(DuplicateNodeId(line_num, id))
            False -> do_parse_nodes(rest, node_parser, [#(id, data), ..acc], warnings)
          }
        }
        Error(None) -> {
          // Skip empty/malformed line with warning
          do_parse_nodes(rest, node_parser, acc, [#(line_num, line), ..warnings])
        }
        Error(Some(e)) -> Error(e)
      }
    }
  }
}

/// Parse a single node line: "id label" or just "id"
fn parse_node_line(
  line: String,
  line_num: Int,
  node_parser: fn(NodeId, String) -> n,
) -> Result(#(NodeId, n), Option(TgfError)) {
  let parts =
    line
    |> string.split(" ")
    |> list.filter(fn(s) { string.trim(s) != "" })

  case parts {
    [] -> Error(None)
    [id_str, ..rest] -> {
      case int.parse(string.trim(id_str)) {
        Error(_) -> Error(Some(InvalidNodeId(line_num, id_str)))
        Ok(id) -> {
          let label = case rest {
            [] -> id_str
            _ -> string.join(rest, " ")
          }
          Ok(#(id, node_parser(id, label)))
        }
      }
    }
  }
}

/// Create a graph with the parsed nodes.
fn create_graph_with_nodes(
  gtype: model.GraphType,
  nodes: List(#(NodeId, n)),
) -> Graph(n, e) {
  list.fold(nodes, model.new(gtype), fn(graph, pair) {
    let #(id, data) = pair
    model.add_node(graph, id, data)
  })
}

/// Parse edge lines: "source target [label]"
fn parse_edges(
  lines: List(#(Int, String)),
  edge_parser: fn(String) -> e,
  graph: Graph(n, e),
  node_parser: fn(NodeId, String) -> n,
) -> Result(#(Graph(n, e), List(#(Int, String))), TgfError) {
  do_parse_edges(lines, edge_parser, graph, [], node_parser)
}

fn do_parse_edges(
  lines: List(#(Int, String)),
  edge_parser: fn(String) -> e,
  graph: Graph(n, e),
  warnings: List(#(Int, String)),
  node_parser: fn(NodeId, String) -> n,
) -> Result(#(Graph(n, e), List(#(Int, String))), TgfError) {
  case lines {
    [] -> Ok(#(graph, warnings))
    [#(line_num, line), ..rest] -> {
      case parse_edge_line(line, line_num, edge_parser, graph, node_parser) {
        Ok(new_graph) -> do_parse_edges(rest, edge_parser, new_graph, warnings, node_parser)
        Error(None) -> {
          // Skip malformed line with warning
          do_parse_edges(rest, edge_parser, graph, [#(line_num, line), ..warnings], node_parser)
        }
        Error(Some(e)) -> Error(e)
      }
    }
  }
}

/// Parse a single edge line: "source target [label]"
fn parse_edge_line(
  line: String,
  line_num: Int,
  edge_parser: fn(String) -> e,
  graph: Graph(n, e),
  node_parser: fn(NodeId, String) -> n,
) -> Result(Graph(n, e), Option(TgfError)) {
  let parts =
    line
    |> string.split(" ")
    |> list.filter(fn(s) { string.trim(s) != "" })

  case parts {
    [] | [_] -> Error(None)
    [src_str, tgt_str, ..rest] -> {
      case int.parse(string.trim(src_str)), int.parse(string.trim(tgt_str)) {
        Ok(src), Ok(tgt) -> {
          let edge_data = case rest {
            [] -> edge_parser("")
            _ -> edge_parser(string.join(rest, " "))
          }

          // Try to add edge - if nodes don't exist, create them
          let graph_with_nodes = ensure_nodes_exist(graph, src, tgt, node_parser)

          case model.add_edge(graph_with_nodes, from: src, to: tgt, with: edge_data) {
            Ok(new_graph) -> Ok(new_graph)
            Error(_) -> Error(None)
          }
        }
        Error(_), _ -> Error(Some(InvalidEdgeEndpoint(line_num, src_str)))
        _, Error(_) -> Error(Some(InvalidEdgeEndpoint(line_num, tgt_str)))
      }
    }
  }
}

/// Ensure both source and target nodes exist in the graph.
fn ensure_nodes_exist(
  graph: Graph(n, e),
  src: NodeId,
  tgt: NodeId,
  node_parser: fn(NodeId, String) -> n,
) -> Graph(n, e) {
  let graph_with_src = case dict.has_key(graph.nodes, src) {
    True -> graph
    False -> model.add_node(graph, src, node_parser(src, int.to_string(src)))
  }
  case dict.has_key(graph_with_src.nodes, tgt) {
    True -> graph_with_src
    False -> model.add_node(graph_with_src, tgt, node_parser(tgt, int.to_string(tgt)))
  }
}

/// Parses a TGF string into a graph with String labels.
///
/// Convenience function for the common case where both node and edge data
/// are just Strings.
///
/// ## Example
///
/// ```gleam
/// let tgf_string = "1 Alice\n2 Bob\n#\n1 2 follows"
///
/// case tgf.parse(tgf_string, Directed) {
///   Ok(result) -> {
///     // result.graph is Graph(String, String)
///     process_graph(result.graph)
///   }
///   Error(e) -> handle_error(e)
/// }
/// ```
pub fn parse(
  input: String,
  gtype: model.GraphType,
) -> Result(TgfResult(String, String), TgfError) {
  parse_with(
    input,
    graph_type: gtype,
    node_parser: fn(_id, label) { label },
    edge_parser: fn(label) { label },
  )
}

// =============================================================================
// FILE READING
// =============================================================================

/// Reads a graph from a TGF file.
///
/// Convenience function that reads node and edge data as strings.
///
/// ## Example
///
/// ```gleam
/// let result = tgf.read("graph.tgf", Directed)
///
/// case result {
///   Ok(tgf.TgfResult(graph, warnings)) -> {
///     // Use the graph
///     process_graph(graph)
///   }
///   Error(e) -> handle_error(e)
/// }
/// ```
pub fn read(
  path: String,
  gtype: model.GraphType,
) -> Result(TgfResult(String, String), TgfError) {
  case simplifile.read(path) {
    Ok(content) -> parse(content, gtype)
    Error(e) -> Error(ReadError(path, simplifile.describe_error(e)))
  }
}

/// Reads a graph from a TGF file with custom parsers.
///
/// ## Example
///
/// ```gleam
/// let result = tgf.read_with(
///   "graph.tgf",
///   graph_type: Directed,
///   node_parser: fn(id, label) { Person(id, label) },
///   edge_parser: fn(label) { String.to_int(label) },
/// )
/// ```
pub fn read_with(
  path: String,
  graph_type gtype: model.GraphType,
  node_parser node_parser: fn(NodeId, String) -> n,
  edge_parser edge_parser: fn(String) -> e,
) -> Result(TgfResult(n, e), TgfError) {
  case simplifile.read(path) {
    Ok(content) -> parse_with(content, graph_type: gtype, node_parser:, edge_parser:)
    Error(e) -> Error(ReadError(path, simplifile.describe_error(e)))
  }
}
