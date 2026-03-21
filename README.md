# yog_io

[![Package Version](https://img.shields.io/hexpm/v/yog_io)](https://hex.pm/packages/yog_io)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/yog_io/)

Graph file format I/O for the [yog](https://hex.pm/packages/yog) graph library. Provides serialization and deserialization support for popular graph file formats including GraphML, GDF, and JSON.

## Features

- **GraphML Support** - Full XML-based graph format support compatible with Gephi, yEd, Cytoscape, and NetworkX
- **Gephi-Optimized** - Typed attributes (int, double, boolean) for proper Gephi visualizations and analysis
- **GDF Support** - Simple CSV-like format used by Gephi and GUESS
- **JSON Support** - Multiple JSON formats for web visualization libraries (D3.js, Cytoscape.js, vis.js, NetworkX)
- **Generic Types** - Work with any node and edge data types using custom serializers
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

  // Or export to JSON for web visualization
  let assert Ok(Nil) = yog_io.write_json("graph.json", graph)
  let json_string = yog_io.to_json(graph)
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
import gleam/int
import gleam/result
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
    #("name", person.name),
    #("age", int.to_string(person.age)),
    #("role", person.role),
  ])
}

let edge_attr = fn(rel: Relationship) {
  dict.from_list([
    #("kind", rel.kind),
    #("strength", int.to_string(rel.strength)),
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
      |> int.parse()
      |> result.unwrap(0),
    role: dict.get(attrs, "role") |> result.unwrap(""),
  )
}

let edge_folder = fn(attrs) {
  Relationship(
    kind: dict.get(attrs, "kind") |> result.unwrap(""),
    strength: dict.get(attrs, "strength")
      |> result.unwrap("0")
      |> int.parse()
      |> result.unwrap(0),
  )
}

let assert Ok(loaded) =
  graphml.deserialize_with(node_folder, edge_folder, xml)
```

#### Gephi Compatibility

For use with [Gephi](https://gephi.org/), use typed attributes to enable proper numeric visualizations, weighted layouts, and statistical analysis:

```gleam
import gleam/dict
import gleam/float
import gleam/int
import yog/model.{Directed}
import yog_io/graphml.{DoubleType, IntType, StringType}

type Person {
  Person(name: String, age: Int, influence: Float)
}

let graph =
  model.new(Directed)
  |> model.add_node(1, Person("Alice", 30, 0.85))
  |> model.add_node(2, Person("Bob", 25, 0.92))

let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: 5.0)

// Map to typed attributes for Gephi
let node_attrs = fn(p: Person) {
  dict.from_list([
    #("label", #(p.name, StringType)),
    #("age", #(int.to_string(p.age), IntType)),
    #("influence", #(float.to_string(p.influence), DoubleType)),
  ])
}

let edge_attrs = fn(weight: Float) {
  dict.from_list([
    #("weight", #(float.to_string(weight), DoubleType)),
  ])
}

// Write with proper types for Gephi
let assert Ok(Nil) = graphml.write_with_types(
  "graph.graphml",
  node_attrs,
  edge_attrs,
  graph,
)
```

With typed attributes, Gephi can:
- Size/color nodes by numeric attributes (age, influence)
- Use edge weights in layouts (ForceAtlas2)
- Filter by numeric ranges
- Run statistical analysis

See [GEPHI.md](GEPHI.md) for complete Gephi compatibility guide.

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

### JSON Format

JSON format export for web visualization libraries and data exchange. Supports multiple format presets for popular visualization tools.

```gleam
import yog/model.{Directed}
import yog_io/json

// Basic serialization for String graphs
let assert Ok(graph) =
  model.new(Directed)
  |> model.add_node(1, "Alice")
  |> model.add_node(2, "Bob")
  |> model.add_edge(from: 1, to: 2, with: "follows")

// Export to JSON string with default options
let json_string = json.to_json(graph, json.default_export_options())

// Export to file
let assert Ok(Nil) = json.to_json_file(
  graph,
  "graph.json",
  json.default_export_options(),
)
```

#### Format Presets

The JSON module supports multiple format presets for different visualization libraries:

**D3.js Force-Directed Format**

```gleam
import gleam/json as gleam_json
import gleam/option

let d3_options = json.JsonExportOptions(
  format: json.D3Force,
  include_metadata: False,
  node_serializer: option.Some(gleam_json.string),
  edge_serializer: option.Some(gleam_json.string),
  pretty: True,
  metadata: option.None,
)

let d3_json = json.to_json(graph, d3_options)
// Or use the convenience function
let d3_json = json.to_d3_json(graph, gleam_json.string, gleam_json.string)
```

**Cytoscape.js Format**

```gleam
let cyto_json = json.to_cytoscape_json(graph, gleam_json.string, gleam_json.string)
```

**vis.js Format**

```gleam
let visjs_json = json.to_visjs_json(graph, gleam_json.string, gleam_json.string)
```

**NetworkX Format (Python compatibility)**

```gleam
let nx_options = json.JsonExportOptions(
  format: json.NetworkX,
  include_metadata: False,
  node_serializer: option.Some(gleam_json.string),
  edge_serializer: option.Some(gleam_json.string),
  pretty: True,
  metadata: option.None,
)

let nx_json = json.to_json(graph, nx_options)
```

#### Custom Types with JSON

Use custom serializers to export graphs with any data types:

```gleam
import gleam/dict
import gleam/json as gleam_json
import gleam/option

pub type Person {
  Person(name: String, age: Int, role: String)
}

let assert Ok(graph) =
  model.new(Directed)
  |> model.add_node(1, Person("Alice", 30, "Engineer"))
  |> model.add_node(2, Person("Bob", 25, "Designer"))
  |> model.add_edge(from: 1, to: 2, with: 5)

let options = json.export_options_with(
  fn(person: Person) {
    gleam_json.object([
      #("name", gleam_json.string(person.name)),
      #("age", gleam_json.int(person.age)),
      #("role", gleam_json.string(person.role)),
    ])
  },
  fn(weight) { gleam_json.int(weight) },
)

let json_string = json.to_json(graph, options)
```

#### JSON with Metadata

Add custom metadata to your JSON exports:

```gleam
import gleam/dict

let metadata = dict.from_list([
  #("description", gleam_json.string("Social Network")),
  #("version", gleam_json.string("1.0")),
  #("tags", gleam_json.array(
    [gleam_json.string("social"), gleam_json.string("network")],
    of: fn(x) { x },
  )),
])

let options = json.JsonExportOptions(
  ..json.default_export_options(),
  metadata: option.Some(metadata),
)

let json_string = json.to_json(graph, options)
```

#### Generic Format Output

The default Generic format includes full metadata:

```json
{
  "format": "yog-generic",
  "version": "2.0",
  "metadata": {
    "graph_type": "directed",
    "node_count": 2,
    "edge_count": 1
  },
  "nodes": [
    { "id": 1, "data": "Alice" },
    { "id": 2, "data": "Bob" }
  ],
  "edges": [
    { "source": 1, "target": 2, "data": "follows" }
  ]
}
```

#### Exporting DAGs (Directed Acyclic Graphs)

DAGs can be exported by first converting them to a regular graph:

```gleam
import yog/dag/models as dag
import yog_io/json

// You have a DAG
let my_dag: dag.Dag(String, String) = ...

// Convert to Graph and export
let graph = dag.to_graph(my_dag)
let json_string = json.to_json(graph, json.default_export_options())
```

The output will include `"graph_type": "directed"` in the metadata. The acyclicity property is a semantic constraint that is preserved by the DAG type but not explicitly indicated in the JSON output.

#### MultiGraph Support

**Note:** The current JSON implementation supports simple graphs (at most one edge between any pair of nodes). Support for MultiGraphs (multiple parallel edges between nodes) is planned for a future release.

For details on how different graph types will be represented, see [GRAPH_TYPES_JSON.md](GRAPH_TYPES_JSON.md).

## Module Overview

| Module | Purpose |
|--------|---------|
| `yog_io` | Convenience functions for common operations |
| `yog_io/graphml` | Full GraphML support with custom mappers |
| `yog_io/gdf` | Full GDF support with custom mappers |
| `yog_io/json` | JSON export with multiple format presets |

## Format Support

### GraphML

- ✅ Nodes with custom attributes
- ✅ Edges with custom attributes
- ✅ Directed and undirected graphs
- ✅ Typed attributes (string, int, float, double, boolean, long)
- ✅ Gephi-compatible numeric attributes
- ✅ XML escaping
- ✅ Custom serialization options

### GDF

- ✅ Nodes with custom attributes
- ✅ Edges with custom attributes
- ✅ Directed and undirected graphs
- ✅ CSV-style escaping (quotes, separators)
- ✅ Custom separators and type annotations
- ✅ Weighted graph convenience functions

### JSON

- ✅ Generic format with full metadata
- ✅ D3.js force-directed format
- ✅ Cytoscape.js elements format
- ✅ vis.js network format
- ✅ NetworkX node-link format
- ✅ Custom node and edge serializers
- ✅ Generic type support (not limited to String)
- ✅ File I/O operations
- ✅ Custom metadata fields

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

### JSON Example (Generic Format)

```json
{
  "format": "yog-generic",
  "version": "2.0",
  "metadata": {
    "graph_type": "directed",
    "node_count": 2,
    "edge_count": 1
  },
  "nodes": [
    { "id": 1, "data": "Alice" },
    { "id": 2, "data": "Bob" }
  ],
  "edges": [
    { "source": 1, "target": 2, "data": "friend" }
  ]
}
```

### JSON Example (D3.js Format)

```json
{
  "nodes": [
    { "id": "1" },
    { "id": "2" }
  ],
  "links": [
    { "source": "1", "target": "2", "value": "friend" }
  ]
}
```

## Development

```sh
# Run tests
gleam test

# Run specific test module
gleam test yog_io/graphml_test
gleam test yog_io/gdf_test
gleam test yog_io/json_test

# Run examples (output files are written to output/ directory)
gleam run -m examples/json_export_example
gleam run -m examples/gephi_example

# Build documentation
gleam docs
```

**Note:** Example outputs (JSON files, GraphML files, etc.) are written to the `output/` directory, which is ignored by git.

## References

- [GraphML Specification](http://graphml.graphdrawing.org/specification.html)
- [GDF Format](https://gephi.org/users/supported-graph-formats/gdf-format/)
- [JSON Specification](https://www.json.org/)
- [D3.js Documentation](https://d3js.org/)
- [Cytoscape.js Documentation](https://js.cytoscape.org/)
- [vis.js Documentation](https://visjs.github.io/vis-network/)
- [NetworkX JSON Format](https://networkx.org/documentation/stable/reference/readwrite/json_graph.html)
- [yog Graph Library](https://hex.pm/packages/yog)

## License

Apache-2.0
