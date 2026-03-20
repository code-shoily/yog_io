import gleam/dict
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import simplifile
import yog/model.{Directed, Undirected}
import yog_io/graphml

// Type for custom mapper tests
type Person {
  Person(name: String, age: Int)
}

// =============================================================================
// SERIALIZATION TESTS
// =============================================================================

pub fn serialize_empty_directed_graph_test() {
  let graph = model.new(Directed)
  let xml = graphml.serialize(graph)

  xml
  |> string.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
  |> should.be_true()
  xml
  |> string.contains("<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\"")
  |> should.be_true()
  xml
  |> string.contains("edgedefault=\"directed\"")
  |> should.be_true()
  xml
  |> string.contains("</graphml>")
  |> should.be_true()
}

pub fn serialize_empty_undirected_graph_test() {
  let graph = model.new(Undirected)
  let xml = graphml.serialize(graph)

  xml
  |> string.contains("edgedefault=\"undirected\"")
  |> should.be_true()
}

pub fn serialize_single_node_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")

  let xml = graphml.serialize(graph)

  xml
  |> string.contains("<node id=\"1\">")
  |> should.be_true()
  xml
  |> string.contains("<data key=\"label\">Alice</data>")
  |> should.be_true()
  xml
  |> string.contains("</node>")
  |> should.be_true()
  xml
  |> string.contains("<key id=\"label\" for=\"node\"")
  |> should.be_true()
}

pub fn serialize_multiple_nodes_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
    |> model.add_node(3, "Charlie")

  let xml = graphml.serialize(graph)

  xml
  |> string.contains("<node id=\"1\">")
  |> should.be_true()
  xml
  |> string.contains("<node id=\"2\">")
  |> should.be_true()
  xml
  |> string.contains("<node id=\"3\">")
  |> should.be_true()
}

pub fn serialize_simple_edge_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")

  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "5")

  let xml = graphml.serialize(graph)

  xml
  |> string.contains("<edge source=\"1\" target=\"2\">")
  |> should.be_true()
  xml
  |> string.contains("<data key=\"weight\">5</data>")
  |> should.be_true()
  xml
  |> string.contains("<key id=\"weight\" for=\"edge\"")
  |> should.be_true()
}

pub fn serialize_multiple_edges_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")
    |> model.add_node(3, "C")

  let assert Ok(graph) =
    model.add_edges(graph, [#(1, 2, "10"), #(2, 3, "20"), #(1, 3, "30")])

  let xml = graphml.serialize(graph)

  xml
  |> string.contains("<edge source=\"1\" target=\"2\">")
  |> should.be_true()
  xml
  |> string.contains("<edge source=\"2\" target=\"3\">")
  |> should.be_true()
  xml
  |> string.contains("<edge source=\"1\" target=\"3\">")
  |> should.be_true()
}

pub fn serialize_undirected_edge_test() {
  let graph =
    model.new(Undirected)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")

  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "10")

  let xml = graphml.serialize(graph)

  // For undirected graphs, we should only have one edge (not two)
  // Count occurrences of edge element
  let edge_count = count_substrings(xml, "<edge ")
  edge_count
  |> should.equal(1)
}

pub fn serialize_with_custom_attributes_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")

  let node_attr = fn(name: String) {
    dict.from_list([#("name", name), #("type", "person")])
  }

  let edge_attr = fn(rel: String) {
    dict.from_list([#("relation", rel), #("strength", "strong")])
  }

  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "friend")

  let xml = graphml.serialize_with(node_attr, edge_attr, graph)

  xml
  |> string.contains("<key id=\"name\" for=\"node\"")
  |> should.be_true()
  xml
  |> string.contains("<key id=\"type\" for=\"node\"")
  |> should.be_true()
  xml
  |> string.contains("<key id=\"relation\" for=\"edge\"")
  |> should.be_true()
  xml
  |> string.contains("<key id=\"strength\" for=\"edge\"")
  |> should.be_true()
  xml
  |> string.contains("<data key=\"name\">Alice</data>")
  |> should.be_true()
  xml
  |> string.contains("<data key=\"type\">person</data>")
  |> should.be_true()
  xml
  |> string.contains("<data key=\"relation\">friend</data>")
  |> should.be_true()
  xml
  |> string.contains("<data key=\"strength\">strong</data>")
  |> should.be_true()
}

pub fn serialize_escapes_xml_special_chars_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice <admin>")

  let xml = graphml.serialize(graph)

  xml
  |> string.contains("&lt;admin&gt;")
  |> should.be_true()
  xml
  |> string.contains("<admin>")
  |> should.be_false()
}

pub fn serialize_with_options_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")

  let options = graphml.GraphMLOptions(indent: 0, xml_declaration: False)

  let node_attr = fn(name: String) { dict.from_list([#("label", name)]) }
  let edge_attr = fn(_: String) { dict.new() }

  let xml = graphml.serialize_with_options(node_attr, edge_attr, options, graph)

  xml
  |> string.contains("<?xml")
  |> should.be_false()
}

// =============================================================================
// DESERIALIZATION TESTS
// =============================================================================

pub fn deserialize_empty_graph_test() {
  let xml =
    "<?xml version=\"1.0\"?>
<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">
  <graph id=\"G\" edgedefault=\"directed\">
  </graph>
</graphml>"

  let assert Ok(graph) = graphml.deserialize(xml)

  graph.kind
  |> should.equal(Directed)

  dict.size(graph.nodes)
  |> should.equal(0)
}

pub fn deserialize_single_node_test() {
  let xml =
    "<?xml version=\"1.0\"?>
<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">
  <key id=\"label\" for=\"node\" attr.name=\"label\" attr.type=\"string\"/>
  <graph id=\"G\" edgedefault=\"directed\">
    <node id=\"1\">
      <data key=\"label\">Alice</data>
    </node>
  </graph>
</graphml>"

  let assert Ok(graph) = graphml.deserialize(xml)

  dict.size(graph.nodes)
  |> should.equal(1)

  let node_data = dict.get(graph.nodes, 1) |> should.be_ok()
  dict.get(node_data, "label")
  |> should.equal(Ok("Alice"))
}

pub fn deserialize_multiple_nodes_test() {
  let xml =
    "<?xml version=\"1.0\"?>
<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">
  <key id=\"label\" for=\"node\" attr.name=\"label\" attr.type=\"string\"/>
  <graph id=\"G\" edgedefault=\"directed\">
    <node id=\"1\"><data key=\"label\">Alice</data></node>
    <node id=\"2\"><data key=\"label\">Bob</data></node>
    <node id=\"3\"><data key=\"label\">Charlie</data></node>
  </graph>
</graphml>"

  let assert Ok(graph) = graphml.deserialize(xml)

  dict.size(graph.nodes)
  |> should.equal(3)

  dict.get(graph.nodes, 1)
  |> should.be_ok()
  dict.get(graph.nodes, 2)
  |> should.be_ok()
  dict.get(graph.nodes, 3)
  |> should.be_ok()
}

pub fn deserialize_simple_edge_test() {
  let xml =
    "<?xml version=\"1.0\"?>
<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">
  <key id=\"label\" for=\"node\" attr.name=\"label\" attr.type=\"string\"/>
  <key id=\"weight\" for=\"edge\" attr.name=\"weight\" attr.type=\"string\"/>
  <graph id=\"G\" edgedefault=\"directed\">
    <node id=\"1\"><data key=\"label\">A</data></node>
    <node id=\"2\"><data key=\"label\">B</data></node>
    <edge source=\"1\" target=\"2\">
      <data key=\"weight\">10</data>
    </edge>
  </graph>
</graphml>"

  let assert Ok(graph) = graphml.deserialize(xml)

  // Check edge exists
  let successors = model.successors(graph, 1)
  list.length(successors)
  |> should.equal(1)

  let assert Ok(#(dst, edge_data)) = list.first(successors)
  dst
  |> should.equal(2)

  dict.get(edge_data, "weight")
  |> should.equal(Ok("10"))
}

pub fn deserialize_undirected_graph_test() {
  let xml =
    "<?xml version=\"1.0\"?>
<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">
  <key id=\"label\" for=\"node\" attr.name=\"label\" attr.type=\"string\"/>
  <graph id=\"G\" edgedefault=\"undirected\">
    <node id=\"1\"><data key=\"label\">A</data></node>
    <node id=\"2\"><data key=\"label\">B</data></node>
    <edge source=\"1\" target=\"2\"/>
  </graph>
</graphml>"

  let assert Ok(graph) = graphml.deserialize(xml)

  graph.kind
  |> should.equal(Undirected)

  // In undirected graphs, both directions should exist
  let succ_1 = model.successors(graph, 1)
  list.length(succ_1)
  |> should.equal(1)

  let succ_2 = model.successors(graph, 2)
  list.length(succ_2)
  |> should.equal(1)
}

pub fn deserialize_with_custom_mappers_test() {
  let xml =
    "<?xml version=\"1.0\"?>
<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">
  <key id=\"name\" for=\"node\" attr.name=\"name\" attr.type=\"string\"/>
  <key id=\"age\" for=\"node\" attr.name=\"age\" attr.type=\"string\"/>
  <key id=\"relation\" for=\"edge\" attr.name=\"relation\" attr.type=\"string\"/>
  <graph id=\"G\" edgedefault=\"directed\">
    <node id=\"1\">
      <data key=\"name\">Alice</data>
      <data key=\"age\">30</data>
    </node>
    <node id=\"2\">
      <data key=\"name\">Bob</data>
      <data key=\"age\">25</data>
    </node>
    <edge source=\"1\" target=\"2\">
      <data key=\"relation\">friend</data>
    </edge>
  </graph>
</graphml>"

  let node_folder = fn(attrs: dict.Dict(String, String)) {
    let name = dict.get(attrs, "name") |> result.unwrap("")
    let age =
      dict.get(attrs, "age")
      |> result.unwrap("0")
      |> int.parse()
      |> result.unwrap(0)
    Person(name, age)
  }

  let edge_folder = fn(attrs: dict.Dict(String, String)) {
    dict.get(attrs, "relation") |> result.unwrap("")
  }

  let assert Ok(graph) = graphml.deserialize_with(node_folder, edge_folder, xml)

  // Check nodes
  let person1 = dict.get(graph.nodes, 1) |> should.be_ok()
  person1.name
  |> should.equal("Alice")
  person1.age
  |> should.equal(30)

  let person2 = dict.get(graph.nodes, 2) |> should.be_ok()
  person2.name
  |> should.equal("Bob")
  person2.age
  |> should.equal(25)

  // Check edge
  let assert Ok(#(_, edge_data)) = model.successors(graph, 1) |> list.first()
  edge_data
  |> should.equal("friend")
}

pub fn deserialize_multiple_edges_test() {
  let xml =
    "<?xml version=\"1.0\"?>
<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">
  <key id=\"label\" for=\"node\" attr.name=\"label\" attr.type=\"string\"/>
  <key id=\"weight\" for=\"edge\" attr.name=\"weight\" attr.type=\"string\"/>
  <graph id=\"G\" edgedefault=\"directed\">
    <node id=\"1\"><data key=\"label\">A</data></node>
    <node id=\"2\"><data key=\"label\">B</data></node>
    <node id=\"3\"><data key=\"label\">C</data></node>
    <edge source=\"1\" target=\"2\"><data key=\"weight\">10</data></edge>
    <edge source=\"2\" target=\"3\"><data key=\"weight\">20</data></edge>
    <edge source=\"1\" target=\"3\"><data key=\"weight\">30</data></edge>
  </graph>
</graphml>"

  let assert Ok(graph) = graphml.deserialize(xml)

  let succ_1 = model.successors(graph, 1)
  list.length(succ_1)
  |> should.equal(2)

  let succ_2 = model.successors(graph, 2)
  list.length(succ_2)
  |> should.equal(1)

  let succ_3 = model.successors(graph, 3)
  list.length(succ_3)
  |> should.equal(0)
}

// =============================================================================
// ROUNDTRIP TESTS
// =============================================================================

pub fn roundtrip_simple_graph_test() {
  let original =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")

  let assert Ok(original) =
    model.add_edge(original, from: 1, to: 2, with: "friend")

  let xml = graphml.serialize(original)
  let assert Ok(loaded) = graphml.deserialize(xml)

  // Check nodes
  dict.size(loaded.nodes)
  |> should.equal(2)

  let node1 = dict.get(loaded.nodes, 1) |> should.be_ok()
  dict.get(node1, "label")
  |> should.equal(Ok("Alice"))

  // Check edge
  let succ = model.successors(loaded, 1)
  list.length(succ)
  |> should.equal(1)

  let assert Ok(#(dst, edge_data)) = list.first(succ)
  dst
  |> should.equal(2)
  dict.get(edge_data, "weight")
  |> should.equal(Ok("friend"))
}

pub fn roundtrip_undirected_graph_test() {
  let original =
    model.new(Undirected)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")
    |> model.add_node(3, "C")

  let assert Ok(original) =
    model.add_edges(original, [#(1, 2, "10"), #(2, 3, "20")])

  let xml = graphml.serialize(original)
  let assert Ok(loaded) = graphml.deserialize(xml)

  loaded.kind
  |> should.equal(Undirected)

  // Check bidirectional edges exist
  let succ_1 = model.successors(loaded, 1)
  list.length(succ_1)
  |> should.equal(1)

  let succ_2 = model.successors(loaded, 2)
  list.length(succ_2)
  |> should.equal(2)
}

pub fn roundtrip_complex_graph_test() {
  let original =
    model.new(Directed)
    |> model.add_node(1, "Node1")
    |> model.add_node(2, "Node2")
    |> model.add_node(3, "Node3")
    |> model.add_node(4, "Node4")

  let assert Ok(original) =
    model.add_edges(original, [
      #(1, 2, "a"),
      #(1, 3, "b"),
      #(2, 4, "c"),
      #(3, 4, "d"),
    ])

  let xml = graphml.serialize(original)
  let assert Ok(loaded) = graphml.deserialize(xml)

  dict.size(loaded.nodes)
  |> should.equal(4)

  // Check all edges
  let succ_1 = model.successors(loaded, 1)
  list.length(succ_1)
  |> should.equal(2)

  let succ_4 = model.predecessors(loaded, 4)
  list.length(succ_4)
  |> should.equal(2)
}

// =============================================================================
// FILE I/O TESTS
// =============================================================================

pub fn write_and_read_graphml_file_test() {
  let path = "/tmp/test_yog_io_graphml.graphml"

  let original =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")

  let assert Ok(original) = model.add_edge(original, from: 1, to: 2, with: "5")

  // Write
  let assert Ok(Nil) = graphml.write(path, original)

  // Read back
  let assert Ok(loaded) = graphml.read(path)

  // Verify
  dict.size(loaded.nodes)
  |> should.equal(2)

  let node1 = dict.get(loaded.nodes, 1) |> should.be_ok()
  dict.get(node1, "label")
  |> should.equal(Ok("Alice"))

  // Cleanup
  let _ = simplifile.delete(path)

  Nil
}

pub fn read_nonexistent_file_test() {
  let result = graphml.read("/tmp/nonexistent_file_xyz.graphml")

  result
  |> should.be_error()
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

fn count_substrings(haystack: String, needle: String) -> Int {
  count_substrings_loop(haystack, needle, 0)
}

fn count_substrings_loop(haystack: String, needle: String, count: Int) -> Int {
  case string.split_once(haystack, needle) {
    Ok(#(_, rest)) -> count_substrings_loop(rest, needle, count + 1)
    Error(_) -> count
  }
}
