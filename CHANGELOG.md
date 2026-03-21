# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - Unreleased

### Added

- **JSON Support** (`yog_io/json`)
  - `to_json/2` - Export graph to JSON string with format options
  - `to_json_file/3` - Export graph directly to JSON file
  - `default_export_options/0` - Get default JSON export options
  - `export_options_with/2` - Create options with custom serializers
  - `to_d3_json/3` - Quick export to D3.js force-directed format
  - `to_cytoscape_json/3` - Quick export to Cytoscape.js format
  - `to_visjs_json/3` - Quick export to vis.js format
  - `error_to_string/1` - Convert JSON errors to readable strings

- **JSON Format Presets**
  - `Generic` - Full metadata format with type preservation
  - `D3Force` - D3.js force-directed graph format
  - `Cytoscape` - Cytoscape.js elements format
  - `VisJs` - vis.js network format
  - `NetworkX` - Python NetworkX node-link format

- **Convenience Functions** (`yog_io`)
  - `write_json/2` - Quick JSON file writing for String graphs
  - `to_json/1` - Quick JSON string export for String graphs
  - `write_d3_json/2` - Export to D3.js format file
  - `write_cytoscape_json/2` - Export to Cytoscape.js format file
  - `write_visjs_json/2` - Export to vis.js format file
  - `default_json_options/0` - Get default JSON options

- **Type Exports**
  - `JsonFormat` - Format preset type
  - `JsonExportOptions(n, e)` - Generic export options
  - `JsonError` - Error type for JSON operations

### Features

- Generic type support for nodes and edges (not limited to String)
- Custom serializers for any data type
- Multiple format presets for popular visualization libraries
- Rich metadata support with custom fields
- File I/O operations with comprehensive error handling
- Pretty printing support
- Proper handling of directed and undirected graphs
- Edge deduplication for undirected graphs

### Testing

- Comprehensive test suite with 71 tests including:
  - Format-specific tests (Generic, D3, Cytoscape, vis.js, NetworkX)
  - Custom serializer tests
  - Metadata inclusion tests
  - File I/O tests
  - Edge case tests (empty graphs, single nodes)

### Documentation

- **[GRAPH_TYPES_JSON.md](GRAPH_TYPES_JSON.md)** - Comprehensive guide for exporting different graph types (Graph, MultiGraph, DAG)
  - Current support status for each graph type
  - Format requirements for MultiGraph support (planned)
  - How to export DAGs using `dag.to_graph()`
  - Compatibility matrix for all formats

### References

- Based on, and will eventually replace: [yog/render/json](../yog/src/yog/render/json.gleam)
- Format presets compatible with:
  - [D3.js](https://d3js.org/)
  - [Cytoscape.js](https://js.cytoscape.org/)
  - [vis.js](https://visjs.github.io/vis-network/)
  - [NetworkX](https://networkx.org/)

### Known Limitations

- MultiGraph support not yet implemented (multiple parallel edges between same nodes)
- DAG export requires manual conversion via `dag.to_graph()` (no acyclicity flag in metadata yet)

## [0.5.0] - 2025-03-20

### Added

- **GraphML Support** (`yog_io/graphml`)
  - `serialize/1` - Serialize String graphs to GraphML format
  - `serialize_with/3` - Serialize with custom attribute mappers
  - `serialize_with_options/4` - Serialize with custom options
  - `deserialize/1` - Deserialize GraphML to attributed graph
  - `deserialize_with/3` - Deserialize with custom data mappers
  - `read/1` - Read GraphML file into attributed graph
  - `read_with/3` - Read with custom data mappers
  - `write/2` - Write String graph to GraphML file
  - `write_with/4` - Write with custom attribute mappers
  - `default_options/0` - Get default serialization options

- **GDF Support** (`yog_io/gdf`)
  - `serialize/1` - Serialize String graphs to GDF format
  - `serialize_weighted/1` - Serialize with integer weights
  - `serialize_with/4` - Serialize with custom attribute mappers
  - `deserialize/1` - Deserialize GDF to attributed graph
  - `deserialize_with/3` - Deserialize with custom data mappers
  - `read/1` - Read GDF file into attributed graph
  - `read_with/3` - Read with custom data mappers
  - `write/2` - Write String graph to GDF file
  - `write_with/5` - Write with custom attribute mappers
  - `default_options/0` - Get default serialization options

- **Convenience Module** (`yog_io`)
  - `read_graphml/1` - Quick GraphML file reading
  - `write_graphml/2` - Quick GraphML file writing
  - `read_gdf/1` - Quick GDF file reading
  - `write_gdf/2` - Quick GDF file writing
  - `default_graphml_options/0` - Get default GraphML options
  - `default_gdf_options/0` - Get default GDF options

- **Type Exports**
  - `NodeAttributes` - Dictionary type for node attributes
  - `EdgeAttributes` - Dictionary type for edge attributes
  - `AttributedGraph` - Graph with string dictionaries for data
  - `GraphMLOptions` - Options for GraphML serialization
  - `GdfOptions` - Options for GDF serialization

- **Comprehensive Test Suite**
  - Serialization tests for both formats
  - Deserialization tests for both formats
  - Roundtrip tests to verify read/write consistency
  - File I/O tests with actual file operations
  - Custom mapper tests for domain types
  - Edge case and error handling tests

### Features

- Full support for directed and undirected graphs
- Custom attribute mappers for domain types
- XML escaping for GraphML special characters
- CSV-style escaping for GDF values
- Bidirectional edge handling for undirected graphs
- JS-compatible dependencies (xmlm, simplifile)

### References

- Based on the [yog-fsharp](https://github.com/code-shoily/yog-fsharp) reference implementation
- GraphML format follows the [GraphML Specification](http://graphml.graphdrawing.org/specification.html)
- GDF format follows the [Gephi GDF format](https://gephi.org/users/supported-graph-formats/gdf-format/)

[0.7.0]: https://github.com/code-shoily/yog_io/releases/tag/v0.7.0
[0.5.0]: https://github.com/code-shoily/yog_io/releases/tag/v0.5.0
