//// Pajek (.net) format serialization support.
////
//// Provides functions to serialize and deserialize graphs in the Pajek .net format,
//// a standard format for social network analysis used by the Pajek software and
//// compatible with many network analysis tools.
////
//// ## Format Overview
////
//// Pajek files have a structured text format with distinct sections:
//// - **Vertices**: `*Vertices N` followed by node definitions
//// - **Arcs**: `*Arcs` section for directed edges
//// - **Edges**: `*Edges` section for undirected edges
////
//// ## Example
////
//// ```gleam
//// import yog/model.{Directed}
//// import yog_io/pajek
////
//// // Create a simple graph
//// let graph =
////   model.new(Directed)
////   |> model.add_node(1, "Alice")
////   |> model.add_node(2, "Bob")
////
//// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "5")
////
//// // Serialize to Pajek
//// let pajek_string = pajek.serialize(graph)
////
//// // Write to file
//// let assert Ok(Nil) = pajek.write("graph.net", graph)
//// ```
////
//// ## Output Format
////
//// ```
//// *Vertices 3
//// 1 "Alice"
//// 2 "Bob"
//// 3 "Carol"
//// *Arcs
//// 1 2 5
//// 2 3 3
//// ```
////
//// ## Characteristics
////
//// - **Social network standard**: Widely used in academic research
//// - **Node coordinates**: Supports x, y positioning
//// - **Visual attributes**: Node shapes, colors, sizes
//// - **Weighted edges**: Supports edge weights
//// - **1-indexed**: Node numbering starts at 1
////
//// ## Parsing Behavior
////
//// When parsing Pajek .net files, the following behaviors apply:
////
//// - **Node IDs from *Vertices section**: All nodes must be declared in the
////   *Vertices section at the beginning of the file. Node IDs are preserved
////   from the file.
////
//// - **Graph type determination**: The graph type (directed/undirected) is
////   determined by the edge section header: `*Arcs` for directed graphs,
////   `*Edges` for undirected graphs. Header matching is case-insensitive.
////
//// - **Multi-word labels**: Node labels can contain spaces when enclosed in
////   double quotes (e.g., `1 "Alice Smith"`). Quotes are required for
////   multi-word labels and are stripped during parsing.
////
//// - **Optional weights**: Edge/arc lines can include optional weights as a
////   third field (e.g., `1 2 5.0`). Weights are parsed as floats and passed
////   to the edge parser.
////
//// - **Comment handling**: Lines starting with `%` are treated as comments
////   and ignored during parsing.
////
//// - **Strict node references**: Edges/arcs must reference node IDs that exist
////   in the *Vertices section. Unlike TGF, Pajek does not auto-create missing
////   nodes. Edges with invalid node IDs are skipped and added to warnings.
////
//// - **Visual attributes**: The parser currently extracts only the node label,
////   ignoring additional fields like coordinates, shapes, and colors. These
////   are preserved during serialization if provided via options.
////
//// - **Section order**: Files must start with a *Vertices section. The *Arcs
////   or *Edges section follows. Additional sections (if present) are ignored.
////
//// - **Whitespace handling**: Multiple consecutive spaces are handled correctly
////   in both vertex and edge lines. Leading and trailing whitespace is trimmed.
////
//// - **Malformed lines**: Lines that cannot be parsed are skipped and collected
////   as warnings in the `PajekResult`, rather than causing the parse to fail.
////
//// ## References
////
//// - [Pajek Software](http://mrvar.fdv.uni-lj.si/pajek/)
//// - [Pajek Format Specification](http://mrvar.fdv.uni-lj.si/pajek/dokuwiki/doku.php?id=description_of_net_file_format)

import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order

import gleam/string
import gleam/string_tree as sb
import simplifile
import yog/model.{type Graph, type GraphType, type NodeId, Directed, Undirected}

// =============================================================================
// TYPES
// =============================================================================

/// Node shape options for Pajek visualization.
pub type NodeShape {
  /// Default ellipse shape
  Ellipse
  /// Box/rectangle shape
  Box
  /// Diamond shape
  Diamond
  /// Triangle shape
  Triangle
  /// Cross shape
  Cross
  /// Empty shape (invisible node)
  Empty
  /// Custom shape name
  CustomShape(String)
}

/// Node visual attributes for Pajek format.
pub type NodeAttributes {
  NodeAttributes(
    /// X coordinate (0.0 to 1.0)
    x: Option(Float),
    /// Y coordinate (0.0 to 1.0)
    y: Option(Float),
    /// Node shape
    shape: Option(NodeShape),
    /// Node size
    size: Option(Float),
    /// Node color (hex or name)
    color: Option(String),
  )
}

/// Options for Pajek serialization.
pub type PajekOptions(n, e) {
  PajekOptions(
    /// Function to convert node data to a label string
    node_label: fn(n) -> String,
    /// Function to convert edge data to a weight (optional)
    edge_weight: fn(e) -> Option(Float),
    /// Function to get node attributes (for visualization)
    node_attributes: fn(n) -> NodeAttributes,
    /// Include node coordinates in output
    include_coordinates: Bool,
    /// Include visual attributes (shape, color, size)
    include_visuals: Bool,
  )
}

/// Errors that can occur during Pajek operations.
pub type PajekError {
  /// Empty input string
  EmptyInput
  /// Invalid *Vertices line
  InvalidVerticesLine(line: Int, content: String)
  /// Invalid vertex/node line
  InvalidVertexLine(line: Int, content: String)
  /// Invalid *Arcs or *Edges section header
  InvalidSectionHeader(line: Int, content: String)
  /// Invalid arc/edge line
  InvalidArcLine(line: Int, content: String)
  /// Invalid node ID
  InvalidNodeId(line: Int, value: String)
  /// Invalid weight value
  InvalidWeight(line: Int, value: String)
  /// Node ID out of range
  NodeIdOutOfRange(line: Int, id: Int, max: Int)
  /// Missing *Vertices section
  MissingVerticesSection
  /// File read error
  ReadError(path: String, error: String)
  /// File write error
  WriteError(path: String, error: String)
}

/// Result type for Pajek parsing.
pub type PajekResult(n, e) {
  PajekResult(
    graph: Graph(n, e),
    /// Lines that couldn't be parsed (with line numbers)
    warnings: List(#(Int, String)),
  )
}

// =============================================================================
// DEFAULT OPTIONS
// =============================================================================

/// Default node attributes (no special visualization).
pub fn default_node_attributes() -> NodeAttributes {
  NodeAttributes(x: None, y: None, shape: None, size: None, color: None)
}

/// Default Pajek options for String node and edge data.
///
/// Default configuration:
/// - Node labels: Uses the node data's string representation
/// - Edge weights: None (no weights)
/// - Node attributes: None
/// - Include coordinates: False
/// - Include visuals: False
pub fn default_options() -> PajekOptions(String, String) {
  PajekOptions(
    node_label: fn(data) { data },
    edge_weight: fn(_) { None },
    node_attributes: fn(_) { default_node_attributes() },
    include_coordinates: False,
    include_visuals: False,
  )
}

/// Creates Pajek options with custom functions.
///
/// ## Example
///
/// ```gleam
/// let options = pajek.options_with(
///   node_label: fn(p) { p.name },
///   edge_weight: fn(w) { Some(w) },
///   node_attributes: fn(p) { pajek.NodeAttributes(
///     x: Some(p.x),
///     y: Some(p.y),
///     shape: Some(pajek.Ellipse),
///     size: None,
///     color: None,
///   )},
///   include_coordinates: True,
///   include_visuals: False,
/// )
/// ```
pub fn options_with(
  node_label node_label: fn(n) -> String,
  edge_weight edge_weight: fn(e) -> Option(Float),
  node_attributes node_attributes: fn(n) -> NodeAttributes,
  include_coordinates include_coordinates: Bool,
  include_visuals include_visuals: Bool,
) -> PajekOptions(n, e) {
  PajekOptions(
    node_label:,
    edge_weight:,
    node_attributes:,
    include_coordinates:,
    include_visuals:,
  )
}

// =============================================================================
// SERIALIZATION
// =============================================================================

/// Serializes a graph to Pajek format with custom options.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
/// import yog_io/pajek
///
/// type Person {
///   Person(name: String, x: Float, y: Float)
/// }
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, Person("Alice", 0.5, 0.5))
///   |> model.add_node(2, Person("Bob", 0.7, 0.3))
///
/// let options = pajek.options_with(
///   node_label: fn(p) { p.name },
///   edge_weight: fn(w) { None },
///   node_attributes: fn(p) { pajek.NodeAttributes(
///     x: Some(p.x),
///     y: Some(p.y),
///     shape: None,
///     size: None,
///     color: None,
///   )},
///   include_coordinates: True,
///   include_visuals: False,
/// )
///
/// let pajek_string = pajek.serialize_with(options, graph)
/// ```
pub fn serialize_with(options: PajekOptions(n, e), graph: Graph(n, e)) -> String {
  let builder = sb.new()

  // Get sorted nodes (Pajek uses 1-indexed sequential nodes)
  let sorted_nodes =
    dict.to_list(graph.nodes)
    |> list.sort(fn(a, b) { int.compare(a.0, b.0) })

  let node_count = list.length(sorted_nodes)

  // *Vertices section
  let builder =
    sb.append(builder, "*Vertices " <> int.to_string(node_count) <> "\n")

  // Node lines: id "label" [x y shape ...]
  let builder =
    list.fold(sorted_nodes, builder, fn(b, entry) {
      let #(id, data) = entry
      let label = options.node_label(data)
      let attrs = options.node_attributes(data)

      // Build node line
      let line = build_node_line(id, label, attrs, options)
      sb.append(b, line <> "\n")
    })

  // Separate arcs/edges based on graph type
  case graph.kind {
    Directed -> {
      // *Arcs section for directed graphs
      let arcs = collect_edges_with_options(graph, options, True)
      case list.is_empty(arcs) {
        True -> sb.to_string(builder)
        False -> {
          let builder = sb.append(builder, "*Arcs\n")
          list.fold(arcs, builder, fn(b, edge) {
            let #(src, dst, weight) = edge
            let line = build_edge_line(src, dst, weight)
            sb.append(b, line <> "\n")
          })
          |> sb.to_string()
        }
      }
    }
    Undirected -> {
      // *Edges section for undirected graphs
      let edges = collect_edges_with_options(graph, options, False)
      case list.is_empty(edges) {
        True -> sb.to_string(builder)
        False -> {
          let builder = sb.append(builder, "*Edges\n")
          list.fold(edges, builder, fn(b, edge) {
            let #(src, dst, weight) = edge
            let line = build_edge_line(src, dst, weight)
            sb.append(b, line <> "\n")
          })
          |> sb.to_string()
        }
      }
    }
  }
}

/// Build a node line in Pajek format.
fn build_node_line(
  id: NodeId,
  label: String,
  attrs: NodeAttributes,
  options: PajekOptions(n, e),
) -> String {
  // Base line: id "label"
  let base = int.to_string(id) <> " \"" <> label <> "\""

  // Add coordinates if requested
  let with_coords = case options.include_coordinates {
    False -> base
    True -> {
      case attrs.x, attrs.y {
        Some(x), Some(y) ->
          base <> " " <> format_float(x) <> " " <> format_float(y)
        _, _ -> base
      }
    }
  }

  // Add visual attributes if requested
  case options.include_visuals {
    False -> with_coords
    True -> {
      let with_shape = case attrs.shape {
        Some(shape) -> with_coords <> " " <> shape_to_string(shape)
        None -> with_coords
      }
      let with_size = case attrs.size {
        Some(size) -> with_shape <> " " <> format_float(size)
        None -> with_shape
      }
      case attrs.color {
        Some(color) -> with_size <> " " <> color
        None -> with_size
      }
    }
  }
}

/// Format a float for Pajek output.
fn format_float(f: Float) -> String {
  // Pajek uses decimal format
  float.to_string(f)
}

/// Convert NodeShape to Pajek string.
fn shape_to_string(shape: NodeShape) -> String {
  case shape {
    Ellipse -> "ellipse"
    Box -> "box"
    Diamond -> "diamond"
    Triangle -> "triangle"
    Cross -> "cross"
    Empty -> "empty"
    CustomShape(s) -> s
  }
}

/// Collect edges from the graph, converting to 1-indexed sequential IDs.
fn collect_edges_with_options(
  graph: Graph(n, e),
  options: PajekOptions(n, e),
  is_directed: Bool,
) -> List(#(Int, Int, Option(Float))) {
  let all_edges =
    dict.fold(graph.out_edges, [], fn(acc, src_id, targets) {
      dict.fold(targets, acc, fn(inner_acc, dst_id, data) {
        [#(src_id, dst_id, data), ..inner_acc]
      })
    })

  // For undirected graphs, only include each edge once (src <= dst)
  let filtered_edges = case is_directed {
    True -> all_edges
    False ->
      list.filter(all_edges, fn(edge) {
        let #(src, dst, _) = edge
        src <= dst
      })
  }

  // Sort by source, then destination for consistent ordering
  let sorted_edges =
    list.sort(filtered_edges, fn(a, b) {
      case int.compare(a.0, b.0) {
        order.Eq -> int.compare(a.1, b.1)
        ord -> ord
      }
    })

  // Convert to Pajek format with weights
  list.map(sorted_edges, fn(edge) {
    let #(src, dst, data) = edge
    let weight = options.edge_weight(data)
    #(src, dst, weight)
  })
}

/// Build an edge line in Pajek format.
fn build_edge_line(src: Int, dst: Int, weight: Option(Float)) -> String {
  let base = int.to_string(src) <> " " <> int.to_string(dst)
  case weight {
    Some(w) -> base <> " " <> format_float(w)
    None -> base
  }
}

/// Serializes a graph to Pajek format.
///
/// Convenience function for graphs with String node and edge data.
///
/// ## Example
///
/// ```gleam
/// let pajek_string = pajek.serialize(graph)
/// ```
pub fn serialize(graph: Graph(String, String)) -> String {
  serialize_with(default_options(), graph)
}

/// Converts a graph to a Pajek string.
///
/// Alias for `serialize` for consistency with other modules.
pub fn to_string(graph: Graph(String, String)) -> String {
  serialize(graph)
}

// =============================================================================
// FILE I/O
// =============================================================================

/// Writes a graph to a Pajek file.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = pajek.write("graph.net", graph)
/// ```
pub fn write(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, simplifile.FileError) {
  let content = serialize(graph)
  simplifile.write(path, content)
}

/// Writes a graph to a Pajek file with custom options.
///
/// ## Example
///
/// ```gleam
/// let options = pajek.options_with(
///   node_label: fn(p) { p.name },
///   edge_weight: fn(w) { Some(w) },
///   node_attributes: fn(_) { pajek.default_node_attributes() },
///   include_coordinates: False,
///   include_visuals: False,
/// )
///
/// let assert Ok(Nil) = pajek.write_with("graph.net", options, graph)
/// ```
pub fn write_with(
  path: String,
  options: PajekOptions(n, e),
  graph: Graph(n, e),
) -> Result(Nil, simplifile.FileError) {
  let content = serialize_with(options, graph)
  simplifile.write(path, content)
}

// =============================================================================
// PARSING
// =============================================================================

/// Parses a Pajek string into a graph with custom parsers.
///
/// ## Example
///
/// ```gleam
/// let pajek_string = "*Vertices 2\n1 \"Alice\"\n2 \"Bob\"\n*Arcs\n1 2"
///
/// let result = pajek.parse_with(
///   pajek_string,
///   node_parser: fn(s) { s },
///   edge_parser: fn(_) { "" },
/// )
///
/// case result {
///   Ok(pajek.PajekResult(graph, warnings)) -> {
///     // Use the graph
///     process_graph(graph)
///   }
///   Error(e) -> handle_error(e)
/// }
/// ```
pub fn parse_with(
  input: String,
  node_parser node_parser: fn(String) -> n,
  edge_parser edge_parser: fn(Option(Float)) -> e,
) -> Result(PajekResult(n, e), PajekError) {
  let lines =
    input
    |> string.split("\n")
    |> list.index_map(fn(line, idx) { #(idx + 1, string.trim(line)) })
    |> list.filter(fn(pair) {
      // Filter out empty lines and comments
      let #(_, content) = pair
      content != "" && !string.starts_with(content, "%")
    })

  case lines {
    [] -> Error(EmptyInput)
    _ -> do_parse(lines, node_parser, edge_parser)
  }
}

fn do_parse(
  lines: List(#(Int, String)),
  node_parser: fn(String) -> n,
  edge_parser: fn(Option(Float)) -> e,
) -> Result(PajekResult(n, e), PajekError) {
  // Parse *Vertices section
  case lines {
    [#(line_num, first), ..rest] -> {
      case parse_vertices_header(first) {
        Ok(vertex_count) -> {
          // Parse vertex lines
          case parse_vertices(rest, vertex_count, node_parser, [], []) {
            Ok(#(remaining, nodes, warnings)) -> {
              // Create graph (type determined by *Arcs vs *Edges)
              let gtype = case remaining {
                [#(_, line), ..] -> {
                  case string.lowercase(line) {
                    "*arcs" -> Directed
                    _ -> Undirected
                  }
                }
                _ -> Undirected
              }
              let graph = create_graph_with_nodes(gtype, nodes)

              // Parse edges/arcs
              case parse_edges(remaining, edge_parser, graph, []) {
                Ok(#(final_graph, edge_warnings)) -> {
                  let all_warnings = list.append(warnings, edge_warnings)
                  Ok(PajekResult(graph: final_graph, warnings: all_warnings))
                }
                Error(e) -> Error(e)
              }
            }
            Error(e) -> Error(e)
          }
        }
        Error(_) -> Error(InvalidVerticesLine(line_num, first))
      }
    }
    _ -> Error(MissingVerticesSection)
  }
}

/// Parse the *Vertices line to get vertex count.
fn parse_vertices_header(line: String) -> Result(Int, Nil) {
  let parts = string.split(line, " ")
  case parts {
    ["*Vertices", count_str] | ["*vertices", count_str] -> {
      int.parse(string.trim(count_str))
    }
    _ -> Error(Nil)
  }
}

/// Parse vertex lines.
fn parse_vertices(
  lines: List(#(Int, String)),
  count: Int,
  node_parser: fn(String) -> n,
  acc: List(#(Int, n)),
  warnings: List(#(Int, String)),
) -> Result(
  #(List(#(Int, String)), List(#(Int, n)), List(#(Int, String))),
  PajekError,
) {
  case count {
    0 -> Ok(#(lines, list.reverse(acc), list.reverse(warnings)))
    _ -> {
      case lines {
        [] -> {
          // Calculate expected line number based on how many vertices we've parsed
          let parsed_count = list.length(acc)
          let expected_line = 2 + parsed_count
          // *Vertices is line 1, then vertices start at line 2
          Error(InvalidVertexLine(expected_line, "unexpected end of input"))
        }
        [#(line_num, line), ..rest] -> {
          case parse_vertex_line(line, node_parser) {
            Ok(#(id, data)) -> {
              parse_vertices(
                rest,
                count - 1,
                node_parser,
                [#(id, data), ..acc],
                warnings,
              )
            }
            Error(_) -> {
              // Skip malformed line with warning
              parse_vertices(rest, count - 1, node_parser, acc, [
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

/// Parse a single vertex line: id "label" [x y ...]
fn parse_vertex_line(
  line: String,
  node_parser: fn(String) -> n,
) -> Result(#(Int, n), Nil) {
  let trimmed = string.trim(line)

  // Split only on first space to separate ID from the rest
  case string.split_once(trimmed, " ") {
    Ok(#(id_str, rest)) -> {
      case int.parse(string.trim(id_str)) {
        Ok(id) -> {
          // Extract label from the rest of the line (may contain spaces)
          let label = extract_quoted_string_from_line(string.trim(rest))
          let data = node_parser(label)
          Ok(#(id, data))
        }
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

/// Extract a quoted string from a line, handling multi-word labels.
fn extract_quoted_string_from_line(s: String) -> String {
  let trimmed = string.trim(s)

  // Find the first quote
  case string.split_once(trimmed, "\"") {
    Ok(#(_, after_first_quote)) -> {
      // Find the closing quote
      case string.split_once(after_first_quote, "\"") {
        Ok(#(label, _)) -> label
        Error(_) -> trimmed
        // No closing quote, return as-is
      }
    }
    Error(_) -> trimmed
    // No quotes at all, return as-is
  }
}

/// Create a graph with the parsed nodes.
fn create_graph_with_nodes(
  gtype: GraphType,
  nodes: List(#(Int, n)),
) -> Graph(n, e) {
  list.fold(nodes, model.new(gtype), fn(graph, pair) {
    let #(id, data) = pair
    model.add_node(graph, id, data)
  })
}

/// Parse *Arcs or *Edges section.
fn parse_edges(
  lines: List(#(Int, String)),
  edge_parser: fn(Option(Float)) -> e,
  graph: Graph(n, e),
  warnings: List(#(Int, String)),
) -> Result(#(Graph(n, e), List(#(Int, String))), PajekError) {
  case lines {
    [] -> Ok(#(graph, list.reverse(warnings)))
    [#(line_num, section), ..rest] -> {
      case string.lowercase(section) {
        "*arcs" | "*edges" -> do_parse_edges(rest, edge_parser, graph, [])
        _ -> {
          // Unknown section, skip
          parse_edges(rest, edge_parser, graph, [
            #(line_num, section),
            ..warnings
          ])
        }
      }
    }
  }
}

fn do_parse_edges(
  lines: List(#(Int, String)),
  edge_parser: fn(Option(Float)) -> e,
  graph: Graph(n, e),
  warnings: List(#(Int, String)),
) -> Result(#(Graph(n, e), List(#(Int, String))), PajekError) {
  case lines {
    [] -> Ok(#(graph, list.reverse(warnings)))
    [#(line_num, line), ..rest] -> {
      // Check if this is a new section
      case string.starts_with(string.lowercase(line), "*") {
        True -> {
          // New section, stop parsing edges
          Ok(#(graph, list.reverse(warnings)))
        }
        False -> {
          case parse_edge_line(line, edge_parser) {
            Ok(#(src, dst, data)) -> {
              // Add edge to graph (ensure nodes exist)
              let graph_with_nodes = ensure_nodes_exist(graph, src, dst)
              case
                model.add_edge(graph_with_nodes, from: src, to: dst, with: data)
              {
                Ok(new_graph) ->
                  do_parse_edges(rest, edge_parser, new_graph, warnings)
                Error(_) -> {
                  // Edge couldn't be added, skip with warning
                  do_parse_edges(rest, edge_parser, graph_with_nodes, [
                    #(line_num, line),
                    ..warnings
                  ])
                }
              }
            }
            Error(_) -> {
              // Skip malformed line with warning
              do_parse_edges(rest, edge_parser, graph, [
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

/// Parse an edge/arc line: source target [weight]
fn parse_edge_line(
  line: String,
  edge_parser: fn(Option(Float)) -> e,
) -> Result(#(Int, Int, e), Nil) {
  let parts =
    line
    |> string.split(" ")
    |> list.filter(fn(s) { string.trim(s) != "" })

  case parts {
    [src_str, dst_str, ..rest] -> {
      case int.parse(src_str), int.parse(dst_str) {
        Ok(src), Ok(dst) -> {
          // Parse optional weight
          let weight = case rest {
            [weight_str, ..] -> {
              case float.parse(weight_str) {
                Ok(w) -> Some(w)
                Error(_) -> None
              }
            }
            _ -> None
          }
          let data = edge_parser(weight)
          Ok(#(src, dst, data))
        }
        _, _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

/// Ensure both source and target nodes exist in the graph.
/// For Pajek, nodes should always exist from the *Vertices section,
/// so this is a safety measure that should not be needed for well-formed files.
fn ensure_nodes_exist(
  graph: Graph(n, e),
  _src: NodeId,
  _tgt: NodeId,
) -> Graph(n, e) {
  // Nodes should already exist from *Vertices section
  // This function is a placeholder for type compatibility
  graph
}

/// Parses a Pajek string into a graph with String labels.
///
/// Convenience function for the common case where both node and edge data
/// are just Strings.
///
/// ## Example
///
/// ```gleam
/// let pajek_string = "*Vertices 2\n1 \"Alice\"\n2 \"Bob\"\n*Arcs\n1 2"
///
/// case pajek.parse(pajek_string) {
///   Ok(result) -> {
///     // result.graph is Graph(String, String)
///     process_graph(result.graph)
///   }
///   Error(e) -> handle_error(e)
/// }
/// ```
pub fn parse(input: String) -> Result(PajekResult(String, String), PajekError) {
  parse_with(input, node_parser: fn(s) { s }, edge_parser: fn(_) { "" })
}

// =============================================================================
// FILE READING
// =============================================================================

/// Reads a graph from a Pajek file.
///
/// Convenience function that reads node and edge data as strings.
///
/// ## Example
///
/// ```gleam
/// let result = pajek.read("graph.net")
///
/// case result {
///   Ok(pajek.PajekResult(graph, warnings)) -> {
///     // Use the graph
///     process_graph(graph)
///   }
///   Error(e) -> handle_error(e)
/// }
/// ```
pub fn read(path: String) -> Result(PajekResult(String, String), PajekError) {
  case simplifile.read(path) {
    Ok(content) -> parse(content)
    Error(e) -> Error(ReadError(path, simplifile.describe_error(e)))
  }
}

/// Reads a graph from a Pajek file with custom parsers.
///
/// ## Example
///
/// ```gleam
/// let result = pajek.read_with(
///   "graph.net",
///   node_parser: fn(s) { Person(s, 0.0, 0.0) },
///   edge_parser: fn(w) { case w { Some(val) -> val None -> 0.0 } },
/// )
/// ```
pub fn read_with(
  path: String,
  node_parser node_parser: fn(String) -> n,
  edge_parser edge_parser: fn(Option(Float)) -> e,
) -> Result(PajekResult(n, e), PajekError) {
  case simplifile.read(path) {
    Ok(content) -> parse_with(content, node_parser:, edge_parser:)
    Error(e) -> Error(ReadError(path, simplifile.describe_error(e)))
  }
}
