import gleam/dict
import gleam/float
import gleam/int
import gleam/string
import gleeunit/should
import simplifile
import yog/model.{Directed}
import yog_io/graphml.{DoubleType, IntType, StringType}

pub fn serialize_with_types_test() {
  // Create a graph with various attribute types
  let graph =
    model.new(Directed)
    |> model.add_node(1, #("Alice", 30, 85.5))
    |> model.add_node(2, #("Bob", 25, 92.3))
    |> model.add_node(3, #("Charlie", 35, 78.9))

  let assert Ok(graph) =
    model.add_edges(graph, [
      #(1, 2, 5.0),
      #(2, 3, 10.0),
      #(1, 3, 3.5),
    ])

  // Map node data to typed attributes
  let node_attrs = fn(person: #(String, Int, Float)) {
    let #(name, age, score) = person
    dict.from_list([
      #("label", #(name, StringType)),
      #("age", #(int.to_string(age), IntType)),
      #("score", #(float.to_string(score), DoubleType)),
    ])
  }

  // Map edge data to typed attributes
  let edge_attrs = fn(weight: Float) {
    dict.from_list([#("weight", #(float.to_string(weight), DoubleType))])
  }

  // Serialize with types
  let xml = graphml.serialize_with_types(node_attrs, edge_attrs, graph)

  // Verify that types are correctly specified
  xml
  |> string.contains("attr.type=\"string\"")
  |> should.be_true()

  xml
  |> string.contains("attr.type=\"int\"")
  |> should.be_true()

  xml
  |> string.contains("attr.type=\"double\"")
  |> should.be_true()

  // Verify node attributes
  xml
  |> string.contains("<data key=\"label\">Alice</data>")
  |> should.be_true()

  xml
  |> string.contains("<data key=\"age\">30</data>")
  |> should.be_true()

  // Verify edge attributes
  xml
  |> string.contains("<data key=\"weight\">5.0</data>")
  |> should.be_true()
}

pub fn generate_gephi_sample_test() {
  // Create a realistic social network graph
  let graph =
    model.new(Directed)
    |> model.add_node(1, #("Alice", 30, 0.85, True))
    |> model.add_node(2, #("Bob", 25, 0.92, True))
    |> model.add_node(3, #("Charlie", 35, 0.78, False))
    |> model.add_node(4, #("Diana", 28, 0.95, True))

  let assert Ok(graph) =
    model.add_edges(graph, [
      #(1, 2, 5.0),
      #(2, 3, 10.0),
      #(1, 3, 3.5),
      #(2, 4, 7.2),
      #(3, 4, 2.1),
    ])

  // Map to Gephi-friendly attributes
  let node_attrs = fn(person: #(String, Int, Float, Bool)) {
    let #(name, age, influence, active) = person
    dict.from_list([
      #("label", #(name, StringType)),
      #("age", #(int.to_string(age), IntType)),
      #("influence", #(float.to_string(influence), DoubleType)),
      #("active", #(
        case active {
          True -> "true"
          False -> "false"
        },
        graphml.BooleanType,
      )),
    ])
  }

  let edge_attrs = fn(weight: Float) {
    dict.from_list([#("weight", #(float.to_string(weight), DoubleType))])
  }

  let xml = graphml.serialize_with_types(node_attrs, edge_attrs, graph)

  // Write to a file for manual Gephi testing
  let path = "/tmp/gephi_test_graph.graphml"
  let assert Ok(Nil) = simplifile.write(path, xml)

  // Verify file was created
  simplifile.is_file(path)
  |> should.be_ok()
  |> should.be_true()

  Nil
}
