import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import gleeunit/should
import simplifile
import yog/model.{Directed, Undirected}
import yog_io/gdf

// Type for custom mapper tests
type Person {
  Person(name: String, age: Int)
}

// =============================================================================
// SERIALIZATION TESTS
// =============================================================================

pub fn serialize_empty_directed_graph_test() {
  let graph = model.new(Directed)
  let gdf_str = gdf.serialize(graph)

  gdf_str
  |> string.contains("nodedef>name VARCHAR")
  |> should.be_true()
  gdf_str
  |> string.contains("edgedef>node1 VARCHAR")
  |> should.be_true()
  gdf_str
  |> string.contains("directed BOOLEAN")
  |> should.be_true()
}

pub fn serialize_empty_undirected_graph_test() {
  let graph = model.new(Undirected)
  let gdf_str = gdf.serialize(graph)

  // Undirected graphs should still have directed column but all values false
  gdf_str
  |> string.contains("directed BOOLEAN")
  |> should.be_true()
}

pub fn serialize_single_node_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")

  let gdf_str = gdf.serialize(graph)

  gdf_str
  |> string.contains("1,Alice")
  |> should.be_true()
  gdf_str
  |> string.contains("label VARCHAR")
  |> should.be_true()
}

pub fn serialize_multiple_nodes_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
    |> model.add_node(3, "Charlie")

  let gdf_str = gdf.serialize(graph)

  gdf_str
  |> string.contains("1,Alice")
  |> should.be_true()
  gdf_str
  |> string.contains("2,Bob")
  |> should.be_true()
  gdf_str
  |> string.contains("3,Charlie")
  |> should.be_true()
}

pub fn serialize_simple_edge_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")

  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "5")

  let gdf_str = gdf.serialize(graph)

  gdf_str
  |> string.contains("edgedef>")
  |> should.be_true()
  gdf_str
  |> string.contains("1,2,true,5")
  |> should.be_true()
  gdf_str
  |> string.contains("label VARCHAR")
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

  let gdf_str = gdf.serialize(graph)

  gdf_str
  |> string.contains("1,2,true,10")
  |> should.be_true()
  gdf_str
  |> string.contains("2,3,true,20")
  |> should.be_true()
  gdf_str
  |> string.contains("1,3,true,30")
  |> should.be_true()
}

pub fn serialize_undirected_edge_test() {
  let graph =
    model.new(Undirected)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")

  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "10")

  let gdf_str = gdf.serialize(graph)

  // For undirected graphs, we should only have one edge
  let lines = string.split(gdf_str, "\n")
  let edge_lines =
    list.filter(lines, fn(line) {
      string.starts_with(line, "1,2,") || string.starts_with(line, "2,1,")
    })

  list.length(edge_lines)
  |> should.equal(1)

  // Should be marked as undirected
  gdf_str
  |> string.contains("false")
  |> should.be_true()
}

pub fn serialize_weighted_graph_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")

  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: 42)

  let gdf_str = gdf.serialize_weighted(graph)

  gdf_str
  |> string.contains("weight VARCHAR")
  |> should.be_true()
  gdf_str
  |> string.contains("1,2,true,42")
  |> should.be_true()
}

pub fn serialize_with_custom_attributes_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")

  let node_attr = fn(name: String) {
    dict.from_list([#("name", name), #("role", "user")])
  }

  let edge_attr = fn(rel: String) {
    dict.from_list([#("relation", rel), #("weight", "strong")])
  }

  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "friend")

  let gdf_str =
    gdf.serialize_with(node_attr, edge_attr, gdf.default_options(), graph)

  gdf_str
  |> string.contains("nodedef>name VARCHAR,name VARCHAR,role VARCHAR")
  |> should.be_true()
  gdf_str
  |> string.contains("1,Alice,user")
  |> should.be_true()
  gdf_str
  |> string.contains("2,Bob,user")
  |> should.be_true()
  gdf_str
  |> string.contains("edgedef>")
  |> should.be_true()
  gdf_str
  |> string.contains("relation")
  |> should.be_true()
  gdf_str
  |> string.contains("weight")
  |> should.be_true()
}

pub fn serialize_without_types_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")

  let options =
    gdf.GdfOptions(separator: ",", include_types: False, include_directed: None)
  let node_attr = fn(name: String) { dict.from_list([#("label", name)]) }
  let edge_attr = fn(_: String) { dict.new() }

  let gdf_str = gdf.serialize_with(node_attr, edge_attr, options, graph)

  gdf_str
  |> string.contains("nodedef>name,label")
  |> should.be_true()
  gdf_str
  |> string.contains("VARCHAR")
  |> should.be_false()
}

pub fn serialize_with_custom_separator_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")

  let options =
    gdf.GdfOptions(separator: ";", include_types: True, include_directed: None)
  let node_attr = fn(name: String) { dict.from_list([#("label", name)]) }
  let edge_attr = fn(_: String) { dict.new() }

  let gdf_str = gdf.serialize_with(node_attr, edge_attr, options, graph)

  gdf_str
  |> string.contains("nodedef>name VARCHAR;label VARCHAR")
  |> should.be_true()
  gdf_str
  |> string.contains("1;Alice")
  |> should.be_true()
}

pub fn serialize_escapes_special_chars_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice, Admin")

  let gdf_str = gdf.serialize(graph)

  // Value with comma should be quoted
  gdf_str
  |> string.contains("\"Alice, Admin\"")
  |> should.be_true()
}

pub fn serialize_escapes_quotes_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice \"The Admin\"")

  let gdf_str = gdf.serialize(graph)

  // Quotes should be escaped as double quotes
  gdf_str
  |> string.contains("\"Alice \"\"The Admin\"\"\"")
  |> should.be_true()
}

// =============================================================================
// DESERIALIZATION TESTS
// =============================================================================

pub fn deserialize_empty_graph_test() {
  let gdf_str =
    "nodedef>name VARCHAR,label VARCHAR
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

  dict.size(graph.nodes)
  |> should.equal(0)
}

pub fn deserialize_single_node_test() {
  let gdf_str =
    "nodedef>name VARCHAR,label VARCHAR
1,Alice
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

  dict.size(graph.nodes)
  |> should.equal(1)

  let node_data = dict.get(graph.nodes, 1) |> should.be_ok()
  dict.get(node_data, "label")
  |> should.equal(Ok("Alice"))
}

pub fn deserialize_multiple_nodes_test() {
  let gdf_str =
    "nodedef>name VARCHAR,label VARCHAR
1,Alice
2,Bob
3,Charlie
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

  dict.size(graph.nodes)
  |> should.equal(3)

  let node1 = dict.get(graph.nodes, 1) |> should.be_ok()
  dict.get(node1, "label")
  |> should.equal(Ok("Alice"))

  let node2 = dict.get(graph.nodes, 2) |> should.be_ok()
  dict.get(node2, "label")
  |> should.equal(Ok("Bob"))

  let node3 = dict.get(graph.nodes, 3) |> should.be_ok()
  dict.get(node3, "label")
  |> should.equal(Ok("Charlie"))
}

pub fn deserialize_simple_edge_test() {
  let gdf_str =
    "nodedef>name VARCHAR,label VARCHAR
1,Alice
2,Bob
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,weight VARCHAR
1,2,true,10"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

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
  let gdf_str =
    "nodedef>name VARCHAR,label VARCHAR
1,A
2,B
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR
1,2,false,edge"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

  // Both directions should exist
  let succ_1 = model.successors(graph, 1)
  list.length(succ_1)
  |> should.equal(1)

  let succ_2 = model.successors(graph, 2)
  list.length(succ_2)
  |> should.equal(1)
}

pub fn deserialize_directed_graph_test() {
  let gdf_str =
    "nodedef>name VARCHAR,label VARCHAR
1,A
2,B
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR
1,2,true,edge"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

  graph.kind
  |> should.equal(Directed)

  let succ_1 = model.successors(graph, 1)
  list.length(succ_1)
  |> should.equal(1)

  let succ_2 = model.successors(graph, 2)
  list.length(succ_2)
  |> should.equal(0)
}

pub fn deserialize_multiple_edges_test() {
  let gdf_str =
    "nodedef>name VARCHAR,label VARCHAR
1,A
2,B
3,C
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,weight VARCHAR
1,2,true,10
2,3,true,20
1,3,true,30"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

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

pub fn deserialize_without_types_test() {
  let gdf_str =
    "nodedef>name,label
1,Alice
2,Bob
edgedef>node1,node2,directed,relation
1,2,true,friend"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

  dict.size(graph.nodes)
  |> should.equal(2)

  let succ = model.successors(graph, 1)
  list.length(succ)
  |> should.equal(1)
}

pub fn deserialize_with_quotes_test() {
  let gdf_str =
    "nodedef>name VARCHAR,label VARCHAR
1,\"Alice, Admin\"
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

  let node1 = dict.get(graph.nodes, 1) |> should.be_ok()
  dict.get(node1, "label")
  |> should.equal(Ok("Alice, Admin"))
}

pub fn deserialize_with_custom_mappers_test() {
  let gdf_str =
    "nodedef>name VARCHAR,name VARCHAR,age VARCHAR
1,Alice,30
2,Bob,25
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,relation VARCHAR
1,2,true,friend"

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

  let assert Ok(graph) = gdf.deserialize_with(node_folder, edge_folder, gdf_str)

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

pub fn deserialize_missing_edge_section_test() {
  let gdf_str =
    "nodedef>name VARCHAR,label VARCHAR
1,Alice
2,Bob"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

  dict.size(graph.nodes)
  |> should.equal(2)

  // No edges
  let succ_1 = model.successors(graph, 1)
  list.length(succ_1)
  |> should.equal(0)
}

pub fn deserialize_edge_without_nodes_creates_nodes_test() {
  // In GDF, edges can reference nodes that weren't explicitly defined
  let gdf_str =
    "nodedef>name VARCHAR,label VARCHAR
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,weight VARCHAR
1,2,true,10"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

  // Both nodes should exist even though only referenced in edge
  dict.size(graph.nodes)
  |> should.equal(2)

  let succ_1 = model.successors(graph, 1)
  list.length(succ_1)
  |> should.equal(1)
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

  let gdf_str = gdf.serialize(original)
  let assert Ok(loaded) = gdf.deserialize(gdf_str)

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
  dict.get(edge_data, "label")
  |> should.equal(Ok("friend"))
}

pub fn roundtrip_weighted_graph_test() {
  let original =
    model.new(Directed)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")
    |> model.add_node(3, "C")

  let assert Ok(original) =
    model.add_edges(original, [#(1, 2, 10), #(2, 3, 20)])

  let gdf_str = gdf.serialize_weighted(original)
  let assert Ok(loaded) = gdf.deserialize(gdf_str)

  dict.size(loaded.nodes)
  |> should.equal(3)

  let assert Ok(#(_, edge_data)) = model.successors(loaded, 1) |> list.first()
  dict.get(edge_data, "weight")
  |> should.equal(Ok("10"))
}

pub fn roundtrip_undirected_graph_test() {
  let original =
    model.new(Undirected)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")
    |> model.add_node(3, "C")

  let assert Ok(original) =
    model.add_edges(original, [#(1, 2, "10"), #(2, 3, "20")])

  let gdf_str = gdf.serialize(original)
  let assert Ok(loaded) = gdf.deserialize(gdf_str)

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

  let gdf_str = gdf.serialize(original)
  let assert Ok(loaded) = gdf.deserialize(gdf_str)

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

pub fn write_and_read_gdf_file_test() {
  let path = "/tmp/test_yog_io_gdf.gdf"

  let original =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")

  let assert Ok(original) = model.add_edge(original, from: 1, to: 2, with: "5")

  // Write
  let assert Ok(Nil) = gdf.write(path, original)

  // Read back
  let assert Ok(loaded) = gdf.read(path)

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
  let result = gdf.read("/tmp/nonexistent_file_xyz.gdf")

  result
  |> should.be_error()
}

// =============================================================================
// ERROR HANDLING TESTS
// =============================================================================

pub fn deserialize_missing_nodedef_test() {
  let gdf_str = "some random text without nodedef"

  let result = gdf.deserialize(gdf_str)

  result
  |> should.be_error()
}

pub fn deserialize_invalid_node_id_test() {
  let gdf_str =
    "nodedef>name VARCHAR,label VARCHAR
abc,Alice
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR"

  // Invalid node IDs should be skipped
  let assert Ok(graph) = gdf.deserialize(gdf_str)

  // No valid nodes were parsed
  dict.size(graph.nodes)
  |> should.equal(0)
}

// =============================================================================
// HEADER PARSING TESTS
// =============================================================================

pub fn deserialize_header_without_types_test() {
  let gdf_str =
    "nodedef>name,label,role
1,Alice,admin
edgedef>node1,node2,directed,relation,notes
1,2,true,friend,colleague"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

  let node1 = dict.get(graph.nodes, 1) |> should.be_ok()
  dict.get(node1, "name")
  |> should.equal(Ok("1"))
  dict.get(node1, "label")
  |> should.equal(Ok("Alice"))
  dict.get(node1, "role")
  |> should.equal(Ok("admin"))
}

pub fn deserialize_header_with_mixed_types_test() {
  let gdf_str =
    "nodedef>name VARCHAR,label,age INT
1,Alice,30
edgedef>node1,node2,directed,weight VARCHAR
1,2,true,10"

  let assert Ok(graph) = gdf.deserialize(gdf_str)

  // Column names should be extracted correctly (first word only)
  let node1 = dict.get(graph.nodes, 1) |> should.be_ok()
  dict.get(node1, "name")
  |> should.equal(Ok("1"))
  dict.get(node1, "label")
  |> should.equal(Ok("Alice"))
  dict.get(node1, "age")
  |> should.equal(Ok("30"))
}
