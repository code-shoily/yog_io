import gleam/dict
import gleam/io
import gleam/json
import gleam/option
import yog/model
import yog_io/json as yog_json

pub type Person {
  Person(name: String, age: Int, role: String)
}

pub fn main() {
  // Create a simple social network graph
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
    |> model.add_node(3, "Carol")
    |> model.add_node(4, "Dave")

  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "follows")
  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 3, with: "follows")
  let assert Ok(graph) = model.add_edge(graph, from: 2, to: 3, with: "follows")
  let assert Ok(graph) = model.add_edge(graph, from: 3, to: 4, with: "follows")

  io.println("\n=== JSON Export Examples ===\n")

  // Example 1: Generic format with metadata
  io.println("1. Generic format with metadata:")
  let generic_json = yog_json.to_json(graph, yog_json.default_export_options())
  io.println(generic_json)
  io.println("")

  // Example 2: D3.js force-directed format
  io.println("2. D3.js force-directed format:")
  let d3_options =
    yog_json.JsonExportOptions(
      format: yog_json.D3Force,
      include_metadata: False,
      node_serializer: option.Some(json.string),
      edge_serializer: option.Some(json.string),
      pretty: True,
      metadata: option.None,
    )
  let d3_json = yog_json.to_json(graph, d3_options)
  io.println(d3_json)
  io.println("")

  // Example 3: Cytoscape.js format
  io.println("3. Cytoscape.js format:")
  let cyto_json = yog_json.to_cytoscape_json(graph, json.string, json.string)
  io.println(cyto_json)
  io.println("")

  // Example 4: vis.js format
  io.println("4. vis.js format:")
  let visjs_json = yog_json.to_visjs_json(graph, json.string, json.string)
  io.println(visjs_json)
  io.println("")

  // Example 5: NetworkX format
  io.println("5. NetworkX format:")
  let nx_options =
    yog_json.JsonExportOptions(
      format: yog_json.NetworkX,
      include_metadata: False,
      node_serializer: option.Some(json.string),
      edge_serializer: option.Some(json.string),
      pretty: True,
      metadata: option.None,
    )
  let nx_json = yog_json.to_json(graph, nx_options)
  io.println(nx_json)
  io.println("")

  // Example 6: Export to file
  io.println("6. Exporting to files...")
  case
    yog_json.to_json_file(
      graph,
      "output/graph.json",
      yog_json.default_export_options(),
    )
  {
    Ok(_) -> io.println("✓ Saved to output/graph.json")
    Error(e) -> io.println("✗ Error: " <> yog_json.error_to_string(e))
  }

  case yog_json.to_json_file(graph, "output/graph-d3.json", d3_options) {
    Ok(_) -> io.println("✓ Saved to output/graph-d3.json")
    Error(e) -> io.println("✗ Error: " <> yog_json.error_to_string(e))
  }

  // Example 6b: Using write() and write_with() convenience functions
  io.println("\n6b. Using write() and write_with() convenience functions...")
  case yog_json.write("output/graph-write.json", graph) {
    Ok(_) -> io.println("✓ Saved using write() to output/graph-write.json")
    Error(e) -> io.println("✗ Error: " <> yog_json.error_to_string(e))
  }

  case
    yog_json.write_with("output/graph-write-custom.json", d3_options, graph)
  {
    Ok(_) ->
      io.println("✓ Saved using write_with() to output/graph-write-custom.json")
    Error(e) -> io.println("✗ Error: " <> yog_json.error_to_string(e))
  }

  // Example 7: Custom types with serializers
  io.println("\n7. Custom types with serializers:")

  let custom_graph =
    model.new(model.Directed)
    |> model.add_node(1, Person("Alice", 30, "Engineer"))
    |> model.add_node(2, Person("Bob", 25, "Designer"))
    |> model.add_node(3, Person("Carol", 28, "Manager"))

  let assert Ok(custom_graph) =
    model.add_edge(custom_graph, from: 1, to: 2, with: 5)
  let assert Ok(custom_graph) =
    model.add_edge(custom_graph, from: 2, to: 3, with: 3)

  let custom_options =
    yog_json.export_options_with(
      fn(person: Person) {
        json.object([
          #("name", json.string(person.name)),
          #("age", json.int(person.age)),
          #("role", json.string(person.role)),
        ])
      },
      fn(weight) { json.int(weight) },
    )

  let custom_json = yog_json.to_json(custom_graph, custom_options)
  io.println(custom_json)
  io.println("")

  // Example 8: With custom metadata
  io.println("8. With custom metadata:")
  let metadata =
    dict.from_list([
      #("description", json.string("Social Network Graph")),
      #("version", json.string("1.0")),
      #("created_by", json.string("yog_io example")),
      #(
        "tags",
        json.array([json.string("social"), json.string("network")], of: fn(x) {
          x
        }),
      ),
    ])

  let metadata_options =
    yog_json.JsonExportOptions(
      ..yog_json.default_export_options(),
      metadata: option.Some(metadata),
    )

  let metadata_json = yog_json.to_json(graph, metadata_options)
  io.println(metadata_json)
  io.println("")

  io.println("=== All examples completed! ===")
}
