# yog_io

[![Package Version](https://img.shields.io/hexpm/v/yog_io)](https://hex.pm/packages/yog_io)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/yog_io/)

Graph file format I/O for the [yog](https://hex.pm/packages/yog) graph library. Provides serialization and deserialization support for popular graph file formats including TGF, LEDA, Pajek, JSON, GraphML, and GDF.

## Features

- **TGF Support** - Trivial Graph Format with auto-node creation for lenient parsing
- **LEDA Support** - Academic graph format compatible with LEDA library and NetworkX
- **Pajek Support** - Social network analysis format (.net files) with visual attributes
- **JSON Support** - Multiple JSON formats for web visualization libraries (D3.js, Cytoscape.js, vis.js, NetworkX)
- **MultiGraph Support** - Parallel edges with unique edge IDs in JSON formats
- **GraphML Support** - Full XML-based graph format support compatible with Gephi, yEd, Cytoscape, and NetworkX
- **Gephi-Optimized** - Typed attributes (int, double, boolean) for proper Gephi visualizations and analysis
- **GDF Support** - Simple CSV-like format used by Gephi and GUESS
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

**Note:** The JSON module is currently write-only. Import/read functionality is not implemented. For bidirectional I/O, consider using GraphML, GDF, TGF, LEDA, or Pajek formats.

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

// Export to file (simple method)
let assert Ok(Nil) = json.write("graph.json", graph)

// Export to file (with custom options)
let assert Ok(Nil) = json.write_with(
  "graph.json",
  json.default_export_options(),
  graph,
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

The JSON module now supports MultiGraphs (graphs with multiple parallel edges between nodes):

```gleam
import yog/multi/model as multi
import yog_io/json

// Create a multigraph with parallel edges
let graph = multi.new(model.Directed)
  |> multi.add_node(1, "Alice")
  |> multi.add_node(2, "Bob")

let #(graph, _) = multi.add_edge(graph, from: 1, to: 2, with: "follows")
let #(graph, _) = multi.add_edge(graph, from: 1, to: 2, with: "mentions")
let #(graph, _) = multi.add_edge(graph, from: 1, to: 2, with: "likes")

// Export multigraph to JSON
let options = json.export_options_with(json.string, json.string)
let json_string = json.to_json_multi(graph, options)
```

All JSON format presets (Generic, D3Force, Cytoscape, VisJs, NetworkX) support multigraphs with unique edge IDs. The Generic and NetworkX formats include a `"multigraph": true` metadata flag.

See [test/examples/multigraph_json_example.gleam](https://github.com/code-shoily/yog_io/blob/main/test/examples/multigraph_json_example.gleam) for a complete example.

## Module Overview

| Module | Purpose |
|--------|---------|
| `yog_io` | Convenience functions for common operations |
| `yog_io/tgf` | TGF (Trivial Graph Format) serialization and parsing |
| `yog_io/leda` | LEDA format with strict validation |
| `yog_io/pajek` | Pajek (.net) format for social network analysis |
| `yog_io/json` | JSON export with multiple format presets and MultiGraph support (WRITE-ONLY) |
| `yog_io/graphml` | Full GraphML support with custom mappers |
| `yog_io/gdf` | Full GDF support with custom mappers |

## Format Support

### TGF (Trivial Graph Format)

- ✅ Human-readable text format with minimal syntax
- ✅ Auto-node creation for lenient parsing
- ✅ Support for nodes without labels (defaults to ID)
- ✅ Multi-word labels with space handling
- ✅ Warning collection for malformed lines
- ✅ Directed and undirected graphs

### LEDA

- ✅ LEDA Library compatibility for academic research
- ✅ 1-indexed sequential node IDs
- ✅ Strict node reference validation
- ✅ Support for typed node and edge data
- ✅ Reversal edge indices for undirected graphs
- ✅ Comprehensive error reporting with line numbers

### Pajek

- ✅ Social network analysis standard (.net files)
- ✅ Multi-word quoted labels support
- ✅ Case-insensitive section headers
- ✅ Visual attributes (coordinates, shapes, colors, sizes)
- ✅ Weighted edges with optional float values
- ✅ Comment handling (% lines)
- ✅ Graph type auto-detection (*Arcs vs *Edges)

### JSON

**Note:** JSON module is currently WRITE-ONLY. Import/read functionality is not implemented.

- ✅ Generic format with full metadata
- ✅ D3.js force-directed format
- ✅ Cytoscape.js elements format
- ✅ vis.js network format
- ✅ NetworkX node-link format
- ✅ MultiGraph support with unique edge IDs
- ✅ Custom node and edge serializers
- ✅ Generic type support (not limited to String)
- ✅ File write operations
- ✅ Custom metadata fields
- ❌ Import/read operations (not implemented)

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

### Format Compatibility Matrix

| Format | Directed | Undirected | Weighted | Attributes | MultiGraph | Visual |
|--------|----------|------------|----------|------------|------------|--------|
| TGF | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| LEDA | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Pajek | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| JSON (all) | ✅ | ✅ | ✅ | ✅ | ✅ | Partial |
| GraphML | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| GDF | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |

**Note:** JSON format is write-only (export only). All other formats support bidirectional read/write operations.

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

## Examples

Detailed examples demonstrating each format are located in the [test/examples/](https://github.com/code-shoily/yog_io/tree/main/test/examples) directory:

- [TGF Example](https://github.com/code-shoily/yog_io/blob/main/test/examples/tgf_example.gleam) - Trivial Graph Format with auto-node creation and optional edge labels
- [LEDA Example](https://github.com/code-shoily/yog_io/blob/main/test/examples/leda_example.gleam) - LEDA format for academic graph algorithms with directed and undirected examples
- [Pajek Example](https://github.com/code-shoily/yog_io/blob/main/test/examples/pajek_example.gleam) - Social network analysis format with multi-word labels
- [MultiGraph JSON Example](https://github.com/code-shoily/yog_io/blob/main/test/examples/multigraph_json_example.gleam) - Parallel edges with unique edge IDs across all JSON formats

### Running Examples Locally

The examples live in the `test/examples/` directory and can be run directly:

```bash
gleam run -m examples/tgf_example
gleam run -m examples/leda_example
gleam run -m examples/pajek_example
gleam run -m examples/multigraph_json_example
```

Run all examples at once:

```bash
./run_examples.sh
```

## Development

### Running Tests

Run the full test suite:

```bash
gleam test
```

Run tests for a specific module:

```bash
./test_module.sh yog_io/json_test
./test_module.sh yog_io/graphml_test
./test_module.sh yog_io/tgf_test
```

Run a specific test function:

```bash
./test_module.sh yog_io/json_test to_json_generic_format_test
```

### Property-Based Tests

In addition to traditional example-based tests, `yog_io` includes property-based tests using [qcheck](https://hex.pm/packages/qcheck). These tests generate random graphs and verify roundtrip invariants:

```bash
# Run all tests (including property tests)
gleam test

# Run specific property test
gleam test yog_io@property_test.graphml_structural_roundtrip_property_test
```

**Key Properties Verified:**

| Property | Description |
|----------|-------------|
| Structural Equality | Complete graph topology preserved (GraphML, JSON) |
| Node Count | Number of nodes unchanged after roundtrip |
| Edge Count | Number of edges unchanged after roundtrip |
| Graph Type | Directed/Undirected property maintained |
| Undirected Symmetry | For undirected graphs, edge(u,v) implies edge(v,u) |

**Format Limitations:**

Not all formats support complete structural equality:

- **Full Support**: GraphML, JSON (Generic format)
- **Partial Support**: GDF (empty graphs), TGF (auto-node creation)
- **No Support**: LEDA, Pajek (node IDs renumbered to 1, 2, 3...)

See [PROPERTY_TESTS.md](PROPERTY_TESTS.md) for detailed documentation on invariants, hypotheses, and limitations.

### Running Examples

Run all examples at once:

```bash
./run_examples.sh
```

Run a specific example:

```bash
gleam run -m examples/tgf_example
gleam run -m examples/multigraph_json_example
```

### Building Documentation

```bash
gleam docs
```

### Project Structure

- `src/yog_io/` - Format-specific I/O modules (TGF, LEDA, Pajek, JSON, GraphML, GDF)
- `test/` - Unit tests for each format
- `test/examples/` - Real-world usage examples demonstrating each format

**Note:** Example outputs (JSON files, GraphML files, etc.) are written to the `output/` directory, which is ignored by git.

## References

### Format Specifications

- [TGF - Wikipedia](https://en.wikipedia.org/wiki/Trivial_Graph_Format) | [yEd TGF Import](https://yed.yworks.com/support/manual/tgf.html)
- [LEDA Library](https://www.algorithmic-solutions.com/leda/) | [NetworkX LEDA](https://networkx.org/documentation/stable/reference/readwrite/leda.html)
- [Pajek Software](http://mrvar.fdv.uni-lj.si/pajek/) | [Pajek .net Format](http://mrvar.fdv.uni-lj.si/pajek/dokuwiki/doku.php?id=description_of_net_file_format)
- [GraphML Specification](http://graphml.graphdrawing.org/specification.html)
- [GDF Format - Gephi](https://gephi.org/users/supported-graph-formats/gdf-format/)
- [JSON Specification](https://www.json.org/)

### Visualization Tools

- [D3.js Documentation](https://d3js.org/)
- [Cytoscape.js Documentation](https://js.cytoscape.org/)
- [vis.js Documentation](https://visjs.github.io/vis-network/)
- [NetworkX JSON Format](https://networkx.org/documentation/stable/reference/readwrite/json_graph.html)
- [Gephi - Graph Visualization Platform](https://gephi.org/)

### Libraries

- [yog Graph Library](https://hex.pm/packages/yog)

## License

Apache-2.0
