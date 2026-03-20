//// GraphML (Graph Markup Language) serialization support.
////
//// Provides functions to serialize and deserialize graphs in the GraphML format,
//// an XML-based format widely supported by graph visualization and analysis tools
//// like Gephi, yEd, Cytoscape, and NetworkX.
////
//// ## Quick Start
////
//// ```gleam
//// import yog/model.{Directed}
//// import yog_io/graphml
////
//// // Create a simple graph
//// let graph =
////   model.new(Directed)
////   |> model.add_node(1, "Alice")
////   |> model.add_node(2, "Bob")
////
//// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "friend")
////
//// // Serialize to GraphML
//// let xml = graphml.serialize(graph)
////
//// // Write to file
//// let assert Ok(Nil) = graphml.write("graph.graphml", graph)
////
//// // Read from file
//// let assert Ok(loaded) = graphml.read("graph.graphml")
//// ```
////
//// ## Format Overview
////
//// GraphML is an XML-based format that supports:
//// - **Nodes** with custom attributes
//// - **Edges** with custom attributes
//// - **Directed and undirected** graphs
//// - **Hierarchical graphs** (not yet supported)
////
//// ## References
////
//// - [GraphML Specification](http://graphml.graphdrawing.org/specification.html)
//// - [GraphML Primer](http://graphml.graphdrawing.org/primer/graphml-primer.html)

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/string_tree as sb
import simplifile
import xmlm
import yog/model.{type Graph, type GraphType, type NodeId, Directed, Undirected}

// =============================================================================
// TYPES
// =============================================================================

/// Attributes for a node as a dictionary of string key-value pairs.
pub type NodeAttributes =
  Dict(String, String)

/// Attributes for an edge as a dictionary of string key-value pairs.
pub type EdgeAttributes =
  Dict(String, String)

/// A graph with string-based attributes for nodes and edges.
/// This is the default format used by `serialize` and `deserialize`.
pub type AttributedGraph =
  Graph(NodeAttributes, EdgeAttributes)

/// Attribute data type for GraphML attributes.
///
/// These types are compatible with Gephi, yEd, and other GraphML tools.
pub type AttributeType {
  /// String type - for text data
  StringType
  /// Integer type - for whole numbers
  IntType
  /// Float type - for decimal numbers (32-bit)
  FloatType
  /// Double type - for decimal numbers (64-bit, preferred for Gephi)
  DoubleType
  /// Boolean type - for true/false values
  BooleanType
  /// Long type - for large whole numbers (64-bit)
  LongType
}

/// Typed attributes for nodes - maps attribute name to (value, type) pairs.
/// Use this for proper Gephi compatibility with numeric and boolean attributes.
pub type TypedNodeAttributes =
  Dict(String, #(String, AttributeType))

/// Typed attributes for edges - maps attribute name to (value, type) pairs.
/// Use this for proper Gephi compatibility with numeric and boolean attributes.
pub type TypedEdgeAttributes =
  Dict(String, #(String, AttributeType))

/// Options for GraphML serialization.
pub type GraphMLOptions {
  GraphMLOptions(
    /// XML indentation spaces (0 for no formatting)
    indent: Int,
    /// Include XML declaration
    xml_declaration: Bool,
  )
}

/// Default GraphML serialization options.
pub fn default_options() -> GraphMLOptions {
  GraphMLOptions(indent: 2, xml_declaration: True)
}

/// Convert AttributeType to GraphML attr.type string.
fn attribute_type_to_string(attr_type: AttributeType) -> String {
  case attr_type {
    StringType -> "string"
    IntType -> "int"
    FloatType -> "float"
    DoubleType -> "double"
    BooleanType -> "boolean"
    LongType -> "long"
  }
}

// =============================================================================
// SERIALIZATION
// =============================================================================

/// Serializes a graph to a GraphML string with custom attribute mappers.
///
/// This function allows you to control how node and edge data are converted
/// to GraphML attributes. Use `serialize` for simple cases where node/edge
/// data are strings.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import gleam/dict
/// import yog/model.{Directed}
/// import yog_io/graphml
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
///   dict.from_list([#("name", p.name), #("age", int.to_string(p.age))])
/// }
///
/// let edge_attrs = fn(c: Connection) {
///   dict.from_list([#("weight", int.to_string(c.weight)), #("type", c.relation)])
/// }
///
/// let xml = graphml.serialize_with(node_attrs, edge_attrs, graph)
/// ```
pub fn serialize_with(
  node_attr: fn(n) -> NodeAttributes,
  edge_attr: fn(e) -> EdgeAttributes,
  graph: Graph(n, e),
) -> String {
  serialize_with_options(node_attr, edge_attr, default_options(), graph)
}

/// Serializes a graph to GraphML with typed attributes for Gephi compatibility.
///
/// This function allows you to specify the GraphML data type for each attribute,
/// which is essential for proper Gephi compatibility. Numeric attributes (Int, Float,
/// Double) will be recognized correctly for visualizations, layouts, and filters.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import gleam/dict
/// import gleam/int
/// import yog/model.{Directed}
/// import yog_io/graphml.{DoubleType, IntType, StringType}
///
/// type Person {
///   Person(name: String, age: Int, score: Float)
/// }
///
/// let node_attrs = fn(p: Person) {
///   dict.from_list([
///     #("name", #(p.name, StringType)),
///     #("age", #(int.to_string(p.age), IntType)),
///     #("score", #(float.to_string(p.score), DoubleType)),
///   ])
/// }
///
/// let edge_attrs = fn(weight: Int) {
///   dict.from_list([
///     #("weight", #(int.to_string(weight), DoubleType)),
///   ])
/// }
///
/// let xml = graphml.serialize_with_types(node_attrs, edge_attrs, graph)
/// ```
pub fn serialize_with_types(
  node_attr: fn(n) -> TypedNodeAttributes,
  edge_attr: fn(e) -> TypedEdgeAttributes,
  graph: Graph(n, e),
) -> String {
  serialize_with_types_and_options(
    node_attr,
    edge_attr,
    default_options(),
    graph,
  )
}

/// Serializes a graph to GraphML with typed attributes and custom options.
pub fn serialize_with_types_and_options(
  node_attr: fn(n) -> TypedNodeAttributes,
  edge_attr: fn(e) -> TypedEdgeAttributes,
  options: GraphMLOptions,
  graph: Graph(n, e),
) -> String {
  serialize_internal(
    fn(n) {
      node_attr(n)
      |> dict.map_values(fn(_k, v) { v })
    },
    fn(e) {
      edge_attr(e)
      |> dict.map_values(fn(_k, v) { v })
    },
    options,
    graph,
    True,
  )
}

/// Serializes a graph to a GraphML string with custom options.
pub fn serialize_with_options(
  node_attr: fn(n) -> NodeAttributes,
  edge_attr: fn(e) -> EdgeAttributes,
  options: GraphMLOptions,
  graph: Graph(n, e),
) -> String {
  // Convert untyped attributes to typed (all StringType)
  serialize_internal(
    fn(n) {
      node_attr(n)
      |> dict.map_values(fn(_k, v) { #(v, StringType) })
    },
    fn(e) {
      edge_attr(e)
      |> dict.map_values(fn(_k, v) { #(v, StringType) })
    },
    options,
    graph,
    False,
  )
}

// Internal serialization function that handles typed attributes
fn serialize_internal(
  node_attr: fn(n) -> Dict(String, #(String, AttributeType)),
  edge_attr: fn(e) -> Dict(String, #(String, AttributeType)),
  options: GraphMLOptions,
  graph: Graph(n, e),
  _use_types: Bool,
) -> String {
  let nodes_list = dict.to_list(graph.nodes)

  // Collect all unique attribute keys with their types
  // We use a dict to track key -> type, taking the first type encountered
  let node_key_types =
    nodes_list
    |> list.fold(dict.new(), fn(acc, entry) {
      let #(_, data) = entry
      let attrs = node_attr(data)
      dict.fold(attrs, acc, fn(acc2, key, value_and_type) {
        let #(_, attr_type) = value_and_type
        // Only add if not already present (first type wins)
        case dict.has_key(acc2, key) {
          True -> acc2
          False -> dict.insert(acc2, key, attr_type)
        }
      })
    })

  // Collect edges and their keys with types
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

  let edge_key_types =
    edges_list
    |> list.fold(dict.new(), fn(acc, entry) {
      let #(_, _, data) = entry
      let attrs = edge_attr(data)
      dict.fold(attrs, acc, fn(acc2, key, value_and_type) {
        let #(_, attr_type) = value_and_type
        case dict.has_key(acc2, key) {
          True -> acc2
          False -> dict.insert(acc2, key, attr_type)
        }
      })
    })

  // Build XML
  let builder = sb.new()

  // XML declaration
  let builder = case options.xml_declaration {
    True -> sb.append(builder, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
    False -> builder
  }

  // Root element
  let builder =
    sb.append(
      builder,
      "<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\"",
    )
    |> sb.append(" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"")
    |> sb.append(" xsi:schemaLocation=\"http://graphml.graphdrawing.org/xmlns")
    |> sb.append(" http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd\">\n")

  // Key definitions for nodes
  let builder =
    dict.fold(node_key_types, builder, fn(b, key, attr_type) {
      sb.append(b, "  <key id=\"")
      |> sb.append(escape_xml(key))
      |> sb.append("\" for=\"node\" attr.name=\"")
      |> sb.append(escape_xml(key))
      |> sb.append("\" attr.type=\"")
      |> sb.append(attribute_type_to_string(attr_type))
      |> sb.append("\"/>\n")
    })

  // Key definitions for edges
  let builder =
    dict.fold(edge_key_types, builder, fn(b, key, attr_type) {
      sb.append(b, "  <key id=\"")
      |> sb.append(escape_xml(key))
      |> sb.append("\" for=\"edge\" attr.name=\"")
      |> sb.append(escape_xml(key))
      |> sb.append("\" attr.type=\"")
      |> sb.append(attribute_type_to_string(attr_type))
      |> sb.append("\"/>\n")
    })

  // Graph element
  let edge_default = case graph.kind {
    Directed -> "directed"
    Undirected -> "undirected"
  }

  let builder =
    sb.append(builder, "  <graph id=\"G\" edgedefault=\"")
    |> sb.append(edge_default)
    |> sb.append("\">\n")

  // Nodes
  let builder =
    list.fold(nodes_list, builder, fn(b, entry) {
      let #(id, data) = entry
      let attrs = node_attr(data)

      let b =
        sb.append(b, "    <node id=\"")
        |> sb.append(int.to_string(id))
        |> sb.append("\">\n")

      // Add data elements
      let b =
        dict.fold(attrs, b, fn(b2, key, value_and_type) {
          let #(value, _type) = value_and_type
          sb.append(b2, "      <data key=\"")
          |> sb.append(escape_xml(key))
          |> sb.append("\">")
          |> sb.append(escape_xml(value))
          |> sb.append("</data>\n")
        })

      sb.append(b, "    </node>\n")
    })

  // For undirected graphs, we need to avoid duplicate edges
  // Since we store edges in both directions, we only output edges where src <= dst
  let edges_to_output = case graph.kind {
    Directed -> edges_list
    Undirected ->
      list.filter(edges_list, fn(entry) {
        let #(src, dst, _) = entry
        src <= dst
      })
  }

  // Edges
  let builder =
    list.fold(edges_to_output, builder, fn(b, entry) {
      let #(src, dst, data) = entry
      let attrs = edge_attr(data)

      let b =
        sb.append(b, "    <edge source=\"")
        |> sb.append(int.to_string(src))
        |> sb.append("\" target=\"")
        |> sb.append(int.to_string(dst))
        |> sb.append("\">\n")

      // Add data elements
      let b =
        dict.fold(attrs, b, fn(b2, key, value_and_type) {
          let #(value, _type) = value_and_type
          sb.append(b2, "      <data key=\"")
          |> sb.append(escape_xml(key))
          |> sb.append("\">")
          |> sb.append(escape_xml(value))
          |> sb.append("</data>\n")
        })

      sb.append(b, "    </edge>\n")
    })

  // Close graph and graphml
  let builder = sb.append(builder, "  </graph>\n")
  let builder = sb.append(builder, "</graphml>\n")

  sb.to_string(builder)
}

/// Serializes a graph to a GraphML string.
///
/// This is a simplified version of `serialize_with` for graphs where
/// node data and edge data are already strings. The string data is stored
/// as a "label" attribute.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
/// import yog_io/graphml
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Alice")
///   |> model.add_node(2, "Bob")
///
/// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "5")
///
/// let xml = graphml.serialize(graph)
/// // <?xml version="1.0" encoding="UTF-8"?>
/// // <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
/// //   <key id="label" for="node" attr.name="label" attr.type="string"/>
/// //   <key id="weight" for="edge" attr.name="weight" attr.type="string"/>
/// //   <graph id="G" edgedefault="directed">
/// //     <node id="1"><data key="label">Alice</data></node>
/// //     <node id="2"><data key="label">Bob</data></node>
/// //     <edge source="1" target="2"><data key="weight">5</data></edge>
/// //   </graph>
/// // </graphml>
/// ```
pub fn serialize(graph: Graph(String, String)) -> String {
  serialize_with(
    fn(d) { dict.from_list([#("label", d)]) },
    fn(w) { dict.from_list([#("weight", w)]) },
    graph,
  )
}

/// Writes a graph to a GraphML file.
///
/// ## Example
///
/// ```gleam
/// import yog/model.{Directed}
/// import yog_io/graphml
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, "Start")
///   |> model.add_node(2, "End")
///
/// let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "connection")
///
/// let assert Ok(Nil) = graphml.write("mygraph.graphml", graph)
/// ```
pub fn write(
  path: String,
  graph: Graph(String, String),
) -> Result(Nil, simplifile.FileError) {
  let content = serialize(graph)
  simplifile.write(path, content)
}

/// Writes a graph to a GraphML file with custom attribute mappers.
///
/// ## Example
///
/// ```gleam
/// import gleam/dict
/// import yog/model.{Directed}
/// import yog_io/graphml
///
/// type Person {
///   Person(name: String, age: Int)
/// }
///
/// let node_attrs = fn(p: Person) {
///   dict.from_list([#("name", p.name), #("age", int.to_string(p.age))])
/// }
///
/// let graph =
///   model.new(Directed)
///   |> model.add_node(1, Person("Alice", 30))
///
/// let assert Ok(Nil) = graphml.write_with(
///   "people.graphml",
///   node_attrs,
///   fn(e) { dict.from_list([#("type", e)]) },
///   graph
/// )
/// ```
pub fn write_with(
  path: String,
  node_attr: fn(n) -> NodeAttributes,
  edge_attr: fn(e) -> EdgeAttributes,
  graph: Graph(n, e),
) -> Result(Nil, simplifile.FileError) {
  let content = serialize_with(node_attr, edge_attr, graph)
  simplifile.write(path, content)
}

/// Writes a graph to a GraphML file with typed attributes for Gephi compatibility.
///
/// This function creates GraphML files with proper attribute types that work
/// seamlessly with Gephi for visualizations, layouts, and statistical analysis.
///
/// ## Example
///
/// ```gleam
/// import gleam/dict
/// import gleam/int
/// import yog/model.{Directed}
/// import yog_io/graphml.{DoubleType, IntType, StringType}
///
/// type Person {
///   Person(name: String, age: Int, score: Float)
/// }
///
/// let node_attrs = fn(p: Person) {
///   dict.from_list([
///     #("label", #(p.name, StringType)),
///     #("age", #(int.to_string(p.age), IntType)),
///     #("score", #(float.to_string(p.score), DoubleType)),
///   ])
/// }
///
/// let assert Ok(Nil) = graphml.write_with_types(
///   "people.graphml",
///   node_attrs,
///   fn(e) { dict.from_list([#("weight", #(e, DoubleType))]) },
///   graph
/// )
/// ```
pub fn write_with_types(
  path: String,
  node_attr: fn(n) -> TypedNodeAttributes,
  edge_attr: fn(e) -> TypedEdgeAttributes,
  graph: Graph(n, e),
) -> Result(Nil, simplifile.FileError) {
  let content = serialize_with_types(node_attr, edge_attr, graph)
  simplifile.write(path, content)
}

// =============================================================================
// DESERIALIZATION
// =============================================================================

/// Deserializes a GraphML string into a graph with custom data mappers.
///
/// This function allows you to control how GraphML attributes are converted
/// to your node and edge data types. Use `deserialize` for simple cases
/// where you want node/edge data as string dictionaries.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import gleam/dict
/// import yog/model.{Directed}
/// import yog_io/graphml
///
/// type Person {
///   Person(name: String, age: Int)
/// }
///
/// let node_folder = fn(attrs: dict.Dict(String, String)) {
///   let name = dict.get(attrs, "name") |> result.unwrap("")
///   let age = dict.get(attrs, "age") |> result.unwrap("0") |> int.parse |> result.unwrap(0)
///   Person(name, age)
/// }
///
/// let edge_folder = fn(attrs: dict.Dict(String, String)) {
///   dict.get(attrs, "type") |> result.unwrap("")
/// }
///
/// let xml = "..."
/// let assert Ok(graph) = graphml.deserialize_with(node_folder, edge_folder, xml)
/// ```
pub fn deserialize_with(
  node_folder: fn(NodeAttributes) -> n,
  edge_folder: fn(EdgeAttributes) -> e,
  xml: String,
) -> Result(Graph(n, e), String) {
  // Parse XML into signals
  let input = xmlm.from_string(xml)

  case xmlm.signals(input) {
    Error(_) -> Error("Failed to parse XML")
    Ok(#(signals, _)) -> {
      // Determine graph type from signals
      let graph_type = case find_graph_type(signals) {
        Some(gt) -> gt
        None -> Undirected
      }

      let graph = model.new(graph_type)

      // Parse the graph from signals
      parse_graphml_signals(signals, graph, node_folder, edge_folder)
    }
  }
}

/// Deserializes a GraphML string to a graph.
///
/// This is a simplified version of `deserialize_with` for graphs where
/// you want node data and edge data as string dictionaries containing all attributes.
///
/// **Time Complexity:** O(V + E)
///
/// ## Example
///
/// ```gleam
/// import yog_io/graphml
///
/// let xml = "..."
/// let assert Ok(graph) = graphml.deserialize(xml)
///
/// // Access node data
/// let node1_data = dict.get(graph.nodes, 1)  // Dict(String, String)
/// let label = dict.get(node1_data, "label")
/// ```
pub fn deserialize(xml: String) -> Result(AttributedGraph, String) {
  deserialize_with(fn(attrs) { attrs }, fn(attrs) { attrs }, xml)
}

/// Reads a graph from a GraphML file.
///
/// ## Example
///
/// ```gleam
/// import yog_io/graphml
///
/// let assert Ok(graph) = graphml.read("graph.graphml")
///
/// // Access node data
/// import gleam/dict
/// for node in dict.to_list(graph.nodes) {
///   let #(id, data) = node
///   io.debug("Node " <> int.to_string(id) <> ": " <> data)
/// }
/// ```
pub fn read(path: String) -> Result(AttributedGraph, String) {
  case simplifile.read(path) {
    Ok(content) -> deserialize(content)
    Error(e) -> Error("Failed to read file: " <> simplifile.describe_error(e))
  }
}

/// Reads a graph from a GraphML file with custom data mappers.
///
/// ## Example
///
/// ```gleam
/// import gleam/dict
/// import yog_io/graphml
///
/// type Person {
///   Person(name: String, age: Int)
/// }
///
/// let node_folder = fn(attrs) {
///   Person(
///     dict.get(attrs, "name") |> result.unwrap(""),
///     dict.get(attrs, "age") |> result.unwrap("0") |> int.parse |> result.unwrap(0)
///   )
/// }
///
/// let assert Ok(graph) = graphml.read_with("people.graphml", node_folder, fn(attrs) {
///   dict.get(attrs, "weight") |> result.unwrap("0") |> int.parse |> result.unwrap(0)
/// })
/// ```
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
// INTERNAL PARSING
// =============================================================================

// Parser state for tracking context while processing signals
type ParseState(n, e) {
  ParseState(
    graph: Graph(n, e),
    current_element: Option(String),
    current_node_id: Option(NodeId),
    current_node_attrs: NodeAttributes,
    current_edge_src: Option(NodeId),
    current_edge_tgt: Option(NodeId),
    current_edge_attrs: EdgeAttributes,
    current_data_key: Option(String),
    node_folder: fn(NodeAttributes) -> n,
    edge_folder: fn(EdgeAttributes) -> e,
  )
}

fn find_graph_type(signals: List(xmlm.Signal)) -> Option(GraphType) {
  case signals {
    [] -> None
    [first, ..rest] -> {
      case first {
        xmlm.ElementStart(tag) -> {
          case tag.name.local {
            "graph" -> {
              // Look for edgedefault attribute
              case
                list.find(tag.attributes, fn(attr) {
                  attr.name.local == "edgedefault"
                })
              {
                Ok(attr) ->
                  case attr.value {
                    "directed" -> Some(Directed)
                    _ -> Some(Undirected)
                  }
                Error(_) -> Some(Undirected)
              }
            }
            _ -> find_graph_type(rest)
          }
        }
        _ -> find_graph_type(rest)
      }
    }
  }
}

fn parse_graphml_signals(
  signals: List(xmlm.Signal),
  graph: Graph(n, e),
  node_folder: fn(NodeAttributes) -> n,
  edge_folder: fn(EdgeAttributes) -> e,
) -> Result(Graph(n, e), String) {
  let state =
    ParseState(
      graph: graph,
      current_element: None,
      current_node_id: None,
      current_node_attrs: dict.new(),
      current_edge_src: None,
      current_edge_tgt: None,
      current_edge_attrs: dict.new(),
      current_data_key: None,
      node_folder: node_folder,
      edge_folder: edge_folder,
    )

  let final_state = list.fold(signals, state, process_signal)
  Ok(final_state.graph)
}

fn process_signal(
  state: ParseState(n, e),
  signal: xmlm.Signal,
) -> ParseState(n, e) {
  case signal {
    xmlm.ElementStart(tag) -> process_element_start(state, tag)
    xmlm.ElementEnd -> process_element_end(state)
    xmlm.Data(text) -> process_data(state, text)
    xmlm.Dtd(_) -> state
  }
}

fn process_element_start(
  state: ParseState(n, e),
  tag: xmlm.Tag,
) -> ParseState(n, e) {
  case tag.name.local {
    "node" -> {
      // Extract node id from attributes
      case
        list.find(tag.attributes, fn(attr) { attr.name.local == "id" })
        |> result.try(fn(attr) { int.parse(attr.value) })
      {
        Ok(id) ->
          ParseState(
            ..state,
            current_element: Some("node"),
            current_node_id: Some(id),
            current_node_attrs: dict.new(),
          )
        Error(_) -> state
      }
    }
    "edge" -> {
      // Extract source and target from attributes
      let src =
        list.find(tag.attributes, fn(attr) { attr.name.local == "source" })
        |> result.try(fn(attr) { int.parse(attr.value) })
        |> option.from_result()

      let tgt =
        list.find(tag.attributes, fn(attr) { attr.name.local == "target" })
        |> result.try(fn(attr) { int.parse(attr.value) })
        |> option.from_result()

      ParseState(
        ..state,
        current_element: Some("edge"),
        current_edge_src: src,
        current_edge_tgt: tgt,
        current_edge_attrs: dict.new(),
      )
    }
    "data" -> {
      // Extract key attribute
      case list.find(tag.attributes, fn(attr) { attr.name.local == "key" }) {
        Ok(attr) -> ParseState(..state, current_data_key: Some(attr.value))
        Error(_) -> state
      }
    }
    _ -> state
  }
}

fn process_element_end(state: ParseState(n, e)) -> ParseState(n, e) {
  // If we have a data key set, this is the end of a data element
  case state.current_data_key {
    Some(_) -> ParseState(..state, current_data_key: None)
    None -> {
      // Otherwise, check if we're ending a node or edge element
      case state.current_element {
        Some("node") -> {
          // Finalize node
          case state.current_node_id {
            Some(id) -> {
              let node_data = state.node_folder(state.current_node_attrs)
              let new_graph = model.add_node(state.graph, id, node_data)
              ParseState(
                ..state,
                graph: new_graph,
                current_element: None,
                current_node_id: None,
                current_node_attrs: dict.new(),
              )
            }
            None -> state
          }
        }
        Some("edge") -> {
          // Finalize edge
          case state.current_edge_src, state.current_edge_tgt {
            Some(src), Some(tgt) -> {
              let edge_data = state.edge_folder(state.current_edge_attrs)

              // Ensure nodes exist
              let g_with_src = case dict.has_key(state.graph.nodes, src) {
                True -> state.graph
                False ->
                  model.add_node(
                    state.graph,
                    src,
                    state.node_folder(dict.new()),
                  )
              }

              let g_with_both = case dict.has_key(g_with_src.nodes, tgt) {
                True -> g_with_src
                False ->
                  model.add_node(g_with_src, tgt, state.node_folder(dict.new()))
              }

              let new_graph =
                add_edge_unchecked(g_with_both, src, tgt, edge_data)
              ParseState(
                ..state,
                graph: new_graph,
                current_element: None,
                current_edge_src: None,
                current_edge_tgt: None,
                current_edge_attrs: dict.new(),
              )
            }
            _, _ -> state
          }
        }
        _ -> state
      }
    }
  }
}

fn process_data(state: ParseState(n, e), text: String) -> ParseState(n, e) {
  case state.current_data_key {
    Some(key) -> {
      case state.current_element {
        Some("node") ->
          ParseState(
            ..state,
            current_node_attrs: dict.insert(state.current_node_attrs, key, text),
          )
        Some("edge") ->
          ParseState(
            ..state,
            current_edge_attrs: dict.insert(state.current_edge_attrs, key, text),
          )
        _ -> state
      }
    }
    None -> state
  }
}

fn add_edge_unchecked(
  graph: Graph(n, e),
  src: NodeId,
  dst: NodeId,
  weight: e,
) -> Graph(n, e) {
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

fn escape_xml(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&apos;")
}
