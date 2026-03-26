//// JSON format for graph data exchange.
////
//// This module provides comprehensive JSON I/O capabilities for graph data,
//// supporting multiple formats used by popular visualization libraries.
////
//// ## Features
////
//// - **Generic types** for nodes and edges
//// - **Reading and Writing** support for Generic format
//// - **Multiple JSON export formats** (D3.js, Cytoscape.js, vis.js, etc.)
//// - **File operations** (read/write JSON files directly)
//// - **Rich metadata** support (graph properties, rendering hints)
//// - **Format validation** and error reporting
////
//// ## Quick Start
////
//// ```gleam
//// import yog_io/json
//// import yog/model
////
//// pub fn main() {
////   let graph =
////     model.new(model.Directed)
////     |> model.add_node(1, "Alice")
////     |> model.add_node(2, "Bob")
////     |> model.add_edge(from: 1, to: 2, with: "follows")
////
////   // Export to file (simple)
////   let assert Ok(_) = json.write("graph.json", graph)
////
////   // Or with custom options
////   let assert Ok(_) = json.to_json_file(
////     graph,
////     "graph.json",
////     json.default_export_options(),
////   )
//// }
//// ```
////
//// ## Format Support
////
//// - **Generic**: Full metadata with type preservation
//// - **D3Force**: D3.js force-directed graphs
//// - **Cytoscape**: Cytoscape.js network visualization
//// - **VisJs**: vis.js network format
//// - **NetworkX**: Python NetworkX compatibility
////
//// ## References
////
//// - [JSON Specification](https://www.json.org/)
//// - [D3.js](https://d3js.org/)
//// - [Cytoscape.js](https://js.cytoscape.org/)
//// - [vis.js](https://visjs.github.io/vis-network/)

import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/function
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import yog/model.{type Graph, Directed, Undirected}
import yog/multi/model as multi

/// Format presets for popular graph visualization libraries
pub type JsonFormat {
  /// Generic format with full metadata
  Generic
  /// D3.js force-directed graph format
  D3Force
  /// Cytoscape.js elements format
  Cytoscape
  /// vis.js network format
  VisJs
  /// NetworkX node-link format (Python compatibility)
  NetworkX
}

/// Options for JSON export
pub type JsonExportOptions(n, e) {
  JsonExportOptions(
    /// Output format (default: Generic)
    format: JsonFormat,
    /// Include graph metadata (default: True)
    include_metadata: Bool,
    /// Custom node data serializer
    node_serializer: Option(fn(n) -> json.Json),
    /// Custom edge data serializer
    edge_serializer: Option(fn(e) -> json.Json),
    /// Pretty print output (default: True)
    pretty: Bool,
    /// Custom metadata fields
    metadata: Option(Dict(String, json.Json)),
  )
}

/// Errors that can occur during JSON operations
pub type JsonError {
  /// File not found
  FileNotFound(path: String)
  /// Invalid JSON syntax
  InvalidJson(error: String)
  /// File write error
  WriteError(path: String, error: String)
  /// File read error
  ReadError(path: String, error: String)
  /// Unsupported format
  UnsupportedFormat(format: String)
}

/// Creates default export options for String node and edge data.
///
/// ## Default Settings
///
/// - Format: Generic
/// - Include metadata: True
/// - Pretty print: True
/// - Node serializer: Converts strings to JSON strings
/// - Edge serializer: Converts strings to JSON strings
///
/// ## Example
///
/// ```gleam
/// let options = json.default_export_options()
/// json.to_json(graph, options)
/// ```
pub fn default_export_options() -> JsonExportOptions(String, String) {
  JsonExportOptions(
    format: Generic,
    include_metadata: True,
    node_serializer: Some(json.string),
    edge_serializer: Some(json.string),
    pretty: True,
    metadata: None,
  )
}

/// Creates export options with custom serializers for generic types.
///
/// Use this when your graph contains custom data types that need
/// special conversion to JSON.
///
/// ## Example
///
/// ```gleam
/// pub type Person {
///   Person(name: String, age: Int)
/// }
///
/// let options = json.export_options_with(
///   node_serializer: fn(person) {
///     json.object([
///       #("name", json.string(person.name)),
///       #("age", json.int(person.age)),
///     ])
///   },
///   edge_serializer: fn(weight) { json.int(weight) },
/// )
/// ```
pub fn export_options_with(
  node_serializer: fn(n) -> json.Json,
  edge_serializer: fn(e) -> json.Json,
) -> JsonExportOptions(n, e) {
  JsonExportOptions(
    format: Generic,
    include_metadata: True,
    node_serializer: Some(node_serializer),
    edge_serializer: Some(edge_serializer),
    pretty: True,
    metadata: None,
  )
}

/// Converts a graph to a JSON string.
///
/// This function serializes a graph to JSON format according to the
/// specified options and format preset.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import yog/model
/// import yog_io/json
///
/// pub fn main() {
///   let graph =
///     model.new(model.Directed)
///     |> model.add_node(1, "Alice")
///     |> model.add_node(2, "Bob")
///     |> model.add_edge(from: 1, to: 2, with: "follows")
///
///   let json_string = json.to_json(graph, json.default_export_options())
///   // Returns JSON string representation
/// }
/// ```
pub fn to_json(graph: Graph(n, e), options: JsonExportOptions(n, e)) -> String {
  let json_obj = case options.format {
    Generic -> to_generic_format(graph, options)
    D3Force -> to_d3_force_format(graph, options)
    Cytoscape -> to_cytoscape_format(graph, options)
    VisJs -> to_visjs_format(graph, options)
    NetworkX -> to_networkx_format(graph, options)
  }

  case options.pretty {
    True -> pretty_print_json(json.to_string(json_obj))
    False -> json.to_string(json_obj)
  }
}

/// Exports a graph to a JSON file.
///
/// This function writes the graph to a file in the specified JSON format.
/// The file will be created if it doesn't exist, or overwritten if it does.
///
/// ## Example
///
/// ```gleam
/// case json.to_json_file(graph, "output.json", json.default_export_options()) {
///   Ok(_) -> io.println("Graph saved successfully")
///   Error(json.WriteError(path, error)) -> {
///     io.println("Failed to write to " <> path <> ": " <> error)
///   }
///   Error(_) -> io.println("Unknown error")
/// }
/// ```
pub fn to_json_file(
  graph: Graph(n, e),
  path: String,
  options: JsonExportOptions(n, e),
) -> Result(Nil, JsonError) {
  let json_string = to_json(graph, options)

  simplifile.write(to: path, contents: json_string)
  |> result.map_error(fn(error) { WriteError(path, string.inspect(error)) })
}

/// Quick export for D3.js force-directed graphs with default settings.
///
/// This is a convenience function that exports graphs in D3.js format
/// with sensible defaults.
///
/// ## Example
///
/// ```gleam
/// let d3_json = json.to_d3_json(graph, json.string, json.string)
/// ```
pub fn to_d3_json(
  graph: Graph(n, e),
  node_serializer: fn(n) -> json.Json,
  edge_serializer: fn(e) -> json.Json,
) -> String {
  let options =
    JsonExportOptions(
      format: D3Force,
      include_metadata: False,
      node_serializer: Some(node_serializer),
      edge_serializer: Some(edge_serializer),
      pretty: True,
      metadata: None,
    )
  to_json(graph, options)
}

/// Quick export for Cytoscape.js with default settings.
pub fn to_cytoscape_json(
  graph: Graph(n, e),
  node_serializer: fn(n) -> json.Json,
  edge_serializer: fn(e) -> json.Json,
) -> String {
  let options =
    JsonExportOptions(
      format: Cytoscape,
      include_metadata: False,
      node_serializer: Some(node_serializer),
      edge_serializer: Some(edge_serializer),
      pretty: True,
      metadata: None,
    )
  to_json(graph, options)
}

/// Quick export for vis.js networks with default settings.
pub fn to_visjs_json(
  graph: Graph(n, e),
  node_serializer: fn(n) -> json.Json,
  edge_serializer: fn(e) -> json.Json,
) -> String {
  let options =
    JsonExportOptions(
      format: VisJs,
      include_metadata: False,
      node_serializer: Some(node_serializer),
      edge_serializer: Some(edge_serializer),
      pretty: True,
      metadata: None,
    )
  to_json(graph, options)
}

/// Writes a graph to a JSON file using default export options.
///
/// This is a convenience function for String-based graphs that uses default
/// JSON export options. For more control over the output format, use
/// `to_json_file()` or `write_with()`.
///
/// ## Example
///
/// ```gleam
/// import yog/model
/// import yog_io/json
///
/// let graph =
///   model.new(model.Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///   |> model.add_edge(from: 1, to: 2, with: "follows")
///
/// let assert Ok(Nil) = json.write("graph.json", graph)
/// ```
pub fn write(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, JsonError) {
  to_json_file(graph, path, default_export_options())
}

/// Writes a graph to a JSON file with custom export options.
///
/// This function provides full control over the JSON export format and
/// serialization behavior.
///
/// ## Example
///
/// ```gleam
/// import gleam/json as gleam_json
/// import yog_io/json
///
/// pub type Person {
///   Person(name: String, age: Int)
/// }
///
/// let options = json.export_options_with(
///   node_serializer: fn(person) {
///     gleam_json.object([
///       #("name", gleam_json.string(person.name)),
///       #("age", gleam_json.int(person.age)),
///     ])
///   },
///   edge_serializer: fn(weight) { gleam_json.int(weight) },
/// )
///
/// let assert Ok(Nil) = json.write_with("graph.json", options, graph)
/// ```
pub fn write_with(
  path: String,
  options: JsonExportOptions(n, e),
  graph: Graph(n, e),
) -> Result(Nil, JsonError) {
  to_json_file(graph, path, options)
}

// =============================================================================
// READING / DESERIALIZATION
// =============================================================================

/// Reads a graph from a JSON file using default options.
///
/// This currently supports only the `Generic` format (`yog-generic`).
pub fn read(path: String) -> Result(Graph(String, String), JsonError) {
  simplifile.read(path)
  |> result.map_error(fn(err) { ReadError(path, string.inspect(err)) })
  |> result.try(from_json)
}

/// Reads a multigraph from a JSON file using default options.
pub fn read_multi(
  path: String,
) -> Result(multi.MultiGraph(String, String), JsonError) {
  simplifile.read(path)
  |> result.map_error(fn(err) { ReadError(path, string.inspect(err)) })
  |> result.try(from_json_multi)
}

/// Reads a graph from a JSON file with custom data decoders.
pub fn read_with(
  path: String,
  node_decoder: decode.Decoder(n),
  edge_decoder: decode.Decoder(e),
) -> Result(Graph(n, e), JsonError) {
  simplifile.read(path)
  |> result.map_error(fn(err) { ReadError(path, string.inspect(err)) })
  |> result.try(fn(s) { from_json_with(s, node_decoder, edge_decoder) })
}

/// Reads a multigraph from a JSON file with custom data decoders.
pub fn read_multi_with(
  path: String,
  node_decoder: decode.Decoder(n),
  edge_decoder: decode.Decoder(e),
) -> Result(multi.MultiGraph(n, e), JsonError) {
  simplifile.read(path)
  |> result.map_error(fn(err) { ReadError(path, string.inspect(err)) })
  |> result.try(fn(s) { from_json_multi_with(s, node_decoder, edge_decoder) })
}

/// Parses a graph from a JSON string representation.
pub fn from_json(
  json_string: String,
) -> Result(Graph(String, String), JsonError) {
  from_json_with(json_string, decode.string, decode.string)
}

/// Parses a multigraph from a JSON string representation.
pub fn from_json_multi(
  json_string: String,
) -> Result(multi.MultiGraph(String, String), JsonError) {
  from_json_multi_with(json_string, decode.string, decode.string)
}

/// Parses a graph from a JSON string with custom data decoders.
///
/// This function supports the standard `yog-generic` JSON format.
pub fn from_json_with(
  json_string: String,
  node_data_decoder: decode.Decoder(n),
  edge_data_decoder: decode.Decoder(e),
) -> Result(Graph(n, e), JsonError) {
  let main_decoder = {
    use format <- decode.field("format", decode.string)
    case format {
      "yog-generic" -> {
        use meta <- decode.field("metadata", build_metadata_decoder())
        use nodes <- decode.field(
          "nodes",
          decode.list(decode_node(node_data_decoder)),
        )
        use edges <- decode.field(
          "edges",
          decode.list(decode_edge(edge_data_decoder)),
        )
        decode.success(#(meta, nodes, edges))
      }
      fmt -> decode.failure(#(GenericMetadata("", False), [], []), fmt)
    }
  }

  json.parse(from: json_string, using: main_decoder)
  |> result.map_error(fn(err) { InvalidJson(string.inspect(err)) })
  |> result.try(fn(data) {
    let #(meta, nodes, edges) = data
    let kind = case meta.graph_type {
      "undirected" -> Undirected
      _ -> Directed
    }

    let graph =
      list.fold(nodes, model.new(kind), fn(g, n) {
        model.add_node(g, n.id, n.data)
      })

    list.try_fold(edges, graph, fn(g, e) {
      model.add_edge(g, from: e.source, to: e.target, with: e.data)
      |> result.map_error(fn(err) {
        InvalidJson("Edge creation error: " <> err)
      })
    })
  })
}

/// Parses a multigraph from a JSON string with custom data decoders.
///
/// This function supports the standard `yog-generic` JSON format.
pub fn from_json_multi_with(
  json_string: String,
  node_data_decoder: decode.Decoder(n),
  edge_data_decoder: decode.Decoder(e),
) -> Result(multi.MultiGraph(n, e), JsonError) {
  let main_decoder = {
    use format <- decode.field("format", decode.string)
    case format {
      "yog-generic" -> {
        use meta <- decode.field("metadata", build_metadata_decoder())
        use nodes <- decode.field(
          "nodes",
          decode.list(decode_node(node_data_decoder)),
        )
        use edges <- decode.field(
          "edges",
          decode.list(decode_edge(edge_data_decoder)),
        )
        decode.success(#(meta, nodes, edges))
      }
      fmt -> decode.failure(#(GenericMetadata("", False), [], []), fmt)
    }
  }

  json.parse(from: json_string, using: main_decoder)
  |> result.map_error(fn(err) { InvalidJson(string.inspect(err)) })
  |> result.try(fn(data) {
    let #(meta, nodes, edges) = data
    let kind = case meta.graph_type {
      "undirected" -> Undirected
      _ -> Directed
    }

    let graph =
      list.fold(nodes, multi.new(kind), fn(g, n) {
        multi.add_node(g, n.id, n.data)
      })

    let #(final_graph, _) =
      list.fold(edges, #(graph, 0), fn(acc, e) {
        let #(g, next_id) = acc
        let #(new_g, _) =
          multi.add_edge(g, from: e.source, to: e.target, with: e.data)
        #(new_g, next_id + 1)
      })
    Ok(final_graph)
  })
}

// ===== Internal Format Converters =====

fn to_generic_format(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> json.Json {
  let nodes_json = serialize_nodes_generic(graph, options)
  let edges_json = serialize_edges_generic(graph, options)

  let base_object = [
    #("format", json.string("yog-generic")),
    #("version", json.string("2.0")),
    #("nodes", json.array(nodes_json, of: function.identity)),
    #("edges", json.array(edges_json, of: function.identity)),
  ]

  let with_metadata = case options.include_metadata {
    True -> {
      let metadata = build_metadata(graph, options)
      [#("metadata", metadata), ..base_object]
    }
    False -> base_object
  }

  json.object(with_metadata)
}

fn to_d3_force_format(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> json.Json {
  let nodes_json = serialize_nodes_d3(graph, options)
  let edges_json = serialize_edges_d3(graph, options)

  json.object([
    #("nodes", json.array(nodes_json, of: function.identity)),
    #("links", json.array(edges_json, of: function.identity)),
  ])
}

fn to_cytoscape_format(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> json.Json {
  let nodes_json = serialize_nodes_cytoscape(graph, options)
  let edges_json = serialize_edges_cytoscape(graph, options)

  json.object([
    #(
      "elements",
      json.object([
        #("nodes", json.array(nodes_json, of: function.identity)),
        #("edges", json.array(edges_json, of: function.identity)),
      ]),
    ),
  ])
}

fn to_visjs_format(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> json.Json {
  let nodes_json = serialize_nodes_visjs(graph, options)
  let edges_json = serialize_edges_visjs(graph, options)

  json.object([
    #("nodes", json.array(nodes_json, of: function.identity)),
    #("edges", json.array(edges_json, of: function.identity)),
  ])
}

fn to_networkx_format(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> json.Json {
  let nodes_json = serialize_nodes_networkx(graph, options)
  let edges_json = serialize_edges_networkx(graph, options)

  let directed = case graph.kind {
    Directed -> True
    Undirected -> False
  }

  json.object([
    #("directed", json.bool(directed)),
    #("multigraph", json.bool(False)),
    #("graph", json.object([])),
    #("nodes", json.array(nodes_json, of: function.identity)),
    #("links", json.array(edges_json, of: function.identity)),
  ])
}

// ===== Node Serialization Functions =====

fn serialize_nodes_generic(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.nodes, [], fn(acc, id, data) {
    let data_json = case options.node_serializer {
      Some(serializer) -> serializer(data)
      None -> json.null()
    }

    let node_obj = json.object([#("id", json.int(id)), #("data", data_json)])

    [node_obj, ..acc]
  })
}

fn serialize_nodes_d3(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.nodes, [], fn(acc, id, data) {
    let id_str = int.to_string(id)

    let base = [#("id", json.string(id_str))]

    let with_data = case options.node_serializer {
      Some(serializer) -> {
        // Try to merge data if it's an object, otherwise use as label
        [#("data", serializer(data)), ..base]
      }
      None -> base
    }

    [json.object(with_data), ..acc]
  })
}

fn serialize_nodes_cytoscape(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.nodes, [], fn(acc, id, data) {
    let data_fields = [#("id", json.string(int.to_string(id)))]

    let data_obj = case options.node_serializer {
      Some(serializer) -> {
        json.object([#("label", serializer(data)), ..data_fields])
      }
      None -> json.object(data_fields)
    }

    let node_obj = json.object([#("data", data_obj)])

    [node_obj, ..acc]
  })
}

fn serialize_nodes_visjs(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.nodes, [], fn(acc, id, data) {
    let base = [#("id", json.int(id))]

    let with_label = case options.node_serializer {
      Some(serializer) -> [#("label", serializer(data)), ..base]
      None -> base
    }

    [json.object(with_label), ..acc]
  })
}

fn serialize_nodes_networkx(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.nodes, [], fn(acc, id, data) {
    let base = [#("id", json.int(id))]

    let with_data = case options.node_serializer {
      Some(serializer) -> [#("data", serializer(data)), ..base]
      None -> base
    }

    [json.object(with_data), ..acc]
  })
}

// ===== Edge Serialization Functions =====

fn serialize_edges_generic(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.out_edges, [], fn(acc, from_id, targets) {
    let inner_edges =
      dict.fold(targets, [], fn(inner_acc, to_id, edge_data) {
        case graph.kind {
          Undirected if from_id > to_id -> inner_acc
          _ -> {
            let data_json = case options.edge_serializer {
              Some(serializer) -> serializer(edge_data)
              None -> json.null()
            }

            let edge_obj =
              json.object([
                #("source", json.int(from_id)),
                #("target", json.int(to_id)),
                #("data", data_json),
              ])

            [edge_obj, ..inner_acc]
          }
        }
      })
    list.flatten([inner_edges, acc])
  })
}

fn serialize_edges_d3(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.out_edges, [], fn(acc, from_id, targets) {
    let inner_edges =
      dict.fold(targets, [], fn(inner_acc, to_id, edge_data) {
        case graph.kind {
          Undirected if from_id > to_id -> inner_acc
          _ -> {
            let base = [
              #("source", json.string(int.to_string(from_id))),
              #("target", json.string(int.to_string(to_id))),
            ]

            let with_data = case options.edge_serializer {
              Some(serializer) -> [#("value", serializer(edge_data)), ..base]
              None -> base
            }

            [json.object(with_data), ..inner_acc]
          }
        }
      })
    list.flatten([inner_edges, acc])
  })
}

fn serialize_edges_cytoscape(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.out_edges, [], fn(acc, from_id, targets) {
    let inner_edges =
      dict.fold(targets, [], fn(inner_acc, to_id, edge_data) {
        case graph.kind {
          Undirected if from_id > to_id -> inner_acc
          _ -> {
            let edge_id =
              "e" <> int.to_string(from_id) <> "_" <> int.to_string(to_id)

            let data_fields = [
              #("id", json.string(edge_id)),
              #("source", json.string(int.to_string(from_id))),
              #("target", json.string(int.to_string(to_id))),
            ]

            let data_obj = case options.edge_serializer {
              Some(serializer) -> {
                json.object([#("weight", serializer(edge_data)), ..data_fields])
              }
              None -> json.object(data_fields)
            }

            let edge_obj = json.object([#("data", data_obj)])

            [edge_obj, ..inner_acc]
          }
        }
      })
    list.flatten([inner_edges, acc])
  })
}

fn serialize_edges_visjs(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.out_edges, [], fn(acc, from_id, targets) {
    let inner_edges =
      dict.fold(targets, [], fn(inner_acc, to_id, edge_data) {
        case graph.kind {
          Undirected if from_id > to_id -> inner_acc
          _ -> {
            let base = [
              #("from", json.int(from_id)),
              #("to", json.int(to_id)),
            ]

            let with_data = case options.edge_serializer {
              Some(serializer) -> [#("label", serializer(edge_data)), ..base]
              None -> base
            }

            [json.object(with_data), ..inner_acc]
          }
        }
      })
    list.flatten([inner_edges, acc])
  })
}

fn serialize_edges_networkx(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.out_edges, [], fn(acc, from_id, targets) {
    let inner_edges =
      dict.fold(targets, [], fn(inner_acc, to_id, edge_data) {
        case graph.kind {
          Undirected if from_id > to_id -> inner_acc
          _ -> {
            let base = [
              #("source", json.int(from_id)),
              #("target", json.int(to_id)),
            ]

            let with_data = case options.edge_serializer {
              Some(serializer) -> [#("weight", serializer(edge_data)), ..base]
              None -> base
            }

            [json.object(with_data), ..inner_acc]
          }
        }
      })
    list.flatten([inner_edges, acc])
  })
}

// ===== Metadata =====

fn build_metadata(
  graph: Graph(n, e),
  options: JsonExportOptions(n, e),
) -> json.Json {
  let graph_type = case graph.kind {
    Directed -> "directed"
    Undirected -> "undirected"
  }

  let base_metadata = [
    #("graph_type", json.string(graph_type)),
    #("node_count", json.int(dict.size(graph.nodes))),
    #("edge_count", json.int(count_edges(graph))),
  ]

  let with_custom = case options.metadata {
    Some(custom_metadata) -> {
      let custom_list =
        dict.to_list(custom_metadata)
        |> list.map(fn(pair) {
          let #(key, value) = pair
          #(key, value)
        })
      list.append(base_metadata, custom_list)
    }
    None -> base_metadata
  }

  json.object(with_custom)
}

fn count_edges(graph: Graph(n, e)) -> Int {
  dict.fold(graph.out_edges, 0, fn(acc, _from_id, targets) {
    acc + dict.size(targets)
  })
  / case graph.kind {
    Undirected -> 2
    Directed -> 1
  }
}

/// Converts a JsonError to a human-readable string.
///
/// ## Example
///
/// ```gleam
/// case json.to_json_file(graph, "output.json", options) {
///   Ok(_) -> "Success!"
///   Error(e) -> json.error_to_string(e)
/// }
/// ```
pub fn error_to_string(error: JsonError) -> String {
  case error {
    FileNotFound(path) -> "File not found: " <> path
    InvalidJson(msg) -> "Invalid JSON: " <> msg
    WriteError(path, msg) -> "Write error at " <> path <> ": " <> msg
    ReadError(path, msg) -> "Read error at " <> path <> ": " <> msg
    UnsupportedFormat(fmt) -> "Unsupported format: " <> fmt
  }
}

// =============================================================================
// JSON PRETTY PRINTER
// =============================================================================

/// Simple JSON pretty printer that adds indentation and newlines.
fn pretty_print_json(json_str: String) -> String {
  let chars = string.to_graphemes(json_str)
  let result = pretty_print_loop(chars, 0, [], [], False)
  string.concat(list.reverse(result))
}

fn pretty_print_loop(
  chars: List(String),
  indent: Int,
  acc: List(String),
  indent_stack: List(String),
  in_string: Bool,
) -> List(String) {
  case chars {
    [] -> acc
    [char, ..rest] -> {
      case in_string {
        True -> {
          case char {
            "\"" -> {
              // Check if escaped
              case acc {
                ["\\", ..] ->
                  pretty_print_loop(
                    rest,
                    indent,
                    [char, ..acc],
                    indent_stack,
                    True,
                  )
                _ ->
                  pretty_print_loop(
                    rest,
                    indent,
                    [char, ..acc],
                    indent_stack,
                    False,
                  )
              }
            }
            _ ->
              pretty_print_loop(rest, indent, [char, ..acc], indent_stack, True)
          }
        }
        False -> {
          case char {
            "{" | "[" -> {
              let new_indent = indent + 2
              let indent_str = string.repeat(" ", new_indent)
              let new_acc = case acc {
                [] -> [char]
                _ -> [indent_str, "\n", char, ..acc]
              }
              pretty_print_loop(
                rest,
                new_indent,
                new_acc,
                [indent_str, ..indent_stack],
                False,
              )
            }
            "}" | "]" -> {
              let new_indent = int.max(0, indent - 2)
              let new_stack = case indent_stack {
                [_, ..st] -> st
                [] -> []
              }
              let current_indent = case new_stack {
                [s, ..] -> s
                [] -> ""
              }
              let new_acc = [current_indent, "\n", char, ..acc]
              pretty_print_loop(rest, new_indent, new_acc, new_stack, False)
            }
            "," -> {
              let current_indent = case indent_stack {
                [s, ..] -> s
                [] -> ""
              }
              let new_acc = [current_indent, "\n", char, ..acc]
              pretty_print_loop(rest, indent, new_acc, indent_stack, False)
            }
            ":" -> {
              // Don't add space after colon to maintain backward compatibility
              pretty_print_loop(
                rest,
                indent,
                [char, ..acc],
                indent_stack,
                False,
              )
            }
            " " | "\n" | "\t" -> {
              // Skip whitespace outside strings
              pretty_print_loop(rest, indent, acc, indent_stack, False)
            }
            "\"" -> {
              pretty_print_loop(rest, indent, [char, ..acc], indent_stack, True)
            }
            _ -> {
              pretty_print_loop(
                rest,
                indent,
                [char, ..acc],
                indent_stack,
                False,
              )
            }
          }
        }
      }
    }
  }
}

// =============================================================================
// MULTIGRAPH EXPORT SUPPORT
// =============================================================================

/// Converts a multigraph to a JSON string.
///
/// This function serializes a multigraph to JSON format with edge IDs
/// to preserve parallel edges. All formats include unique edge identifiers.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import yog/multi/model as multi
/// import yog_io/json
///
/// pub fn main() {
///   let graph =
///     multi.new(multi.Directed)
///     |> multi.add_node(1, "Alice")
///     |> multi.add_node(2, "Bob")
///     |> multi.add_edge(from: 1, to: 2, with: "follows")
///     |> multi.add_edge(from: 1, to: 2, with: "mentions")
///
///   let json_string = json.to_json_multi(graph, json.default_export_options())
///   // Returns JSON with edge IDs for parallel edges
/// }
/// ```
pub fn to_json_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> String {
  let json_obj = case options.format {
    Generic -> to_generic_format_multi(graph, options)
    D3Force -> to_d3_force_format_multi(graph, options)
    Cytoscape -> to_cytoscape_format_multi(graph, options)
    VisJs -> to_visjs_format_multi(graph, options)
    NetworkX -> to_networkx_format_multi(graph, options)
  }

  case options.pretty {
    True -> pretty_print_json(json.to_string(json_obj))
    False -> json.to_string(json_obj)
  }
}

/// Exports a multigraph to a JSON file.
///
/// This function writes the multigraph to a file in the specified JSON format.
/// The file will be created if it doesn't exist, or overwritten if it does.
///
/// ## Example
///
/// ```gleam
/// case json.to_json_file_multi(graph, "output.json", json.default_export_options()) {
///   Ok(_) -> io.println("Multigraph saved successfully")
///   Error(json.WriteError(path, error)) -> {
///     io.println("Failed to write to " <> path <> ": " <> error)
///   }
///   Error(_) -> io.println("Unknown error")
/// }
/// ```
pub fn to_json_file_multi(
  graph: multi.MultiGraph(n, e),
  path: String,
  options: JsonExportOptions(n, e),
) -> Result(Nil, JsonError) {
  let json_string = to_json_multi(graph, options)

  simplifile.write(to: path, contents: json_string)
  |> result.map_error(fn(error) { WriteError(path, string.inspect(error)) })
}

// ===== MultiGraph Format Converters =====

fn to_generic_format_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> json.Json {
  let nodes_json = serialize_nodes_generic_multi(graph, options)
  let edges_json = serialize_edges_generic_multi(graph, options)

  let base_object = [
    #("format", json.string("yog-generic")),
    #("version", json.string("2.0")),
    #("nodes", json.array(nodes_json, of: function.identity)),
    #("edges", json.array(edges_json, of: function.identity)),
  ]

  let with_metadata = case options.include_metadata {
    True -> {
      let metadata = build_metadata_multi(graph, options)
      [#("metadata", metadata), ..base_object]
    }
    False -> base_object
  }

  json.object(with_metadata)
}

fn to_d3_force_format_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> json.Json {
  let nodes_json = serialize_nodes_d3_multi(graph, options)
  let edges_json = serialize_edges_d3_multi(graph, options)

  json.object([
    #("nodes", json.array(nodes_json, of: function.identity)),
    #("links", json.array(edges_json, of: function.identity)),
  ])
}

fn to_cytoscape_format_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> json.Json {
  let nodes_json = serialize_nodes_cytoscape_multi(graph, options)
  let edges_json = serialize_edges_cytoscape_multi(graph, options)

  json.object([
    #(
      "elements",
      json.object([
        #("nodes", json.array(nodes_json, of: function.identity)),
        #("edges", json.array(edges_json, of: function.identity)),
      ]),
    ),
  ])
}

fn to_visjs_format_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> json.Json {
  let nodes_json = serialize_nodes_visjs_multi(graph, options)
  let edges_json = serialize_edges_visjs_multi(graph, options)

  json.object([
    #("nodes", json.array(nodes_json, of: function.identity)),
    #("edges", json.array(edges_json, of: function.identity)),
  ])
}

fn to_networkx_format_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> json.Json {
  let nodes_json = serialize_nodes_networkx_multi(graph, options)
  let edges_json = serialize_edges_networkx_multi(graph, options)

  let directed = case graph.kind {
    Directed -> True
    Undirected -> False
  }

  json.object([
    #("directed", json.bool(directed)),
    #("multigraph", json.bool(True)),
    #("graph", json.object([])),
    #("nodes", json.array(nodes_json, of: function.identity)),
    #("links", json.array(edges_json, of: function.identity)),
  ])
}

// ===== MultiGraph Node Serialization Functions =====

fn serialize_nodes_generic_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.nodes, [], fn(acc, id, data) {
    let data_json = case options.node_serializer {
      Some(serializer) -> serializer(data)
      None -> json.null()
    }

    let node_obj = json.object([#("id", json.int(id)), #("data", data_json)])

    [node_obj, ..acc]
  })
}

fn serialize_nodes_d3_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.nodes, [], fn(acc, id, data) {
    let id_str = int.to_string(id)

    let base = [#("id", json.string(id_str))]

    let with_data = case options.node_serializer {
      Some(serializer) -> {
        [#("data", serializer(data)), ..base]
      }
      None -> base
    }

    [json.object(with_data), ..acc]
  })
}

fn serialize_nodes_cytoscape_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.nodes, [], fn(acc, id, data) {
    let data_fields = [#("id", json.string(int.to_string(id)))]

    let data_obj = case options.node_serializer {
      Some(serializer) -> {
        json.object([#("label", serializer(data)), ..data_fields])
      }
      None -> json.object(data_fields)
    }

    let node_obj = json.object([#("data", data_obj)])

    [node_obj, ..acc]
  })
}

fn serialize_nodes_visjs_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.nodes, [], fn(acc, id, data) {
    let base = [#("id", json.int(id))]

    let with_label = case options.node_serializer {
      Some(serializer) -> [#("label", serializer(data)), ..base]
      None -> base
    }

    [json.object(with_label), ..acc]
  })
}

fn serialize_nodes_networkx_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.nodes, [], fn(acc, id, data) {
    let base = [#("id", json.int(id))]

    let with_data = case options.node_serializer {
      Some(serializer) -> [#("data", serializer(data)), ..base]
      None -> base
    }

    [json.object(with_data), ..acc]
  })
}

// ===== MultiGraph Edge Serialization Functions =====

fn serialize_edges_generic_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.edges, [], fn(acc, edge_id, edge_tuple) {
    let #(from_id, to_id, edge_data) = edge_tuple

    // For undirected graphs, only include each edge once
    case graph.kind {
      Undirected if from_id > to_id -> acc
      _ -> {
        let data_json = case options.edge_serializer {
          Some(serializer) -> serializer(edge_data)
          None -> json.null()
        }

        let edge_obj =
          json.object([
            #("id", json.int(edge_id)),
            #("source", json.int(from_id)),
            #("target", json.int(to_id)),
            #("data", data_json),
          ])

        [edge_obj, ..acc]
      }
    }
  })
}

fn serialize_edges_d3_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.edges, [], fn(acc, edge_id, edge_tuple) {
    let #(from_id, to_id, edge_data) = edge_tuple

    case graph.kind {
      Undirected if from_id > to_id -> acc
      _ -> {
        let from_str = int.to_string(from_id)
        let to_str = int.to_string(to_id)

        let base = [
          #("id", json.int(edge_id)),
          #("source", json.string(from_str)),
          #("target", json.string(to_str)),
        ]

        let with_data = case options.edge_serializer {
          Some(serializer) -> [#("value", serializer(edge_data)), ..base]
          None -> base
        }

        [json.object(with_data), ..acc]
      }
    }
  })
}

fn serialize_edges_cytoscape_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.edges, [], fn(acc, edge_id, edge_tuple) {
    let #(from_id, to_id, edge_data) = edge_tuple

    case graph.kind {
      Undirected if from_id > to_id -> acc
      _ -> {
        let edge_id_str = "e" <> int.to_string(edge_id)
        let source_str = int.to_string(from_id)
        let target_str = int.to_string(to_id)

        let data_fields = [
          #("id", json.string(edge_id_str)),
          #("source", json.string(source_str)),
          #("target", json.string(target_str)),
        ]

        let data_obj = case options.edge_serializer {
          Some(serializer) -> {
            json.object([#("label", serializer(edge_data)), ..data_fields])
          }
          None -> json.object(data_fields)
        }

        let edge_obj = json.object([#("data", data_obj)])

        [edge_obj, ..acc]
      }
    }
  })
}

fn serialize_edges_visjs_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.edges, [], fn(acc, edge_id, edge_tuple) {
    let #(from_id, to_id, edge_data) = edge_tuple

    case graph.kind {
      Undirected if from_id > to_id -> acc
      _ -> {
        let base = [
          #("id", json.int(edge_id)),
          #("from", json.int(from_id)),
          #("to", json.int(to_id)),
        ]

        let with_label = case options.edge_serializer {
          Some(serializer) -> [#("label", serializer(edge_data)), ..base]
          None -> base
        }

        [json.object(with_label), ..acc]
      }
    }
  })
}

fn serialize_edges_networkx_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> List(json.Json) {
  dict.fold(graph.edges, [], fn(acc, edge_id, edge_tuple) {
    let #(from_id, to_id, edge_data) = edge_tuple

    case graph.kind {
      Undirected if from_id > to_id -> acc
      _ -> {
        let base = [
          #("id", json.int(edge_id)),
          #("source", json.int(from_id)),
          #("target", json.int(to_id)),
        ]

        let with_data = case options.edge_serializer {
          Some(serializer) -> [#("weight", serializer(edge_data)), ..base]
          None -> base
        }

        [json.object(with_data), ..acc]
      }
    }
  })
}

// ===== MultiGraph Metadata Building =====

fn build_metadata_multi(
  graph: multi.MultiGraph(n, e),
  options: JsonExportOptions(n, e),
) -> json.Json {
  let graph_type = case graph.kind {
    Directed -> "directed"
    Undirected -> "undirected"
  }

  let base_metadata = [
    #("graph_type", json.string(graph_type)),
    #("multigraph", json.bool(True)),
    #("node_count", json.int(dict.size(graph.nodes))),
    #("edge_count", json.int(dict.size(graph.edges))),
  ]

  let with_custom = case options.metadata {
    Some(custom_metadata) -> {
      let custom_list =
        dict.to_list(custom_metadata)
        |> list.map(fn(pair) {
          let #(key, value) = pair
          #(key, value)
        })
      list.append(custom_list, base_metadata)
    }
    None -> base_metadata
  }

  json.object(with_custom)
}

// ===== Internal Decoding =====

type GenericMetadata {
  GenericMetadata(graph_type: String, multigraph: Bool)
}

type GenericNode(n) {
  GenericNode(id: Int, data: n)
}

type GenericEdge(e) {
  GenericEdge(id: Option(Int), source: Int, target: Int, data: e)
}

fn build_metadata_decoder() -> decode.Decoder(GenericMetadata) {
  use graph_type <- decode.field("graph_type", decode.string)
  use multigraph <- decode.optional_field("multigraph", False, decode.bool)
  decode.success(GenericMetadata(graph_type, multigraph))
}

fn decode_node(
  data_decoder: decode.Decoder(n),
) -> decode.Decoder(GenericNode(n)) {
  use id <- decode.field("id", decode.int)
  use data <- decode.field("data", data_decoder)
  decode.success(GenericNode(id, data))
}

fn decode_edge(
  data_decoder: decode.Decoder(e),
) -> decode.Decoder(GenericEdge(e)) {
  use id <- decode.optional_field("id", None, decode.optional(decode.int))
  use source <- decode.field("source", decode.int)
  use target <- decode.field("target", decode.int)
  use data <- decode.field("data", data_decoder)
  decode.success(GenericEdge(id, source, target, data))
}
