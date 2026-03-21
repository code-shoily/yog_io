import gleam/dict
import gleam/json
import gleam/option
import gleam/string
import gleeunit
import gleeunit/should
import simplifile
import yog/model.{Directed, Undirected}
import yog_io/json as yog_json

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// Generic Format Tests
// =============================================================================

pub fn to_json_generic_format_test() {
  let assert Ok(graph) =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
    |> model.add_edge(from: 1, to: 2, with: "follows")

  let json_string = yog_json.to_json(graph, yog_json.default_export_options())

  // Should contain expected structure
  json_string
  |> string.contains("\"format\":\"yog-generic\"")
  |> should.be_true()

  json_string
  |> string.contains("\"version\":\"2.0\"")
  |> should.be_true()

  json_string
  |> string.contains("\"nodes\"")
  |> should.be_true()

  json_string
  |> string.contains("\"edges\"")
  |> should.be_true()

  json_string
  |> string.contains("\"metadata\"")
  |> should.be_true()
}

pub fn to_json_undirected_graph_test() {
  let assert Ok(graph) =
    model.new(Undirected)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")
    |> model.add_edge(from: 1, to: 2, with: "connected")

  let json_string = yog_json.to_json(graph, yog_json.default_export_options())

  json_string
  |> string.contains("\"graph_type\":\"undirected\"")
  |> should.be_true()
}

// =============================================================================
// D3.js Format Tests
// =============================================================================

pub fn to_json_d3_force_format_test() {
  let assert Ok(graph) =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
    |> model.add_edge(from: 1, to: 2, with: "5")

  let options =
    yog_json.JsonExportOptions(
      format: yog_json.D3Force,
      include_metadata: False,
      node_serializer: option.Some(json.string),
      edge_serializer: option.Some(json.string),
      pretty: True,
      metadata: option.None,
    )

  let json_string = yog_json.to_json(graph, options)

  // D3 format uses "links" instead of "edges"
  json_string
  |> string.contains("\"links\"")
  |> should.be_true()

  json_string
  |> string.contains("\"nodes\"")
  |> should.be_true()

  // Should not contain generic format markers
  json_string
  |> string.contains("\"format\"")
  |> should.be_false()
}

// =============================================================================
// Cytoscape Format Tests
// =============================================================================

pub fn to_json_cytoscape_format_test() {
  let assert Ok(graph) =
    model.new(Directed)
    |> model.add_node(1, "Node1")
    |> model.add_node(2, "Node2")
    |> model.add_edge(from: 1, to: 2, with: "edge1")

  let options =
    yog_json.JsonExportOptions(
      format: yog_json.Cytoscape,
      include_metadata: False,
      node_serializer: option.Some(json.string),
      edge_serializer: option.Some(json.string),
      pretty: True,
      metadata: option.None,
    )

  let json_string = yog_json.to_json(graph, options)

  // Cytoscape format has nested "elements" object
  json_string
  |> string.contains("\"elements\"")
  |> should.be_true()
}

// =============================================================================
// vis.js Format Tests
// =============================================================================

pub fn to_json_visjs_format_test() {
  let assert Ok(graph) =
    model.new(Directed)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")
    |> model.add_edge(from: 1, to: 2, with: "link")

  let options =
    yog_json.JsonExportOptions(
      format: yog_json.VisJs,
      include_metadata: False,
      node_serializer: option.Some(json.string),
      edge_serializer: option.Some(json.string),
      pretty: True,
      metadata: option.None,
    )

  let json_string = yog_json.to_json(graph, options)

  // vis.js uses "from" and "to" for edges
  json_string
  |> string.contains("\"from\"")
  |> should.be_true()

  json_string
  |> string.contains("\"to\"")
  |> should.be_true()
}

// =============================================================================
// NetworkX Format Tests
// =============================================================================

pub fn to_json_networkx_format_test() {
  let assert Ok(graph) =
    model.new(Directed)
    |> model.add_node(1, "X")
    |> model.add_node(2, "Y")
    |> model.add_edge(from: 1, to: 2, with: "edge")

  let options =
    yog_json.JsonExportOptions(
      format: yog_json.NetworkX,
      include_metadata: False,
      node_serializer: option.Some(json.string),
      edge_serializer: option.Some(json.string),
      pretty: True,
      metadata: option.None,
    )

  let json_string = yog_json.to_json(graph, options)

  // NetworkX format has specific fields
  json_string
  |> string.contains("\"directed\":true")
  |> should.be_true()

  json_string
  |> string.contains("\"multigraph\":false")
  |> should.be_true()

  json_string
  |> string.contains("\"links\"")
  |> should.be_true()
}

// =============================================================================
// File I/O Tests
// =============================================================================

pub fn to_json_file_test() {
  let assert Ok(graph) =
    model.new(Directed)
    |> model.add_node(1, "Test")
    |> model.add_node(2, "Node")
    |> model.add_edge(from: 1, to: 2, with: "link")

  let path = "test_output.json"

  // Write to file
  let result =
    yog_json.to_json_file(graph, path, yog_json.default_export_options())

  result
  |> should.be_ok()

  // Verify file was created
  let file_result = simplifile.read(path)
  file_result
  |> should.be_ok()

  // Clean up
  let _cleanup = simplifile.delete(path)
}

// =============================================================================
// Custom Serializer Tests
// =============================================================================

pub type Person {
  Person(name: String, age: Int)
}

pub fn custom_serializer_test() {
  let assert Ok(graph) =
    model.new(Directed)
    |> model.add_node(1, Person("Alice", 30))
    |> model.add_node(2, Person("Bob", 25))
    |> model.add_edge(from: 1, to: 2, with: 5)

  let options =
    yog_json.export_options_with(
      fn(person: Person) {
        json.object([
          #("name", json.string(person.name)),
          #("age", json.int(person.age)),
        ])
      },
      fn(weight) { json.int(weight) },
    )

  let json_string = yog_json.to_json(graph, options)

  json_string
  |> string.contains("\"Alice\"")
  |> should.be_true()

  json_string
  |> string.contains("\"Bob\"")
  |> should.be_true()
}

// =============================================================================
// Metadata Tests
// =============================================================================

pub fn metadata_inclusion_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")

  let custom_metadata =
    dict.from_list([
      #("description", json.string("Test Graph")),
      #("version", json.string("1.0")),
    ])

  let options =
    yog_json.JsonExportOptions(
      ..yog_json.default_export_options(),
      metadata: option.Some(custom_metadata),
    )

  let json_string = yog_json.to_json(graph, options)

  json_string
  |> string.contains("\"description\":\"Test Graph\"")
  |> should.be_true()

  json_string
  |> string.contains("\"version\":\"1.0\"")
  |> should.be_true()
}

pub fn no_metadata_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "A")

  let options =
    yog_json.JsonExportOptions(
      ..yog_json.default_export_options(),
      include_metadata: False,
    )

  let json_string = yog_json.to_json(graph, options)

  json_string
  |> string.contains("\"metadata\"")
  |> should.be_false()
}

// =============================================================================
// Edge Case Tests
// =============================================================================

pub fn empty_graph_test() {
  let graph = model.new(Directed)

  let json_string = yog_json.to_json(graph, yog_json.default_export_options())

  json_string
  |> string.contains("\"nodes\"")
  |> should.be_true()

  json_string
  |> string.contains("\"edges\"")
  |> should.be_true()
}

pub fn single_node_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(42, "Lonely")

  let json_string = yog_json.to_json(graph, yog_json.default_export_options())

  json_string
  |> string.contains("\"id\":42")
  |> should.be_true()

  json_string
  |> string.contains("\"Lonely\"")
  |> should.be_true()
}
