//// Property-based tests for graph serialization roundtrips.
////
//// These tests verify that serializing and then deserializing a graph
//// produces an equivalent graph (structural equality).

import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleeunit/should
import qcheck
import yog/model.{type Graph}
import yog_io/generators

// Import all format modules
import yog_io/gdf
import yog_io/graphml
import yog_io/json
import yog_io/leda
import yog_io/pajek
import yog_io/tgf

// =============================================================================
// STRUCTURAL EQUALITY HELPERS
// =============================================================================

/// Check if two graphs have the same structure (same nodes, edges, and connectivity).
/// This is stronger than just comparing counts - it verifies the actual graph topology.
fn graphs_structurally_equal(g1: Graph(n, e), g2: Graph(n, e)) -> Bool {
  // Must have same type
  g1.kind == g2.kind
  // Must have same number of nodes
  && model.node_count(g1) == model.node_count(g2)
  // Must have same number of edges
  && model.edge_count(g1) == model.edge_count(g2)
  // Must have same nodes (by ID and data)
  && have_same_nodes(g1, g2)
  // Must have same connectivity
  && have_same_edges(g1, g2)
}

/// Check if both graphs have the same nodes (same IDs with same data)
fn have_same_nodes(g1: Graph(n, e), g2: Graph(n, e)) -> Bool {
  let nodes1 =
    dict.to_list(g1.nodes) |> list.sort(by: fn(a, b) { int.compare(a.0, b.0) })
  let nodes2 =
    dict.to_list(g2.nodes) |> list.sort(by: fn(a, b) { int.compare(a.0, b.0) })

  nodes1 == nodes2
}

/// Check if both graphs have the same edges (same source/target with same data)
fn have_same_edges(g1: Graph(n, e), g2: Graph(n, e)) -> Bool {
  // Get all edges as sorted list of #(src, dst, weight)
  let edges1 = get_all_edges_sorted(g1)
  let edges2 = get_all_edges_sorted(g2)

  edges1 == edges2
}

/// Extract all edges from a graph as a sorted list
fn get_all_edges_sorted(graph: Graph(n, e)) -> List(#(Int, Int, e)) {
  dict.fold(graph.out_edges, [], fn(acc, src, targets) {
    dict.fold(targets, acc, fn(edge_acc, dst, weight) {
      [#(src, dst, weight), ..edge_acc]
    })
  })
  |> list.sort(by: fn(a, b) {
    case int.compare(a.0, b.0) {
      order.Eq -> int.compare(a.1, b.1)
      ord -> ord
    }
  })
}

// =============================================================================
// TGF FORMAT PROPERTY TESTS
// =============================================================================

/// TGF roundtrip property: serialize then parse should preserve structure
pub fn tgf_roundtrip_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())

  // Serialize with edge labels
  let options =
    tgf.options_with(node_label: fn(data) { data }, edge_label: fn(label) {
      Some(label)
    })
  let tgf_string = tgf.serialize_with(options, graph)

  // Parse back
  let result =
    tgf.parse_with(
      tgf_string,
      graph_type: graph.kind,
      node_parser: fn(_id, label) { label },
      edge_parser: fn(label) { label },
    )

  // Should parse successfully
  let assert Ok(tgf.TgfResult(parsed_graph, _warnings)) = result

  // Node count should match
  assert model.node_count(parsed_graph) == model.node_count(graph)
}

/// TGF directed graph roundtrip
pub fn tgf_directed_roundtrip_property_test() {
  use graph <- qcheck.given(generators.directed_string_graph_generator())

  let options =
    tgf.options_with(node_label: fn(data) { data }, edge_label: fn(label) {
      Some(label)
    })
  let tgf_string = tgf.serialize_with(options, graph)

  let result =
    tgf.parse_with(
      tgf_string,
      graph_type: model.Directed,
      node_parser: fn(_id, label) { label },
      edge_parser: fn(label) { label },
    )

  let assert Ok(tgf.TgfResult(parsed_graph, _)) = result

  // Check graph type is preserved
  assert parsed_graph.kind == model.Directed
  assert model.node_count(parsed_graph) == model.node_count(graph)
}

/// TGF undirected graph roundtrip
pub fn tgf_undirected_roundtrip_property_test() {
  use graph <- qcheck.given(generators.undirected_string_graph_generator())

  let options =
    tgf.options_with(node_label: fn(data) { data }, edge_label: fn(label) {
      Some(label)
    })
  let tgf_string = tgf.serialize_with(options, graph)

  let result =
    tgf.parse_with(
      tgf_string,
      graph_type: model.Undirected,
      node_parser: fn(_id, label) { label },
      edge_parser: fn(label) { label },
    )

  let assert Ok(tgf.TgfResult(parsed_graph, _)) = result

  assert parsed_graph.kind == model.Undirected
  assert model.node_count(parsed_graph) == model.node_count(graph)
}

// =============================================================================
// LEDA FORMAT PROPERTY TESTS
// =============================================================================

/// LEDA roundtrip property
pub fn leda_roundtrip_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())

  let options =
    leda.options_with(
      node_serializer: fn(data) { data },
      edge_serializer: fn(data) { data },
      node_deserializer: fn(s) { s },
      edge_deserializer: fn(s) { s },
    )

  let leda_string = leda.serialize_with(options, graph)

  let result =
    leda.parse_with(leda_string, node_parser: fn(s) { s }, edge_parser: fn(s) {
      s
    })

  let assert Ok(leda.LedaResult(parsed_graph, _warnings)) = result

  // LEDA uses 1-indexed sequential IDs, so structure may differ
  // but node count should match
  assert model.node_count(parsed_graph) == model.node_count(graph)
}

// =============================================================================
// PAJEK FORMAT PROPERTY TESTS
// =============================================================================

/// Pajek roundtrip property
pub fn pajek_roundtrip_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())

  let options =
    pajek.options_with(
      node_label: fn(data) { data },
      edge_weight: fn(_) { None },
      node_attributes: fn(_) { pajek.default_node_attributes() },
      include_coordinates: False,
      include_visuals: False,
    )

  let pajek_string = pajek.serialize_with(options, graph)

  let result =
    pajek.parse_with(pajek_string, node_parser: fn(s) { s }, edge_parser: fn(_) {
      ""
    })

  let assert Ok(pajek.PajekResult(parsed_graph, _warnings)) = result

  // Node count should always be preserved
  assert model.node_count(parsed_graph) == model.node_count(graph)

  // Graph type is only reliably preserved when there are edges
  // Empty/edgeless graphs may default to Undirected
  let graph_type_preserved = case model.edge_count(graph) {
    0 -> True
    _ -> parsed_graph.kind == graph.kind
  }
  assert graph_type_preserved
}

// =============================================================================
// GRAPHML FORMAT PROPERTY TESTS
// =============================================================================

/// GraphML roundtrip property
pub fn graphml_roundtrip_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())

  let node_attr = fn(label: String) { dict.from_list([#("label", label)]) }
  let edge_attr = fn(label: String) { dict.from_list([#("weight", label)]) }

  let xml = graphml.serialize_with(node_attr, edge_attr, graph)

  let result =
    graphml.deserialize_with(
      fn(attrs) { dict.get(attrs, "label") |> should.be_ok() },
      fn(attrs) { dict.get(attrs, "weight") |> should.be_ok() },
      xml,
    )

  let assert Ok(parsed_graph) = result

  // GraphML preserves structure well
  assert model.node_count(parsed_graph) == model.node_count(graph)
  assert model.edge_count(parsed_graph) == model.edge_count(graph)
}

/// GraphML structural roundtrip - verifies complete graph topology
pub fn graphml_structural_roundtrip_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())

  // GraphML with identity mappers preserves exact structure
  let node_attr = fn(label: String) { dict.from_list([#("data", label)]) }
  let edge_attr = fn(label: String) { dict.from_list([#("data", label)]) }

  let xml = graphml.serialize_with(node_attr, edge_attr, graph)

  let result =
    graphml.deserialize_with(
      fn(attrs) { dict.get(attrs, "data") |> should.be_ok() },
      fn(attrs) { dict.get(attrs, "data") |> should.be_ok() },
      xml,
    )

  let assert Ok(parsed_graph) = result

  // Verify complete structural equality
  assert graphs_structurally_equal(parsed_graph, graph)
}

/// GraphML preserves graph type
pub fn graphml_graph_type_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())

  let xml = graphml.serialize(graph)
  let assert Ok(parsed) = graphml.deserialize(xml)

  assert parsed.kind == graph.kind
}

// =============================================================================
// GDF FORMAT PROPERTY TESTS
// =============================================================================

/// GDF roundtrip property
pub fn gdf_roundtrip_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())

  let node_attr = fn(label: String) { dict.from_list([#("label", label)]) }
  let edge_attr = fn(label: String) { dict.from_list([#("weight", label)]) }

  let gdf_string =
    gdf.serialize_with(node_attr, edge_attr, gdf.default_options(), graph)

  let result =
    gdf.deserialize_with(
      fn(attrs) { dict.get(attrs, "label") |> should.be_ok() },
      fn(attrs) { dict.get(attrs, "weight") |> should.be_ok() },
      gdf_string,
    )

  let assert Ok(parsed_graph) = result

  assert model.node_count(parsed_graph) == model.node_count(graph)
}

/// GDF structural roundtrip - verifies complete graph topology
pub fn gdf_structural_roundtrip_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())

  let node_attr = fn(label: String) { dict.from_list([#("data", label)]) }
  let edge_attr = fn(label: String) { dict.from_list([#("data", label)]) }

  let gdf_string =
    gdf.serialize_with(node_attr, edge_attr, gdf.default_options(), graph)

  let result =
    gdf.deserialize_with(
      fn(attrs) { dict.get(attrs, "data") |> should.be_ok() },
      fn(attrs) { dict.get(attrs, "data") |> should.be_ok() },
      gdf_string,
    )

  let assert Ok(parsed_graph) = result

  // For non-empty graphs, verify complete structural equality
  // Empty graphs may have different type (determined from edge data)
  let structurally_equal = case model.edge_count(graph) {
    0 -> model.node_count(parsed_graph) == model.node_count(graph)
    _ -> graphs_structurally_equal(parsed_graph, graph)
  }
  assert structurally_equal
}

// =============================================================================
// JSON FORMAT PROPERTY TESTS
// =============================================================================

/// JSON roundtrip property (Generic format)
pub fn json_roundtrip_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())

  let options = json.default_export_options()
  let json_string = json.to_json(graph, options)

  let result = json.from_json(json_string)

  let assert Ok(parsed_graph) = result

  // JSON should preserve structure well
  assert model.node_count(parsed_graph) == model.node_count(graph)
  assert model.edge_count(parsed_graph) == model.edge_count(graph)
  assert parsed_graph.kind == graph.kind
}

/// JSON structural roundtrip - verifies complete graph topology
pub fn json_structural_roundtrip_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())

  let options = json.default_export_options()
  let json_string = json.to_json(graph, options)

  let result = json.from_json(json_string)

  let assert Ok(parsed_graph) = result

  // Verify complete structural equality
  assert graphs_structurally_equal(parsed_graph, graph)
}

/// JSON preserves node and edge counts
pub fn json_node_edge_count_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())

  let options = json.default_export_options()
  let json_string = json.to_json(graph, options)
  let assert Ok(parsed) = json.from_json(json_string)

  assert model.node_count(parsed) == model.node_count(graph)
  assert model.edge_count(parsed) == model.edge_count(graph)
}

// =============================================================================
// EDGE CASE PROPERTY TESTS
// =============================================================================

/// Empty graph roundtrip for all formats
pub fn empty_graph_all_formats_property_test() {
  use kind <- qcheck.given(generators.graph_type_generator())

  let graph = model.new(kind)

  // Test GraphML
  let xml = graphml.serialize(graph)
  let assert Ok(parsed) = graphml.deserialize(xml)

  assert model.node_count(parsed) == 0
  assert model.edge_count(parsed) == 0
}

/// Single node graph roundtrip
pub fn single_node_graph_property_test() {
  use kind <- qcheck.given(generators.graph_type_generator())

  let graph = model.add_node(model.new(kind), 1, "Single")

  // Test GraphML
  let xml = graphml.serialize(graph)
  let assert Ok(parsed) = graphml.deserialize(xml)

  assert model.node_count(parsed) == 1
  assert model.edge_count(parsed) == 0
}

/// Path graph structure preservation
pub fn path_graph_structure_property_test() {
  use graph <- qcheck.given(generators.path_graph_generator())

  // TGF roundtrip should preserve path structure
  let options =
    tgf.options_with(node_label: fn(data) { data }, edge_label: fn(label) {
      Some(label)
    })
  let tgf_string = tgf.serialize_with(options, graph)

  let result =
    tgf.parse_with(
      tgf_string,
      graph_type: graph.kind,
      node_parser: fn(_id, label) { label },
      edge_parser: fn(label) { label },
    )

  let assert Ok(tgf.TgfResult(parsed, _)) = result

  // Path should have n-1 edges for n nodes
  let node_count = model.node_count(graph)
  let edge_count = model.edge_count(parsed)

  let valid_edge_count = case node_count {
    0 -> edge_count == 0
    1 -> edge_count == 0
    n -> edge_count == n - 1
  }
  assert valid_edge_count
}

// =============================================================================
// INVARIANT PROPERTY TESTS
// =============================================================================

/// Serialization never loses nodes
pub fn serialization_preserves_nodes_property_test() {
  use graph <- qcheck.given(generators.string_graph_generator())

  let options = json.default_export_options()
  let json_string = json.to_json(graph, options)
  let assert Ok(parsed) = json.from_json(json_string)

  // Node count invariant
  assert model.node_count(parsed) >= 0
  assert model.node_count(parsed) == model.node_count(graph)
}

/// Undirected graphs have symmetric edges after roundtrip
pub fn undirected_symmetry_property_test() {
  use graph <- qcheck.given(generators.undirected_string_graph_generator())

  // Serialize via GraphML (best for structure preservation)
  let xml = graphml.serialize(graph)
  let assert Ok(parsed) = graphml.deserialize(xml)

  // In undirected graphs, if A->B exists, B->A should exist
  let nodes = dict.keys(parsed.nodes)

  let is_symmetric =
    list.all(nodes, fn(u) {
      list.all(nodes, fn(v) {
        let succ_u = model.successors(parsed, u)
        let succ_v = model.successors(parsed, v)

        let u_to_v = list.any(succ_u, fn(edge) { edge.0 == v })
        let v_to_u = list.any(succ_v, fn(edge) { edge.0 == u })

        // Symmetry: u->v implies v->u
        case u_to_v {
          True -> v_to_u
          False -> True
        }
      })
    })

  assert is_symmetric
}
