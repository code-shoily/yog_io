import gleam/dict
import gleeunit
import gleeunit/should
import simplifile
import yog/model.{Directed, Undirected}
import yog_io/gdf
import yog_io/graphml
import yog_io/json
import yog_io/leda
import yog_io/list as list_io
import yog_io/matrix as matrix_io
import yog_io/matrix_market as mtx_io
import yog_io/pajek
import yog_io/tgf

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// SAMPLE READ TESTS
// =============================================================================

pub fn read_gdf_sample_test() {
  let path = "test/yog_io/samples/sample.gdf"
  let assert Ok(graph) = gdf.read(path)

  dict.size(graph.nodes) |> should.equal(2)
  let node1 = dict.get(graph.nodes, 1) |> should.be_ok()
  dict.get(node1, "label") |> should.equal(Ok("Alice"))

  let succ = model.successors(graph, 1)
  let assert Ok(#(dst, edge_data)) = case succ {
    [first, ..] -> Ok(first)
    [] -> Error(Nil)
  }
  dst |> should.equal(2)
  dict.get(edge_data, "label") |> should.equal(Ok("friend"))
}

pub fn read_graphml_sample_test() {
  let path = "test/yog_io/samples/sample.graphml"
  let assert Ok(graph) = graphml.read(path)

  dict.size(graph.nodes) |> should.equal(2)
  let node1 = dict.get(graph.nodes, 1) |> should.be_ok()
  dict.get(node1, "label") |> should.equal(Ok("Alice"))

  let succ = model.successors(graph, 1)
  let assert Ok(#(dst, edge_data)) = case succ {
    [first, ..] -> Ok(first)
    [] -> Error(Nil)
  }
  dst |> should.equal(2)
  dict.get(edge_data, "weight") |> should.equal(Ok("friend"))
}

pub fn read_leda_sample_test() {
  let path = "test/yog_io/samples/sample.leda"
  let assert Ok(content) = simplifile.read(path)
  let assert Ok(result) = leda.parse(content)
  let graph = result.graph

  dict.size(graph.nodes) |> should.equal(2)
  dict.get(graph.nodes, 1) |> should.be_ok() |> should.equal("Alice")

  model.edge_count(graph) |> should.equal(1)
  let succ = model.successors(graph, 1)
  let assert Ok(#(dst, edge_data)) = case succ {
    [first, ..] -> Ok(first)
    [] -> Error(Nil)
  }
  dst |> should.equal(2)
  edge_data |> should.equal("friend")
}

pub fn read_pajek_sample_test() {
  let path = "test/yog_io/samples/sample.pajek"
  let assert Ok(content) = simplifile.read(path)
  let assert Ok(result) = pajek.parse(content)
  let graph = result.graph

  dict.size(graph.nodes) |> should.equal(2)
  dict.get(graph.nodes, 1) |> should.be_ok() |> should.equal("Alice")

  model.edge_count(graph) |> should.equal(1)
  let succ = model.successors(graph, 1)
  let assert Ok(#(dst, _)) = case succ {
    [first, ..] -> Ok(first)
    [] -> Error(Nil)
  }
  dst |> should.equal(2)
}

pub fn read_tgf_sample_test() {
  let path = "test/yog_io/samples/sample.tgf"
  let assert Ok(content) = simplifile.read(path)
  let assert Ok(result) = tgf.parse(content, Directed)
  let graph = result.graph

  dict.size(graph.nodes) |> should.equal(2)
  dict.get(graph.nodes, 1) |> should.be_ok() |> should.equal("Alice")

  model.edge_count(graph) |> should.equal(1)
  let succ = model.successors(graph, 1)
  let assert Ok(#(dst, edge_data)) = case succ {
    [first, ..] -> Ok(first)
    [] -> Error(Nil)
  }
  dst |> should.equal(2)
  edge_data |> should.equal("friend")
}

pub fn read_json_sample_test() {
  let path = "test/yog_io/samples/sample.json"
  let assert Ok(graph) = json.read(path)

  dict.size(graph.nodes) |> should.equal(2)
  dict.get(graph.nodes, 1) |> should.be_ok() |> should.equal("Alice")

  model.edge_count(graph) |> should.equal(1)
  let succ = model.successors(graph, 1)
  let assert Ok(#(dst, edge_data)) = case succ {
    [first, ..] -> Ok(first)
    [] -> Error(Nil)
  }
  dst |> should.equal(2)
  edge_data |> should.equal("friend")
}

pub fn read_list_sample_test() {
  let path = "test/yog_io/samples/sample.list"
  let assert Ok(graph) = list_io.read(path, Directed)

  dict.size(graph.nodes) |> should.equal(2)
  model.edge_count(graph) |> should.equal(1)
}

pub fn read_mtx_sample_test() {
  let path = "test/yog_io/samples/sample.mtx"
  let assert Ok(result) = mtx_io.read(path)

  dict.size(result.graph.nodes) |> should.equal(3)
  model.edge_count(result.graph) |> should.equal(2)
}

pub fn read_matrix_sample_test() {
  let path = "test/yog_io/samples/sample.mat"
  let assert Ok(graph) = matrix_io.read(path, Undirected)

  dict.size(graph.nodes) |> should.equal(2)
  model.edge_count(graph) |> should.equal(1)
}

// =============================================================================
// WRITE TESTS
// =============================================================================

fn create_test_graph() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "friend")
  graph
}

pub fn write_gdf_test() {
  let path = "/tmp/write_test.gdf"
  let graph = create_test_graph()

  let assert Ok(Nil) = gdf.write(path, graph)
  let assert Ok(loaded) = gdf.read(path)

  dict.size(loaded.nodes) |> should.equal(2)
  let _ = simplifile.delete(path)
}

pub fn write_graphml_test() {
  let path = "/tmp/write_test.graphml"
  let graph = create_test_graph()

  let assert Ok(Nil) = graphml.write(path, graph)
  let assert Ok(loaded) = graphml.read(path)

  dict.size(loaded.nodes) |> should.equal(2)
  let _ = simplifile.delete(path)
}

pub fn write_json_test() {
  let path = "/tmp/write_test.json"
  let graph = create_test_graph()

  let assert Ok(Nil) = json.write(path, graph)
  let assert Ok(loaded) = json.read(path)

  dict.size(loaded.nodes) |> should.equal(2)
  dict.get(loaded.nodes, 1) |> should.be_ok() |> should.equal("Alice")

  let _ = simplifile.delete(path)
}

pub fn write_leda_test() {
  let path = "/tmp/write_test.leda"
  let graph = create_test_graph()
  let exported = leda.serialize(graph)
  let assert Ok(Nil) = simplifile.write(to: path, contents: exported)

  let assert Ok(content) = simplifile.read(path)
  let assert Ok(result) = leda.parse(content)
  dict.size(result.graph.nodes) |> should.equal(2)

  let _ = simplifile.delete(path)
}

pub fn write_pajek_test() {
  let path = "/tmp/write_test.pajek"
  let graph = create_test_graph()
  let exported = pajek.serialize(graph)
  let assert Ok(Nil) = simplifile.write(to: path, contents: exported)

  let assert Ok(content) = simplifile.read(path)
  let assert Ok(result) = pajek.parse(content)
  dict.size(result.graph.nodes) |> should.equal(2)

  let _ = simplifile.delete(path)
}

pub fn write_tgf_test() {
  let path = "/tmp/write_test.tgf"
  let graph = create_test_graph()
  let exported = tgf.serialize(graph)
  let assert Ok(Nil) = simplifile.write(to: path, contents: exported)

  let assert Ok(content) = simplifile.read(path)
  let assert Ok(result) = tgf.parse(content, Directed)
  dict.size(result.graph.nodes) |> should.equal(2)

  let _ = simplifile.delete(path)
}

pub fn matrix_io_test() {
  let matrix = [[0.0, 1.0], [1.0, 0.0]]
  let assert Ok(graph) = matrix_io.from_matrix(Undirected, matrix)

  dict.size(graph.nodes) |> should.equal(2)
  model.edge_count(graph) |> should.equal(1)

  let #(_, exported) = matrix_io.to_matrix(graph)
  exported |> should.equal(matrix)

  let path = "/tmp/write_test.mat"
  let assert Ok(Nil) = matrix_io.write(path, graph)
  let assert Ok(loaded) = matrix_io.read(path, Undirected)
  dict.size(loaded.nodes) |> should.equal(2)
  let _ = simplifile.delete(path)
}
