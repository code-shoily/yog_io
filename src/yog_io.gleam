//// Yog IO - Graph file format I/O for the yog graph library.
////
//// Provides serialization and deserialization support for popular graph file formats:
//// - **GraphML** - XML-based format supported by Gephi, yEd, Cytoscape, and NetworkX
//// - **GDF** - Simple CSV-like format used by Gephi
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
////
//// For more control over serialization, use the submodules directly.

import simplifile
import yog/model.{type Graph}
import yog_io/gdf
import yog_io/graphml

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
