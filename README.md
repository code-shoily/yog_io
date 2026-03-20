# yog_io

[![Package Version](https://img.shields.io/hexpm/v/yog_io)](https://hex.pm/packages/yog_io)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/yog_io/)

Graph file format I/O for the [yog](https://hex.pm/packages/yog) graph library. Provides serialization and deserialization support for popular graph file formats including GraphML and GDF.

## Features

- **GraphML Support** - Full XML-based graph format support compatible with Gephi, yEd, Cytoscape, and NetworkX
- **GDF Support** - Simple CSV-like format used by Gephi and GUESS
- **Custom Attributes** - Map your domain types to graph attributes with custom mappers
- **JS Compatible** - Uses `xmlm` for XML parsing and `simplifile` for file operations
- **Type Safe** - Leverages Gleam's type system for safe graph serialization

## Installation

Add `yog_io` to your Gleam project:

```sh
gleam add yog_io
```

## Quick Start

```gleam
import yog/model.{Directed}
import yog_io

pub fn main() {
  // Create a graph
  let graph =
    model.new(Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
    |> model.add_node(3, "Charlie")

  let assert Ok(graph) =
    model.add_edges(graph, [
      #(1, 2, "friend"),
      #(2, 3, "colleague"),
    ])

  // Write to GraphML
  let assert Ok(Nil) = yog_io.write_graphml("graph.graphml", graph)

  // Read from GraphML
  let assert Ok(loaded) = yog_io.read_graphml("graph.graphml")

  // Or use GDF format
  let assert Ok(Nil) = yog_io.write_gdf("graph.gdf", graph)
  let assert Ok(loaded_gdf) = yog_io.read_gdf("graph.gdf")
}
```

## Usage

### GraphML Format

GraphML is an XML-based format widely supported by graph visualization tools.

```gleam
import yog/model.{Directed}
import yog_io/graphml

// Basic serialization for String graphs
let graph =
  model.new(Directed)
  |> model.add_node(1, "Alice")
  |> model.add_node(2, "Bob")

let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "5")

// Serialize to GraphML XML string
let xml = graphml.serialize(graph)

// Write to file
let assert Ok(Nil) = graphml.write("graph.graphml", graph)

// Read from file
let assert Ok(loaded) = graphml.read("graph.graphml")
```

#### Custom Types with GraphML

Use custom attribute mappers to serialize your domain types:

```gleam
import gleam/dict
import yog/model.{Directed}
import yog_io/graphml

// Define your domain types
type Person {
  Person(name: String, age: Int, role: String)
}

type Relationship {
  Relationship(kind: String, strength: Int)
}

// Create a graph with custom types
let graph =
  model.new(Directed)
  |> model.add_node(1, Person("Alice", 30, "Engineer"))
  |> model.add_node(2, Person("Bob", 25, "Designer"))

let assert Ok(graph) =
  model.add_edge(
    graph,
    from: 1,
    to: 2,
    with: Relationship("friend", 8),
  )

// Define attribute mappers
let node_attr = fn(person: Person) {
  dict.from_list([
    ("name", person.name),
    ("age", int.to_string(person.age)),
    ("role", person.role),
  ])
}

let edge_attr = fn(rel: Relationship) {
  dict.from_list([
    ("kind", rel.kind),
    ("strength", int.to_string(rel.strength)),
  ])
}

// Serialize with custom mappers
let xml = graphml.serialize_with(node_attr, edge_attr, graph)

// Deserialize with custom mappers
let node_folder = fn(attrs) {
  Person(
    name: dict.get(attrs, "name") |> result.unwrap(""),
    age: dict.get(attrs, "age")
      |> result.unwrap("0")
      |> int.parse
      |> result.unwrap(0),
    role: dict.get(attrs, "role") |> result.unwrap(""),
  )
}

let edge_folder = fn(attrs) {
  Relationship(
    kind: dict.get(attrs, "kind") |> result.unwrap(""),
    strength: dict.get(attrs, "strength")
      |> result.unwrap("0")
      |> int.parse
      |> result.unwrap(0),
  )
}

let assert Ok(loaded) =
  graphml.deserialize_with(node_folder, edge_folder, xml)
```

### GDF Format

GDF (GUESS Graph Format) is a simple CSV-like format with separate sections for nodes and edges.

```gleam
import yog/model.{Directed}
import yog_io/gdf

// Basic serialization for String graphs
let graph =
  model.new(Directed)
  |> model.add_node(1, "Alice")
  |> model.add_node(2, "Bob")

let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "friend")

// Serialize to GDF string
let gdf_string = gdf.serialize(graph)

// Serialize with integer weights
let weighted_graph =
  model.new(Directed)
  |> model.add_node(1, "A")
  |> model.add_node(2, "B")

let assert Ok(weighted_graph) =
  model.add_edge(weighted_graph, from: 1, to: 2, with: 42)

let gdf_weighted = gdf.serialize_weighted(weighted_graph)

// Write to file
let assert Ok(Nil) = gdf.write("graph.gdf", graph)

// Read from file
let assert Ok(loaded) = gdf.read("graph.gdf")
```

#### GDF Output Format

```gdf
nodedef>name VARCHAR,label VARCHAR
1,Alice
2,Bob
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR
1,2,true,friend
```

#### Custom Options for GDF

```gleam
import yog_io/gdf

// Customize separator and type annotations
let options = gdf.GdfOptions(
  separator: ";",
  include_types: False,
  include_directed: Some(True),
)

let gdf_string = gdf.serialize_with(node_attr, edge_attr, options, graph)
```

## Module Overview

| Module | Purpose |
|--------|---------|
| `yog_io` | Convenience functions for common operations |
| `yog_io/graphml` | Full GraphML support with custom mappers |
| `yog_io/gdf` | Full GDF support with custom mappers |

## Format Support

### GraphML

- ✅ Nodes with custom attributes
- ✅ Edges with custom attributes
- ✅ Directed and undirected graphs
- ✅ XML escaping
- ✅ Custom serialization options

### GDF

- ✅ Nodes with custom attributes
- ✅ Edges with custom attributes
- ✅ Directed and undirected graphs
- ✅ CSV-style escaping (quotes, separators)
- ✅ Custom separators and type annotations
- ✅ Weighted graph convenience functions

## File Format Examples

### GraphML Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns">
  <key id="label" for="node" attr.name="label" attr.type="string"/>
  <key id="weight" for="edge" attr.name="weight" attr.type="string"/>
  <graph id="G" edgedefault="directed">
    <node id="1">
      <data key="label">Alice</data>
    </node>
    <node id="2">
      <data key="label">Bob</data>
    </node>
    <edge source="1" target="2">
      <data key="weight">friend</data>
    </edge>
  </graph>
</graphml>
```

### GDF Example

```gdf
nodedef>name VARCHAR,label VARCHAR
1,Alice
2,Bob
edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR
1,2,true,friend
```

## Development

```sh
# Run tests
gleam test

# Run specific test module
gleam test yog_io/graphml_test
gleam test yog_io/gdf_test

# Build documentation
gleam docs
```

## References

- [GraphML Specification](http://graphml.graphdrawing.org/specification.html)
- [GDF Format](https://gephi.org/users/supported-graph-formats/gdf-format/)
- [yog Graph Library](https://hex.pm/packages/yog)

## License

Apache-2.0
