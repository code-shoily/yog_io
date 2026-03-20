# Gephi Compatibility Guide

This document explains how to create GraphML and GDF files that work seamlessly with [Gephi](https://gephi.org/), the leading graph visualization platform.

## Quick Start

```gleam
import gleam/dict
import gleam/int
import gleam/float
import yog/model.{Directed}
import yog_io/graphml.{DoubleType, IntType, StringType}

// Define your data with typed attributes
let node_attrs = fn(person) {
  dict.from_list([
    #("label", #(person.name, StringType)),
    #("age", #(int.to_string(person.age), IntType)),
    #("influence", #(float.to_string(person.score), DoubleType)),
  ])
}

let edge_attrs = fn(weight) {
  dict.from_list([
    #("weight", #(float.to_string(weight), DoubleType)),
  ])
}

// Serialize with proper types
let xml = graphml.serialize_with_types(node_attrs, edge_attrs, graph)
```

## Why Typed Attributes Matter

Gephi needs to know the data type of each attribute to enable advanced features:

### Without Typed Attributes (Old Way)
```gleam
// ❌ All attributes treated as strings
let node_attrs = fn(person) {
  dict.from_list([
    #("age", "30"),  // Gephi sees this as text, not a number
    #("score", "0.85"),  // Can't use for numeric operations
  ])
}

let xml = graphml.serialize_with(node_attrs, edge_attrs, graph)
```

**Gephi Limitations:**
- ❌ Can't size nodes by age
- ❌ Can't color by score
- ❌ Can't filter by numeric range
- ❌ Can't use weighted layouts (ForceAtlas2)
- ❌ Statistical analysis won't work

### With Typed Attributes (New Way)
```gleam
// ✅ Proper type information
let node_attrs = fn(person) {
  dict.from_list([
    #("age", #(int.to_string(person.age), IntType)),
    #("score", #(float.to_string(person.score), DoubleType)),
  ])
}

let xml = graphml.serialize_with_types(node_attrs, edge_attrs, graph)
```

**Gephi Features Enabled:**
- ✅ Size nodes by age
- ✅ Color nodes by score
- ✅ Filter by numeric ranges
- ✅ Use edge weights in layouts
- ✅ Run statistical analysis
- ✅ Create dynamic visualizations

## Available Attribute Types

| Type | GraphML | Use For | Example |
|------|---------|---------|---------|
| `StringType` | `string` | Text data, labels, categories | Names, descriptions |
| `IntType` | `int` | Whole numbers | Age, count, year |
| `FloatType` | `float` | Decimals (32-bit) | Ratings, percentages |
| `DoubleType` | `double` | Decimals (64-bit, **recommended**) | Weights, scores, measurements |
| `BooleanType` | `boolean` | True/false values | Active status, flags |
| `LongType` | `long` | Large integers (64-bit) | Timestamps, IDs |

**Recommendation:** Use `DoubleType` for all decimal numbers in Gephi graphs.

## Complete Example

```gleam
import gleam/dict
import gleam/float
import gleam/int
import yog/model.{Directed}
import yog_io/graphml.{BooleanType, DoubleType, IntType, StringType}

pub fn create_social_network() {
  // Create graph with custom data types
  let graph =
    model.new(Directed)
    |> model.add_node(1, Person("Alice", 30, 0.85, True))
    |> model.add_node(2, Person("Bob", 25, 0.92, False))
    |> model.add_node(3, Person("Charlie", 35, 0.78, True))

  let assert Ok(graph) =
    model.add_edges(graph, [
      #(1, 2, 5.0),
      #(2, 3, 10.0),
      #(1, 3, 3.5),
    ])

  // Map to typed attributes
  let node_attrs = fn(person: Person) {
    dict.from_list([
      #("label", #(person.name, StringType)),
      #("age", #(int.to_string(person.age), IntType)),
      #("influence", #(float.to_string(person.influence), DoubleType)),
      #("active", #(case person.active {
        True -> "true"
        False -> "false"
      }, BooleanType)),
    ])
  }

  let edge_attrs = fn(weight: Float) {
    dict.from_list([
      #("weight", #(float.to_string(weight), DoubleType)),
    ])
  }

  // Save for Gephi
  graphml.write_with_types(
    "social_network.graphml",
    node_attrs,
    edge_attrs,
    graph,
  )
}

type Person {
  Person(name: String, age: Int, influence: Float, active: Bool)
}
```

## Using in Gephi

1. **Open the file** in Gephi: File → Open → Select your `.graphml` file

2. **Verify attribute types** in Data Laboratory:
   - Numeric attributes should show as `Integer` or `Double`
   - Not as `String`

3. **Use in visualizations**:
   - **Appearance** → Size → Nodes → Ranking → Select numeric attribute
   - **Appearance** → Color → Nodes → Ranking → Select numeric attribute
   - **Layout** → ForceAtlas 2 → Check "Edge Weight" → Select weight attribute
   - **Filters** → Attributes → Range → Select numeric attribute

4. **Run statistics**:
   - Statistics → Average Degree (uses edge weights if available)
   - Statistics → Modularity (uses edge weights)
   - Statistics → PageRank (uses edge weights)

## GDF Format

GDF also supports typed attributes through type annotations:

```gleam
import yog_io/gdf

// GDF automatically includes type annotations
let gdf_string = gdf.serialize(graph)

// Output includes:
// nodedef>name VARCHAR,label VARCHAR
// edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,weight VARCHAR
```

**Note:** GDF type annotations are recognized by Gephi, but GraphML with typed attributes provides better compatibility.

## Backward Compatibility

The existing API still works for basic cases:

```gleam
// Old API - still works, but attributes are all strings
let xml = graphml.serialize(graph)
let xml = graphml.serialize_with(node_attrs, edge_attrs, graph)

// New API - use for Gephi compatibility
let xml = graphml.serialize_with_types(node_attrs, edge_attrs, graph)
```

## Testing Your Files

A test file has been generated at `/tmp/gephi_test_graph.graphml`.

Try opening it in Gephi to verify:
1. All nodes and edges load correctly
2. Numeric attributes are recognized (not shown as strings)
3. You can size/color nodes by numeric attributes
4. You can filter by numeric ranges
5. Weighted layouts use edge weights

## Troubleshooting

### "Attribute type mismatch" error
- **Cause:** Different nodes have different types for the same attribute
- **Fix:** Ensure all nodes use the same type for each attribute name

### Numeric attributes shown as strings
- **Cause:** Used `serialize_with()` instead of `serialize_with_types()`
- **Fix:** Use `serialize_with_types()` with proper AttributeType values

### Layout doesn't use edge weights
- **Cause:** Edge weight attribute is StringType instead of DoubleType
- **Fix:** Use `DoubleType` for edge weights

### Can't filter by numeric range
- **Cause:** Attribute is StringType
- **Fix:** Use `IntType`, `FloatType`, or `DoubleType`

## Additional Resources

- [Gephi Supported Formats](https://gephi.org/users/supported-graph-formats/)
- [GraphML Specification](http://graphml.graphdrawing.org/)
- [GDF Format](https://gephi.org/users/supported-graph-formats/gdf-format/)
