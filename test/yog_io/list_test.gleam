import gleam/dict
import gleam/list
import gleeunit/should
import yog/model.{Directed}
import yog_io/list as list_io

pub fn from_string_unweighted_test() {
  let content = "1: 2 3\n2: 3\n3:"
  let assert Ok(graph) =
    list_io.from_string(content, Directed, list_io.default_options())

  dict.size(graph.nodes) |> should.equal(3)
  model.edge_count(graph) |> should.equal(3)
  model.successors(graph, 1) |> list.length() |> should.equal(2)
}

pub fn from_string_weighted_test() {
  let content = "1: 2,0.5 3,1.2\n2: 3,0.8\n3:"
  let options = list_io.ListOptions(weighted: True, delimiter: ":")
  let assert Ok(graph) = list_io.from_string(content, Directed, options)

  dict.size(graph.nodes) |> should.equal(3)
  model.edge_count(graph) |> should.equal(3)

  let succ1 = model.successors(graph, 1)
  let _ = case list.key_find(succ1, 2) {
    Ok(w) -> w |> should.equal(0.5)
    _ -> panic as "Edge not found"
  }
}

pub fn serialize_unweighted_test() {
  let graph =
    model.new(Directed)
    |> model.add_node(1, Nil)
    |> model.add_node(2, Nil)
  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: 1.0)

  let str = list_io.serialize(graph, list_io.default_options())
  str |> should.equal("1: 2\n2:")
}

pub fn from_string_comments_test() {
  let content = "# This is a comment\n1: 2\n\n2:"
  let assert Ok(graph) =
    list_io.from_string(content, Directed, list_io.default_options())
  dict.size(graph.nodes) |> should.equal(2)
}
