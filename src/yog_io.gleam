//// Yog IO - Graph file format I/O for the yog graph library.
////
//// Provides serialization and deserialization support for popular graph file formats:
//// - **GraphML** - XML-based format supported by Gephi, yEd, Cytoscape, and NetworkX
//// - **GDF** - Simple CSV-like format used by Gephi
//// - **TGF** - Trivial Graph Format, a simple text format for quick exchange
//// - **LEDA** - Library of Efficient Data types and Algorithms format
//// - **Pajek** - Social network analysis standard (.net format)
//// - **JSON** - Multiple formats for web visualization libraries (D3.js, Cytoscape.js, vis.js, etc.)
////
//// ## Quick Start
////
//// ```gleam
//// import yog/model.{Directed}
//// import yog_io
////
//// // Create a graph
//// let graph =
////   model.new(Directed)
////   |> model.add_node(1, "Alice")
////   |> model.add_node(2, "Bob")
////
//// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "friend")
////
//// // Write to GraphML
//// let assert Ok(Nil) = yog_io.write_graphml("graph.graphml", graph)
////
//// // Read from GraphML
//// let assert Ok(loaded) = yog_io.read_graphml("graph.graphml")
////
//// // Write to GDF
//// let assert Ok(Nil) = yog_io.write_gdf("graph.gdf", graph)
//// ```
////
//// ## Module Structure
////
//// - **`yog_io/graphml`** - Full-featured GraphML support with custom attribute mappers
//// - **`yog_io/gdf`** - GDF format support with custom attribute mappers
//// - **`yog_io/tgf`** - TGF format support with custom label functions
//// - **`yog_io/leda`** - LEDA format support for research tool compatibility
//// - **`yog_io/pajek`** - Pajek format support for social network analysis
////
//// For more control over serialization, use the submodules directly.

import gleam/json as gleam_json
import gleam/option
import simplifile
import yog/model.{type Graph}
import yog_io/gdf
import yog_io/graphml
import yog_io/json
import yog_io/leda
import yog_io/pajek
import yog_io/tgf

// Re-export types
pub type NodeAttributes =
  graphml.NodeAttributes

pub type EdgeAttributes =
  graphml.EdgeAttributes

pub type AttributedGraph =
  graphml.AttributedGraph

pub type AttributeType =
  graphml.AttributeType

pub type TypedNodeAttributes =
  graphml.TypedNodeAttributes

pub type TypedEdgeAttributes =
  graphml.TypedEdgeAttributes

pub type GraphMLOptions =
  graphml.GraphMLOptions

pub type GdfOptions =
  gdf.GdfOptions

pub type TgfOptions(n, e) =
  tgf.TgfOptions(n, e)

pub type TgfError =
  tgf.TgfError

pub type LedaOptions(n, e) =
  leda.LedaOptions(n, e)

pub type LedaError =
  leda.LedaError

pub type LedaType =
  leda.LedaType

pub type PajekOptions(n, e) =
  pajek.PajekOptions(n, e)

pub type PajekError =
  pajek.PajekError

pub type PajekNodeShape =
  pajek.NodeShape

pub type PajekNodeAttributes =
  pajek.NodeAttributes

pub type JsonFormat =
  json.JsonFormat

pub type JsonExportOptions(n, e) =
  json.JsonExportOptions(n, e)

pub type JsonError =
  json.JsonError

// Re-export AttributeType constructors for convenience
pub const string_type = graphml.StringType

pub const int_type = graphml.IntType

pub const float_type = graphml.FloatType

pub const double_type = graphml.DoubleType

pub const boolean_type = graphml.BooleanType

pub const long_type = graphml.LongType

// =============================================================================
// CONVENIENCE FUNCTIONS
// =============================================================================

/// Reads a graph from a GraphML file.
///
/// This is a convenience function that reads node and edge data as
/// string dictionaries. For custom data types, use `graphml.read_with`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(graph) = yog_io.read_graphml("graph.graphml")
///
/// // Access node data
/// import gleam/dict
/// let node1_data = dict.get(graph.nodes, 1)
/// ```
pub fn read_graphml(path: String) -> Result(AttributedGraph, String) {
  graphml.read(path)
}

/// Writes a graph to a GraphML file.
///
/// This is a convenience function for graphs with string data.
/// For custom data types, use `graphml.write_with`.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "5")
///
/// let assert Ok(Nil) = yog_io.write_graphml("graph.graphml", graph)
/// ```
pub fn write_graphml(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, simplifile.FileError) {
  graphml.write(path, graph)
}

/// Reads a graph from a GDF file.
///
/// This is a convenience function that reads node and edge data as
/// string dictionaries. For custom data types, use `gdf.read_with`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(graph) = yog_io.read_gdf("graph.gdf")
/// ```
pub fn read_gdf(path: String) -> Result(AttributedGraph, String) {
  gdf.read(path)
}

/// Writes a graph to a GDF file.
///
/// This is a convenience function for graphs with string data.
/// For custom data types, use `gdf.write_with`.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "5")
///
/// let assert Ok(Nil) = yog_io.write_gdf("graph.gdf", graph)
/// ```
pub fn write_gdf(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, simplifile.FileError) {
  gdf.write(path, graph)
}

// =============================================================================
// DEFAULT OPTIONS
// =============================================================================

/// Default options for GraphML serialization.
pub fn default_graphml_options() -> GraphMLOptions {
  graphml.default_options()
}

/// Default options for GDF serialization.
pub fn default_gdf_options() -> GdfOptions {
  gdf.default_options()
}

/// Default options for TGF serialization.
pub fn default_tgf_options() -> tgf.TgfOptions(String, String) {
  tgf.default_options()
}

/// Default options for LEDA serialization.
pub fn default_leda_options() -> leda.LedaOptions(String, String) {
  leda.default_options()
}

/// Default options for Pajek serialization.
pub fn default_pajek_options() -> pajek.PajekOptions(String, String) {
  pajek.default_options()
}

/// Default node attributes for Pajek serialization.
pub fn default_pajek_node_attributes() -> pajek.NodeAttributes {
  pajek.default_node_attributes()
}

/// Default options for JSON export.
pub fn default_json_options() -> JsonExportOptions(String, String) {
  json.default_export_options()
}

// =============================================================================
// JSON FUNCTIONS
// =============================================================================

/// Writes a graph to a JSON file.
///
/// This is a convenience function for graphs with string data.
/// For custom data types, use `json.to_json_file` with custom serializers.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "follows")
///
/// let assert Ok(Nil) = yog_io.write_json("graph.json", graph)
/// ```
pub fn write_json(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, JsonError) {
  json.to_json_file(graph, path, json.default_export_options())
}

/// Converts a graph to a JSON string.
///
/// This is a convenience function for graphs with string data.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let json_string = yog_io.to_json(graph)
/// ```
pub fn to_json(graph: Graph(String, String)) -> String {
  json.to_json(graph, json.default_export_options())
}

/// Writes a graph to a JSON file in D3.js force-directed format.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = yog_io.write_d3_json("graph-d3.json", graph)
/// ```
pub fn write_d3_json(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, JsonError) {
  let options =
    json.JsonExportOptions(
      format: json.D3Force,
      include_metadata: False,
      node_serializer: option.Some(gleam_json.string),
      edge_serializer: option.Some(gleam_json.string),
      pretty: True,
      metadata: option.None,
    )
  json.to_json_file(graph, path, options)
}

/// Writes a graph to a JSON file in Cytoscape.js format.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = yog_io.write_cytoscape_json("graph-cytoscape.json", graph)
/// ```
pub fn write_cytoscape_json(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, JsonError) {
  let options =
    json.JsonExportOptions(
      format: json.Cytoscape,
      include_metadata: False,
      node_serializer: option.Some(gleam_json.string),
      edge_serializer: option.Some(gleam_json.string),
      pretty: True,
      metadata: option.None,
    )
  json.to_json_file(graph, path, options)
}

/// Writes a graph to a JSON file in vis.js format.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = yog_io.write_visjs_json("graph-visjs.json", graph)
/// ```
pub fn write_visjs_json(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, JsonError) {
  let options =
    json.JsonExportOptions(
      format: json.VisJs,
      include_metadata: False,
      node_serializer: option.Some(gleam_json.string),
      edge_serializer: option.Some(gleam_json.string),
      pretty: True,
      metadata: option.None,
    )
  json.to_json_file(graph, path, options)
}

// =============================================================================
// TGF FUNCTIONS
// =============================================================================

/// Reads a graph from a TGF file.
///
/// This is a convenience function that reads node and edge data as strings.
/// For custom data types, use `tgf.read_with`.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
///
/// case yog_io.read_tgf("graph.tgf", Directed) {
///   Ok(tgf.TgfResult(graph, warnings)) -> {
///     // Use the graph
///     process_graph(graph)
///   }
///   Error(e) -> handle_error(e)
/// }
/// ```
pub fn read_tgf(
  path: String,
  graph_type: model.GraphType,
) -> Result(tgf.TgfResult(String, String), tgf.TgfError) {
  tgf.read(path, graph_type)
}

/// Writes a graph to a TGF file.
///
/// This is a convenience function for graphs with string data.
/// For custom data types, use `tgf.write_with`.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "follows")
///
/// let assert Ok(Nil) = yog_io.write_tgf("graph.tgf", graph)
/// ```
pub fn write_tgf(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, simplifile.FileError) {
  tgf.write(path, graph)
}

/// Converts a graph to a TGF string.
///
/// This is a convenience function for graphs with string data.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let tgf_string = yog_io.to_tgf(graph)
/// ```
pub fn to_tgf(graph: Graph(String, String)) -> String {
  tgf.serialize(graph)
}

// =============================================================================
// LEDA FUNCTIONS
// =============================================================================

/// Reads a graph from a LEDA file.
///
/// This is a convenience function that reads node and edge data as strings.
/// For custom data types, use `leda.read_with`.
///
/// ## Example
///
/// ```gleam
/// case yog_io.read_leda("graph.gw") {
///   Ok(leda.LedaResult(graph, warnings)) -> {
///     // Use the graph
///     process_graph(graph)
///   }
///   Error(e) -> handle_error(e)
/// }
/// ```
pub fn read_leda(
  path: String,
) -> Result(leda.LedaResult(String, String), leda.LedaError) {
  leda.read(path)
}

/// Writes a graph to a LEDA file.
///
/// This is a convenience function for graphs with string data.
/// For custom data types, use `leda.write_with`.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "follows")
///
/// let assert Ok(Nil) = yog_io.write_leda("graph.gw", graph)
/// ```
pub fn write_leda(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, simplifile.FileError) {
  leda.write(path, graph)
}

/// Converts a graph to a LEDA string.
///
/// This is a convenience function for graphs with string data.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let leda_string = yog_io.to_leda(graph)
/// ```
pub fn to_leda(graph: Graph(String, String)) -> String {
  leda.serialize(graph)
}

// =============================================================================
// PAJEK FUNCTIONS
// =============================================================================

/// Reads a graph from a Pajek file.
///
/// This is a convenience function that reads node and edge data as strings.
/// For custom data types, use `pajek.read_with`.
///
/// ## Example
///
/// ```gleam
/// case yog_io.read_pajek("graph.net") {
///   Ok(pajek.PajekResult(graph, warnings)) -> {
///     // Use the graph
///     process_graph(graph)
///   }
///   Error(e) -> handle_error(e)
/// }
/// ```
pub fn read_pajek(
  path: String,
) -> Result(pajek.PajekResult(String, String), pajek.PajekError) {
  pajek.read(path)
}

/// Writes a graph to a Pajek file.
///
/// This is a convenience function for graphs with string data.
/// For custom data types, use `pajek.write_with`.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "follows")
///
/// let assert Ok(Nil) = yog_io.write_pajek("graph.net", graph)
/// ```
pub fn write_pajek(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, simplifile.FileError) {
  pajek.write(path, graph)
}

/// Converts a graph to a Pajek string.
///
/// This is a convenience function for graphs with string data.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let pajek_string = yog_io.to_pajek(graph)
/// ```
pub fn to_pajek(graph: Graph(String, String)) -> String {
  pajek.serialize(graph)
}
