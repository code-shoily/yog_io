/// Example: Creating Gephi-compatible GraphML files with typed attributes
///
/// This example demonstrates how to create graphs with properly typed attributes
/// that work seamlessly with Gephi for visualization and analysis.
import gleam/dict
import gleam/float
import gleam/int
import yog/model.{Directed}
import yog_io/graphml.{DoubleType, IntType, StringType}

pub fn main() {
  // Create a social network graph
  let graph =
    model.new(Directed)
    |> model.add_node(1, Person("Alice", 30, 0.85))
    |> model.add_node(2, Person("Bob", 25, 0.92))
    |> model.add_node(3, Person("Charlie", 35, 0.78))

  let assert Ok(graph) =
    model.add_edges(graph, [
      #(1, 2, Connection(5.0, "friend")),
      #(2, 3, Connection(10.0, "colleague")),
      #(1, 3, Connection(3.5, "acquaintance")),
    ])

  // Define how to convert your domain types to typed GraphML attributes
  let node_attrs = fn(person: Person) {
    dict.from_list([
      #("label", #(person.name, StringType)),
      #("age", #(int.to_string(person.age), IntType)),
      #("influence", #(float.to_string(person.influence), DoubleType)),
    ])
  }

  let edge_attrs = fn(conn: Connection) {
    dict.from_list([
      #("weight", #(float.to_string(conn.weight), DoubleType)),
      #("relationship", #(conn.relationship, StringType)),
    ])
  }

  // Write to file with proper types for Gephi
  let assert Ok(Nil) =
    graphml.write_with_types(
      "output/social_network.graphml",
      node_attrs,
      edge_attrs,
      graph,
    )
  // Now you can:
  // 1. Open output/social_network.graphml in Gephi
  // 2. Use "age" and "influence" for numeric visualizations (size nodes by influence)
  // 3. Use "weight" for weighted layouts (ForceAtlas2 with edge weights)
  // 4. Filter nodes by age range
  // 5. Run statistics on numeric attributes
}

type Person {
  Person(name: String, age: Int, influence: Float)
}

type Connection {
  Connection(weight: Float, relationship: String)
}
