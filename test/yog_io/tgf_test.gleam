import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import yog/model
import yog_io/tgf

// =============================================================================
// SERIALIZATION TESTS
// =============================================================================

pub fn serialize_directed_test() {
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
    |> model.add_node(3, "Carol")
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: "follows")
  let assert Ok(graph3) = model.add_edge(graph2, from: 2, to: 3, with: "knows")

  let options =
    tgf.options_with(node_label: fn(data) { data }, edge_label: fn(_) { None })
  let result = tgf.serialize_with(options, graph3)

  // Check that output contains expected elements
  result |> string.contains("1 Alice") |> should.be_true()
  result |> string.contains("2 Bob") |> should.be_true()
  result |> string.contains("3 Carol") |> should.be_true()
  result |> string.contains("#") |> should.be_true()
  result |> string.contains("1 2") |> should.be_true()
  result |> string.contains("2 3") |> should.be_true()
}

pub fn serialize_with_edge_labels_test() {
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: "follows")

  let options =
    tgf.options_with(node_label: fn(data) { data }, edge_label: fn(label) {
      Some(label)
    })
  let result = tgf.serialize_with(options, graph2)

  result |> string.contains("1 2 follows") |> should.be_true()
}

pub fn serialize_default_test() {
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: "follows")

  let result = tgf.serialize(graph2)

  // Default uses node data as label
  result |> string.contains("1 Alice") |> should.be_true()
  result |> string.contains("2 Bob") |> should.be_true()
}

pub fn serialize_undirected_test() {
  let graph =
    model.new(model.Undirected)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")
    |> model.add_node(3, "C")
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: "")
  let assert Ok(graph3) = model.add_edge(graph2, from: 2, to: 3, with: "")

  let options =
    tgf.options_with(node_label: fn(data) { data }, edge_label: fn(_) { None })
  let result = tgf.serialize_with(options, graph3)

  // For undirected, edges should still be present
  result |> string.contains("1 A") |> should.be_true()
  result |> string.contains("2 B") |> should.be_true()
  result |> string.contains("3 C") |> should.be_true()
  result |> string.contains("#") |> should.be_true()
}

// =============================================================================
// PARSING TESTS
// =============================================================================

pub fn parse_simple_test() {
  let input = "1 Alice\n2 Bob\n#\n1 2"

  let result =
    tgf.parse(input, model.Directed)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)

  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal("Alice")
  dict.get(nodes, 2) |> should.be_ok() |> should.equal("Bob")
}

pub fn parse_with_edge_labels_test() {
  let input = "1 Alice\n2 Bob\n3 Carol\n#\n1 2 follows\n2 3 knows"

  let result =
    tgf.parse(input, model.Directed)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(3)
  result.graph |> model.edge_count() |> should.equal(2)
}

pub fn parse_undirected_test() {
  let input = "1 A\n2 B\n3 C\n#\n1 2\n2 3"

  let result =
    tgf.parse(input, model.Undirected)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(3)
  result.graph |> model.edge_count() |> should.equal(2)
  result.graph.kind |> should.equal(model.Undirected)
}

pub fn parse_empty_input_test() {
  let input = ""

  let result = tgf.parse(input, model.Directed)
  should.be_error(result)
}

pub fn parse_no_edges_test() {
  let input = "1 Alice\n2 Bob\n#"

  let result =
    tgf.parse(input, model.Directed)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(0)
}

pub fn parse_only_separator_test() {
  let input = "#"

  let result =
    tgf.parse(input, model.Directed)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(0)
  result.graph |> model.edge_count() |> should.equal(0)
}

pub fn parse_whitespace_handling_test() {
  let input = "  1  Alice  \n  2  Bob  \n  #  \n  1  2  follows  "

  let result =
    tgf.parse(input, model.Directed)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
}

pub fn parse_labels_with_spaces_test() {
  let input = "1 Alice Smith\n2 Bob Jones\n#\n1 2 works with"

  let result =
    tgf.parse(input, model.Directed)
    |> should.be_ok()

  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal("Alice Smith")
  dict.get(nodes, 2) |> should.be_ok() |> should.equal("Bob Jones")
}

pub fn parse_duplicate_node_id_test() {
  let input = "1 Alice\n1 Bob\n#"

  let result = tgf.parse(input, model.Directed)
  should.be_error(result)
}

// =============================================================================
// ROUNDTRIP TESTS
// =============================================================================

pub fn roundtrip_simple_test() {
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: "follows")

  // Export
  let options =
    tgf.options_with(node_label: fn(data) { data }, edge_label: fn(label) {
      Some(label)
    })
  let exported = tgf.serialize_with(options, graph2)

  // Import
  let result =
    tgf.parse_with(
      exported,
      graph_type: model.Directed,
      node_parser: fn(_id, label) { label },
      edge_parser: fn(label) { label },
    )
    |> should.be_ok()

  // Verify structure
  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)
}

// =============================================================================
// CUSTOM TYPE TESTS
// =============================================================================

pub fn serialize_custom_types_test() {
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, 100)
    |> model.add_node(2, 200)
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: 42)

  let options =
    tgf.options_with(node_label: fn(n) { int.to_string(n) }, edge_label: fn(w) {
      Some(int.to_string(w))
    })
  let result = tgf.serialize_with(options, graph2)

  result |> string.contains("1 100") |> should.be_true()
  result |> string.contains("2 200") |> should.be_true()
  result |> string.contains("1 2 42") |> should.be_true()
}

// =============================================================================
// AUTO-NODE CREATION TESTS
// =============================================================================

pub fn parse_auto_create_nodes_test() {
  // Edge references non-existent node
  let input = "1 Alice\n#\n1 99 knows"

  let result =
    tgf.parse(input, model.Directed)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)

  // Node 99 should be auto-created with ID as label
  let nodes = result.graph.nodes
  dict.get(nodes, 99) |> should.be_ok() |> should.equal("99")
}

pub fn parse_auto_create_both_nodes_test() {
  // Edge with both nodes missing from node section
  let input = "#\n5 10 connects"

  let result =
    tgf.parse(input, model.Directed)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)

  let nodes = result.graph.nodes
  dict.get(nodes, 5) |> should.be_ok() |> should.equal("5")
  dict.get(nodes, 10) |> should.be_ok() |> should.equal("10")
}

// =============================================================================
// ERROR HANDLING TESTS
// =============================================================================

pub fn parse_invalid_node_id_test() {
  let input = "abc Alice\n#"

  case tgf.parse(input, model.Directed) {
    Error(tgf.InvalidNodeId(line, value)) -> {
      line |> should.equal(1)
      value |> should.equal("abc")
    }
    _ -> panic as "Expected InvalidNodeId error"
  }
}

pub fn parse_invalid_edge_source_test() {
  let input = "1 Alice\n2 Bob\n#\nxyz 2"

  case tgf.parse(input, model.Directed) {
    Error(tgf.InvalidEdgeEndpoint(line, value)) -> {
      line |> should.equal(4)
      value |> should.equal("xyz")
    }
    _ -> panic as "Expected InvalidEdgeEndpoint error"
  }
}

pub fn parse_invalid_edge_target_test() {
  let input = "1 Alice\n2 Bob\n#\n1 xyz"

  case tgf.parse(input, model.Directed) {
    Error(tgf.InvalidEdgeEndpoint(line, value)) -> {
      line |> should.equal(4)
      value |> should.equal("xyz")
    }
    _ -> panic as "Expected InvalidEdgeEndpoint error"
  }
}

// =============================================================================
// WARNING TESTS
// =============================================================================

pub fn parse_with_warnings_test() {
  // Include some malformed lines that should be skipped (structurally invalid, not data invalid)
  // Empty node lines and incomplete edge lines should become warnings
  let input = "1 Alice\n2 Bob\n#\n1 2\n3\nincomplete"

  let result =
    tgf.parse(input, model.Directed)
    |> should.be_ok()

  // Should successfully parse valid parts
  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)

  // Should have warnings for incomplete edge lines
  // "3" has only one part (needs at least 2 for an edge)
  // "incomplete" has only one part
  result.warnings
  |> list.length()
  |> should.equal(2)
}

// =============================================================================
// EDGE CASE TESTS
// =============================================================================

pub fn parse_node_without_label_test() {
  // Node ID with no label should use ID as label
  let input = "1\n2 Bob\n#\n1 2"

  let result =
    tgf.parse(input, model.Directed)
    |> should.be_ok()

  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal("1")
  dict.get(nodes, 2) |> should.be_ok() |> should.equal("Bob")
}

pub fn parse_multiple_spaces_test() {
  // Multiple spaces should be handled correctly
  let input = "1   Alice   Smith\n2    Bob    Jones\n#\n1   2   works   with"

  let result =
    tgf.parse(input, model.Directed)
    |> should.be_ok()

  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal("Alice Smith")
  dict.get(nodes, 2) |> should.be_ok() |> should.equal("Bob Jones")
}
