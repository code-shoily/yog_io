import gleam/dict
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import yog/model
import yog_io/pajek

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

  let options = pajek.options_with(
    node_label: fn(data) { data },
    edge_weight: fn(_) { None },
    node_attributes: fn(_) { pajek.default_node_attributes() },
    include_coordinates: False,
    include_visuals: False,
  )
  let result = pajek.serialize_with(options, graph3)

  // Check that output contains expected elements
  result |> string.contains("*Vertices 3") |> should.be_true()
  result |> string.contains("\"Alice\"") |> should.be_true()
  result |> string.contains("\"Bob\"") |> should.be_true()
  result |> string.contains("\"Carol\"") |> should.be_true()
  result |> string.contains("*Arcs") |> should.be_true()
  result |> string.contains("1 2") |> should.be_true()
  result |> string.contains("2 3") |> should.be_true()
}

pub fn serialize_undirected_test() {
  let graph =
    model.new(model.Undirected)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: "edge1")

  let options = pajek.options_with(
    node_label: fn(data) { data },
    edge_weight: fn(_) { None },
    node_attributes: fn(_) { pajek.default_node_attributes() },
    include_coordinates: False,
    include_visuals: False,
  )
  let result = pajek.serialize_with(options, graph2)

  // Undirected should have *Edges
  result |> string.contains("*Vertices 2") |> should.be_true()
  result |> string.contains("\"A\"") |> should.be_true()
  result |> string.contains("\"B\"") |> should.be_true()
  result |> string.contains("*Edges") |> should.be_true()
  result |> string.contains("1 2") |> should.be_true()
}

pub fn serialize_with_weights_test() {
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: 5.0)

  let options = pajek.options_with(
    node_label: fn(_data) { "Person" },
    edge_weight: fn(w) { Some(w) },
    node_attributes: fn(_) { pajek.default_node_attributes() },
    include_coordinates: False,
    include_visuals: False,
  )
  let result = pajek.serialize_with(options, graph2)

  result |> string.contains("1 2 5.0") |> should.be_true()
}

pub fn serialize_default_test() {
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: "follows")

  let result = pajek.serialize(graph2)

  result |> string.contains("*Vertices 2") |> should.be_true()
  result |> string.contains("\"Alice\"") |> should.be_true()
  result |> string.contains("\"Bob\"") |> should.be_true()
}

pub fn to_string_alias_test() {
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Start")
    |> model.add_node(2, "End")
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: "connects")

  let result = pajek.to_string(graph2)

  result |> string.contains("*Vertices 2") |> should.be_true()
}

// =============================================================================
// PARSING TESTS
// =============================================================================

pub fn parse_simple_test() {
  let input = "*Vertices 2\n1 \"Alice\"\n2 \"Bob\"\n*Arcs\n1 2"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)
  result.graph.kind |> should.equal(model.Directed)

  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal("Alice")
  dict.get(nodes, 2) |> should.be_ok() |> should.equal("Bob")
}

pub fn parse_undirected_test() {
  let input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Edges\n1 2"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)
  result.graph.kind |> should.equal(model.Undirected)
}

pub fn parse_with_weights_test() {
  let input = "*Vertices 2\n1 \"Alice\"\n2 \"Bob\"\n*Arcs\n1 2 5.5"

  let result = pajek.parse_with(
    input,
    node_parser: fn(s) { s },
    edge_parser: fn(w) { w },
  )
  |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)
}

pub fn parse_empty_input_test() {
  let input = ""

  let result = pajek.parse(input)
  should.be_error(result)
}

pub fn parse_invalid_header_test() {
  let input = "Invalid\n1 \"A\"\n*Arcs\n1 2"

  let result = pajek.parse(input)
  should.be_error(result)
}

pub fn parse_multiple_edges_test() {
  let input = "*Vertices 3\n1 \"A\"\n2 \"B\"\n3 \"C\"\n*Arcs\n1 2\n2 3"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(3)
  result.graph |> model.edge_count() |> should.equal(2)
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
  let options = pajek.options_with(
    node_label: fn(data) { data },
    edge_weight: fn(_) { None },
    node_attributes: fn(_) { pajek.default_node_attributes() },
    include_coordinates: False,
    include_visuals: False,
  )
  let exported = pajek.serialize_with(options, graph2)

  // Import
  let result = pajek.parse_with(
    exported,
    node_parser: fn(s) { s },
    edge_parser: fn(_) { "" },
  )
  |> should.be_ok()

  // Verify structure
  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)
}

// =============================================================================
// NODE ATTRIBUTES TESTS
// =============================================================================

pub fn node_shape_test() {
  let _shape = pajek.Ellipse
  pajek.default_node_attributes().shape |> should.equal(None)
}

pub fn node_attributes_creation_test() {
  let attrs = pajek.NodeAttributes(
    x: Some(0.5),
    y: Some(0.7),
    shape: Some(pajek.Box),
    size: Some(1.0),
    color: Some("red"),
  )

  attrs.x |> should.equal(Some(0.5))
  attrs.y |> should.equal(Some(0.7))
}

// =============================================================================
// CRITICAL BUG FIX TESTS
// =============================================================================

pub fn parse_multi_word_labels_test() {
  // Test that multi-word labels in quotes are parsed correctly
  let input = "*Vertices 3\n1 \"Alice Smith\"\n2 \"Bob Jones\"\n3 \"Carol White\"\n*Arcs\n1 2"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(3)

  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal("Alice Smith")
  dict.get(nodes, 2) |> should.be_ok() |> should.equal("Bob Jones")
  dict.get(nodes, 3) |> should.be_ok() |> should.equal("Carol White")
}

pub fn parse_multi_word_labels_with_coordinates_test() {
  // Test multi-word labels followed by coordinates
  let input = "*Vertices 2\n1 \"Alice Smith\" 0.5 0.7\n2 \"Bob Jones\" 0.3 0.4\n*Arcs"

  let result = pajek.parse(input)
  |> should.be_ok()

  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal("Alice Smith")
  dict.get(nodes, 2) |> should.be_ok() |> should.equal("Bob Jones")
}

// =============================================================================
// CASE-INSENSITIVE HEADER TESTS
// =============================================================================

pub fn parse_lowercase_arcs_header_test() {
  let input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*arcs\n1 2"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph.kind |> should.equal(model.Directed)
}

pub fn parse_uppercase_arcs_header_test() {
  let input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*ARCS\n1 2"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph.kind |> should.equal(model.Directed)
}

pub fn parse_mixed_case_edges_header_test() {
  let input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*EdGeS\n1 2"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph.kind |> should.equal(model.Undirected)
}

pub fn parse_lowercase_vertices_header_test() {
  let input = "*vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
}

// =============================================================================
// COMMENT HANDLING TESTS
// =============================================================================

pub fn parse_with_comments_test() {
  let input = "% This is a comment\n*Vertices 2\n% Another comment\n1 \"Alice\"\n2 \"Bob\"\n% Comment before arcs\n*Arcs\n1 2"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)
}

// =============================================================================
// EMPTY SECTION TESTS
// =============================================================================

pub fn parse_empty_arcs_section_test() {
  let input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(0)
}

pub fn parse_empty_edges_section_test() {
  let input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Edges"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(0)
}

// =============================================================================
// MALFORMED INPUT TESTS
// =============================================================================

pub fn parse_label_without_quotes_test() {
  // Labels without quotes should still work (fallback behavior)
  let input = "*Vertices 2\n1 Alice\n2 Bob\n*Arcs\n1 2"

  let result = pajek.parse(input)
  |> should.be_ok()

  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal("Alice")
  dict.get(nodes, 2) |> should.be_ok() |> should.equal("Bob")
}

pub fn parse_edge_referencing_nonexistent_node_test() {
  // Edge references node 99 which doesn't exist
  let input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs\n1 99"

  let result = pajek.parse(input)
  |> should.be_ok()

  // Edge should be skipped with warning
  result.graph |> model.edge_count() |> should.equal(0)
  result.warnings |> should.not_equal([])
}

pub fn parse_with_malformed_lines_test() {
  // Include malformed lines that should generate warnings
  let input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs\n1 2\ninvalid line\n2 1"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph |> model.edge_count() |> should.equal(2)
  result.warnings |> should.not_equal([])
}

// =============================================================================
// WHITESPACE HANDLING TESTS
// =============================================================================

pub fn parse_multiple_spaces_test() {
  let input = "*Vertices 2\n1   \"Alice\"\n2    \"Bob\"\n*Arcs\n1   2"

  let result = pajek.parse(input)
  |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)
}

pub fn parse_multiple_spaces_with_weights_test() {
  let input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs\n1   2   5.5"

  let result = pajek.parse_with(
    input,
    node_parser: fn(s) { s },
    edge_parser: fn(w) { w },
  )
  |> should.be_ok()

  result.graph |> model.edge_count() |> should.equal(1)
}

// =============================================================================
// WEIGHT PARSING TESTS
// =============================================================================

pub fn parse_edges_with_integer_weights_test() {
  let input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs\n1 2 5"

  let result = pajek.parse_with(
    input,
    node_parser: fn(s) { s },
    edge_parser: fn(w) { w },
  )
  |> should.be_ok()

  result.graph |> model.edge_count() |> should.equal(1)
}

pub fn parse_edges_without_weights_test() {
  let input = "*Vertices 2\n1 \"A\"\n2 \"B\"\n*Arcs\n1 2"

  let result = pajek.parse_with(
    input,
    node_parser: fn(s) { s },
    edge_parser: fn(w) {
      case w {
        Some(_) -> "weighted"
        None -> "unweighted"
      }
    },
  )
  |> should.be_ok()

  result.graph |> model.edge_count() |> should.equal(1)
}
