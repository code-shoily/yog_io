import gleam/dict
import gleam/list
import gleeunit/should
import yog/model.{Directed, Undirected}
import yog_io/matrix as matrix_io

pub fn from_matrix_directed_test() {
  let matrix = [[0.0, 1.0, 2.0], [3.0, 0.0, 4.0], [5.0, 6.0, 0.0]]
  let assert Ok(graph) = matrix_io.from_matrix(Directed, matrix)

  dict.size(graph.nodes) |> should.equal(3)
  model.edge_count(graph) |> should.equal(6)

  let succ0 = model.successors(graph, 0)
  list.key_find(succ0, 1) |> should.equal(Ok(1.0))
  list.key_find(succ0, 2) |> should.equal(Ok(2.0))
}

pub fn from_matrix_undirected_test() {
  // Symmetric matrix
  let matrix = [[0.0, 1.0, 2.0], [1.0, 0.0, 3.0], [2.0, 3.0, 0.0]]
  let assert Ok(graph) = matrix_io.from_matrix(Undirected, matrix)

  dict.size(graph.nodes) |> should.equal(3)
  model.edge_count(graph) |> should.equal(3)

  let succ0 = model.successors(graph, 0)
  list.key_find(succ0, 1) |> should.equal(Ok(1.0))
  list.key_find(succ0, 2) |> should.equal(Ok(2.0))
}

pub fn to_matrix_directed_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(0, Nil)
    |> model.add_node(1, Nil)
  let assert Ok(graph) = model.add_edge(graph, from: 0, to: 1, with: 1.0)

  let #(_, matrix) = matrix_io.to_matrix(graph)
  matrix |> should.equal([[0.0, 1.0], [0.0, 0.0]])
}

pub fn from_string_matrix_test() {
  let content = "0 1\n2 3"
  let assert Ok(matrix) = matrix_io.from_string(content)
  matrix |> should.equal([[0.0, 1.0], [2.0, 3.0]])
}
