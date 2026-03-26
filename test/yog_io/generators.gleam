//// Generators for property-based testing of graph serialization.
////
//// Provides qcheck generators for creating random graphs with various
//// properties for testing roundtrip serialization.

import gleam/int
import gleam/list
import qcheck
import yog/model.{type Graph, type GraphType, Directed, Undirected}

/// Generate a random GraphType (Directed or Undirected)
pub fn graph_type_generator() {
  use is_directed <- qcheck.map(qcheck.bool())
  case is_directed {
    True -> Directed
    False -> Undirected
  }
}

/// Generate a small random graph with String node/edge data
/// Suitable for most format tests (TGF, GraphML, GDF, etc.)
pub fn string_graph_generator() {
  use kind <- qcheck.bind(graph_type_generator())
  use num_nodes <- qcheck.bind(qcheck.bounded_int(0, 10))
  use num_edges <- qcheck.bind(qcheck.bounded_int(0, 20))

  string_graph_generator_custom(kind, num_nodes, num_edges)
}

/// Generate a graph with String data and specific parameters
pub fn string_graph_generator_custom(
  kind: GraphType,
  num_nodes: Int,
  num_edges: Int,
) -> qcheck.Generator(Graph(String, String)) {
  use edges <- qcheck.map(qcheck.fixed_length_list_from(
    string_edge_generator(num_nodes),
    num_edges,
  ))

  // Build graph with String labels
  let graph = model.new(kind)
  let graph = build_string_nodes(graph, 1, num_nodes)

  let valid_edges = case num_nodes {
    0 -> []
    _ ->
      edges
      |> list.filter(fn(edge) {
        let #(src, dst, _) = edge
        src >= 1 && src <= num_nodes && dst >= 1 && dst <= num_nodes
      })
  }

  valid_edges
  |> list.fold(graph, fn(g, edge) {
    let #(src, dst, label) = edge
    let assert Ok(g) = model.add_edge(g, from: src, to: dst, with: label)
    g
  })
}

fn build_string_nodes(
  graph: Graph(String, e),
  current: Int,
  max: Int,
) -> Graph(String, e) {
  case current > max {
    True -> graph
    False ->
      build_string_nodes(
        model.add_node(graph, current, "Node" <> int.to_string(current)),
        current + 1,
        max,
      )
  }
}

/// Generate an edge with String label
pub fn string_edge_generator(num_nodes: Int) {
  case num_nodes {
    0 -> qcheck.return(#(1, 1, "edge"))
    _ -> {
      use src <- qcheck.bind(qcheck.bounded_int(1, num_nodes))
      use dst <- qcheck.bind(qcheck.bounded_int(1, num_nodes))
      use label_idx <- qcheck.map(qcheck.bounded_int(1, 100))
      #(src, dst, "edge_" <> int.to_string(label_idx))
    }
  }
}

/// Generate a small directed graph with String data
pub fn directed_string_graph_generator() {
  use num_nodes <- qcheck.bind(qcheck.bounded_int(0, 10))
  use num_edges <- qcheck.bind(qcheck.bounded_int(0, 20))
  string_graph_generator_custom(Directed, num_nodes, num_edges)
}

/// Generate a small undirected graph with String data
pub fn undirected_string_graph_generator() {
  use num_nodes <- qcheck.bind(qcheck.bounded_int(0, 10))
  use num_edges <- qcheck.bind(qcheck.bounded_int(0, 20))
  string_graph_generator_custom(Undirected, num_nodes, num_edges)
}

/// Generate a graph suitable for JSON testing (with metadata)
pub fn json_graph_generator() {
  string_graph_generator()
}

/// Generate a simple path graph: 1 -> 2 -> 3 -> ... -> n
pub fn path_graph_generator() {
  use kind <- qcheck.bind(graph_type_generator())
  use length <- qcheck.map(qcheck.bounded_int(1, 10))

  case length {
    0 -> model.new(kind)
    1 -> {
      // Single node, no edges
      let graph = model.new(kind)
      model.add_node(graph, 1, "Node1")
    }
    _ -> {
      // Multiple nodes with path edges
      let graph = model.new(kind)
      let graph = model.add_node(graph, 1, "Node1")

      // Add remaining nodes and edges
      int.range(from: 2, to: length, with: graph, run: fn(g, id) {
        let g = model.add_node(g, id, "Node" <> int.to_string(id))
        let assert Ok(g) = model.add_edge(g, from: id - 1, to: id, with: "path")
        g
      })
    }
  }
}

/// Generate a star graph: center node connected to all others
pub fn star_graph_generator() {
  use kind <- qcheck.bind(graph_type_generator())
  use size <- qcheck.map(qcheck.bounded_int(2, 8))

  let center = 1
  let graph = model.new(kind)
  let graph =
    int.range(from: 1, to: size, with: graph, run: fn(g, id) {
      model.add_node(g, id, "Node" <> int.to_string(id))
    })

  int.range(from: 2, to: size, with: graph, run: fn(g, leaf) {
    let assert Ok(g) = model.add_edge(g, from: center, to: leaf, with: "spoke")
    g
  })
}

/// Generate an empty graph
pub fn empty_graph_generator() {
  use kind <- qcheck.map(graph_type_generator())
  model.new(kind)
}

/// Generate a graph with single node
pub fn single_node_graph_generator() {
  use kind <- qcheck.map(graph_type_generator())
  model.add_node(model.new(kind), 1, "Single")
}
