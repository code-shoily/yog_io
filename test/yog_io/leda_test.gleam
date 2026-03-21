import gleam/dict
import gleam/int
import gleam/string
import gleeunit/should
import yog/model
import yog_io/leda

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
    leda.options_with(
      node_serializer: fn(data) { data },
      edge_serializer: fn(data) { data },
      node_deserializer: fn(s) { s },
      edge_deserializer: fn(s) { s },
    )
  let result = leda.serialize_with(options, graph3)

  // Check that output contains expected elements
  result |> string.contains("LEDA.GRAPH") |> should.be_true()
  result |> string.contains("string") |> should.be_true()
  result |> string.contains("-1") |> should.be_true()
  // Directed
  result |> string.contains("|{Alice}|") |> should.be_true()
  result |> string.contains("|{Bob}|") |> should.be_true()
  result |> string.contains("|{Carol}|") |> should.be_true()
  // Check edge format: source target rev_edge |{data}|
  result |> string.contains("1 2 0 |{follows}|") |> should.be_true()
  result |> string.contains("2 3 0 |{knows}|") |> should.be_true()
}

pub fn serialize_undirected_test() {
  let graph =
    model.new(model.Undirected)
    |> model.add_node(1, "A")
    |> model.add_node(2, "B")
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: "edge1")

  let options =
    leda.options_with(
      node_serializer: fn(data) { data },
      edge_serializer: fn(data) { data },
      node_deserializer: fn(s) { s },
      edge_deserializer: fn(s) { s },
    )
  let result = leda.serialize_with(options, graph2)

  // Undirected should have -2
  result |> string.contains("-2") |> should.be_true()
  result |> string.contains("|{A}|") |> should.be_true()
  result |> string.contains("|{B}|") |> should.be_true()
}

pub fn serialize_default_test() {
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: "follows")

  let result = leda.serialize(graph2)

  result |> string.contains("LEDA.GRAPH") |> should.be_true()
  result |> string.contains("|{Alice}|") |> should.be_true()
  result |> string.contains("|{Bob}|") |> should.be_true()
}

pub fn to_string_alias_test() {
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Start")
    |> model.add_node(2, "End")
  let assert Ok(graph2) =
    model.add_edge(graph, from: 1, to: 2, with: "connects")

  let result = leda.to_string(graph2)

  result |> string.contains("LEDA.GRAPH") |> should.be_true()
}

// =============================================================================
// PARSING TESTS
// =============================================================================

pub fn parse_simple_test() {
  let input =
    "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{Alice}|\n|{Bob}|\n1\n1 2 0 |{follows}|"

  let result =
    leda.parse(input)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)

  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal("Alice")
  dict.get(nodes, 2) |> should.be_ok() |> should.equal("Bob")
}

pub fn parse_undirected_test() {
  let input =
    "LEDA.GRAPH\nstring\nstring\n-2\n2\n|{A}|\n|{B}|\n1\n1 2 0 |{edge1}|"

  let result =
    leda.parse(input)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)
  result.graph.kind |> should.equal(model.Undirected)
}

pub fn parse_empty_input_test() {
  let input = ""

  let result = leda.parse(input)
  should.be_error(result)
}

pub fn parse_invalid_header_test() {
  let input = "INVALID\nstring\nstring\n-1\n1\n|{A}|\n0"

  let result = leda.parse(input)
  should.be_error(result)
}

pub fn parse_with_custom_types_test() {
  let input =
    "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{100}|\n|{200}|\n1\n1 2 0 |{42}|"

  let result =
    leda.parse_with(
      input,
      node_parser: fn(s) {
        case int.parse(s) {
          Ok(n) -> n
          Error(_) -> 0
        }
      },
      edge_parser: fn(s) {
        case int.parse(s) {
          Ok(n) -> n
          Error(_) -> 0
        }
      },
    )
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(2)

  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal(100)
  dict.get(nodes, 2) |> should.be_ok() |> should.equal(200)
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
    leda.options_with(
      node_serializer: fn(data) { data },
      edge_serializer: fn(data) { data },
      node_deserializer: fn(s) { s },
      edge_deserializer: fn(s) { s },
    )
  let exported = leda.serialize_with(options, graph2)

  // Import
  let result =
    leda.parse_with(exported, node_parser: fn(s) { s }, edge_parser: fn(s) { s })
    |> should.be_ok()

  // Verify structure
  result.graph |> model.node_count() |> should.equal(2)
  result.graph |> model.edge_count() |> should.equal(1)
}

// =============================================================================
// EDGE CASE TESTS
// =============================================================================

pub fn parse_labels_with_spaces_test() {
  let input =
    "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{Alice Smith}|\n|{Bob Jones}|\n1\n1 2 0 |{works with}|"

  let result =
    leda.parse(input)
    |> should.be_ok()

  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal("Alice Smith")
  dict.get(nodes, 2) |> should.be_ok() |> should.equal("Bob Jones")
}

pub fn parse_multiple_edges_test() {
  let input =
    "LEDA.GRAPH\nstring\nstring\n-1\n3\n|{A}|\n|{B}|\n|{C}|\n2\n1 2 0 |{edge1}|\n2 3 0 |{edge2}|"

  let result =
    leda.parse(input)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(3)
  result.graph |> model.edge_count() |> should.equal(2)
}

pub fn serialize_custom_types_test() {
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, 100)
    |> model.add_node(2, 200)
  let assert Ok(graph2) = model.add_edge(graph, from: 1, to: 2, with: 42)

  let options =
    leda.options_with(
      node_serializer: fn(n) { int.to_string(n) },
      edge_serializer: fn(w) { int.to_string(w) },
      node_deserializer: fn(s) {
        case int.parse(s) {
          Ok(n) -> n
          Error(_) -> 0
        }
      },
      edge_deserializer: fn(s) {
        case int.parse(s) {
          Ok(n) -> n
          Error(_) -> 0
        }
      },
    )
  let result = leda.serialize_with(options, graph2)

  result |> string.contains("|{100}|") |> should.be_true()
  result |> string.contains("|{200}|") |> should.be_true()
  result |> string.contains("|{42}|") |> should.be_true()
}

// =============================================================================
// ERROR HANDLING TESTS
// =============================================================================

pub fn parse_invalid_direction_test() {
  let input = "LEDA.GRAPH\nstring\nstring\n-99\n1\n|{A}|\n0"

  case leda.parse(input) {
    Error(leda.InvalidDirection(line, value)) -> {
      line |> should.equal(4)
      value |> should.equal("-99")
    }
    _ -> panic as "Expected InvalidDirection error"
  }
}

pub fn parse_empty_graph_test() {
  let input = "LEDA.GRAPH\nstring\nstring\n-1\n0\n0"

  let result =
    leda.parse(input)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(0)
  result.graph |> model.edge_count() |> should.equal(0)
}

pub fn parse_edge_referencing_nonexistent_node_test() {
  // Edge references node 99 which doesn't exist
  let input =
    "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{A}|\n|{B}|\n1\n1 99 0 |{edge}|"

  let result =
    leda.parse(input)
    |> should.be_ok()

  // Edge should be skipped with warning
  result.graph |> model.edge_count() |> should.equal(0)
  result.warnings |> should.not_equal([])
}

pub fn parse_invalid_node_data_format_test() {
  // Node data missing delimiters
  let input = "LEDA.GRAPH\nstring\nstring\n-1\n2\nAlice\n|{Bob}|\n0"

  let result =
    leda.parse(input)
    |> should.be_ok()

  // Parser should handle lines without delimiters (fallback behavior)
  result.graph |> model.node_count() |> should.equal(2)
}

pub fn parse_malformed_edge_line_test() {
  // Edge line missing required fields
  let input = "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{A}|\n|{B}|\n1\n1 2"

  let result =
    leda.parse(input)
    |> should.be_ok()

  // Malformed edge should be skipped with warning
  result.graph |> model.edge_count() |> should.equal(0)
  result.warnings |> should.not_equal([])
}

pub fn parse_multiple_spaces_test() {
  let input =
    "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{Alice   Smith}|\n|{Bob   Jones}|\n1\n1   2   0   |{works   with}|"

  let result =
    leda.parse(input)
    |> should.be_ok()

  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal("Alice   Smith")
  dict.get(nodes, 2) |> should.be_ok() |> should.equal("Bob   Jones")
}

pub fn parse_node_id_mapping_test() {
  // Test that node IDs are properly mapped from LEDA 1-indexed positions
  let input =
    "LEDA.GRAPH\nstring\nstring\n-1\n3\n|{First}|\n|{Second}|\n|{Third}|\n2\n1 3 0 |{edge1}|\n2 3 0 |{edge2}|"

  let result =
    leda.parse(input)
    |> should.be_ok()

  result.graph |> model.node_count() |> should.equal(3)
  result.graph |> model.edge_count() |> should.equal(2)

  // Verify edges connect correct nodes by LEDA IDs
  let nodes = result.graph.nodes
  dict.get(nodes, 1) |> should.be_ok() |> should.equal("First")
  dict.get(nodes, 2) |> should.be_ok() |> should.equal("Second")
  dict.get(nodes, 3) |> should.be_ok() |> should.equal("Third")
}

pub fn parse_with_warnings_test() {
  // Include malformed lines that should generate warnings
  let input =
    "LEDA.GRAPH\nstring\nstring\n-1\n2\n|{A}|\n|{B}|\n2\n1 2 0 |{valid}|\ninvalid edge line"

  let result =
    leda.parse(input)
    |> should.be_ok()

  result.graph |> model.edge_count() |> should.equal(1)
  result.warnings |> should.not_equal([])
}
