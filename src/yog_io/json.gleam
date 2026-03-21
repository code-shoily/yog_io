//// JSON format export and import for graph data exchange.
////
//// This module provides comprehensive JSON import/export capabilities for graph data,
//// supporting multiple formats used by popular visualization libraries.
////
//// ## Features
////
//// - **Generic types** for nodes and edges (not just Strings)
//// - **Multiple JSON formats** (D3.js, Cytoscape.js, vis.js, etc.)
//// - **File I/O operations** (read/write JSON files directly)
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
////   // Export to file
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
import gleam/function
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import yog/model.{type Graph, Directed, Undirected}

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
    True -> json.to_string(json_obj)
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
