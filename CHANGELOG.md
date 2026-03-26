# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-03-26

### Added

- **JSON Deserialization** (`yog_io/json`)
  - Full support for importing graphs from JSON files and strings.
  - `read/1` - Read generic JSON graph file.
  - `read_multi/1` - Read multigraph JSON file.
  - `from_json/1` - Parse JSON string to graph.
  - `from_json_multi/1` - Parse multigraph JSON string.
  - Type-safe decoding using `gleam/dynamic/decode`.

- **Adjacency List Support** (`yog_io/list`)
  - New module for `.list` format I/O.
  - `read/2`, `read_with/3` - Read adjacency list from file.
  - `write/2`, `write_with/3` - Write graph to adjacency list file.
  - `from_string/3` - Parse adjacency list string.
  - `serialize/2` - Convert graph to adjacency list string.
  - Support for weighted (`node: neighbor,weight`) and unweighted formats.

- **Adjacency Matrix Support** (`yog_io/matrix`)
  - New module for dense adjacency matrix I/O.
  - `read/2`, `write/2` - File-based matrix operations.
  - `from_string/1`, `serialize/1` - String-based matrix operations.
  - `from_matrix/2`, `to_matrix/1` - Conversion between lists and graphs.
  - Supports directed and undirected graphs (upper triangle).

- **Matrix Market Support** (`yog_io/matrix_market`)
  - New module for Matrix Market coordinate format (`.mtx`).
  - `read/1`, `write/2` - File-based MTX operations.
  - `from_string/1`, `serialize/1` - String-based MTX operations.
  - Supports `real`, `integer`, and `pattern` fields.
  - Handles `general` and `symmetric` coordinate matrices.

### Changed

- Renamed `to_string` to `serialize` across new modules for consistency with `gdf` and `mtx`.
- Standardized file-based operations to use `read` and `write` naming.
- Replaced all usages of deprecated `result.then` with `result.try`.
- Replaced deprecated `list.range` with modern `int.range` folds.
- Updated documentation across all modules for consistency and breadth.

### Testing

- Increased test suite to **181 tests**.
- Added dedicated unit tests for `list`, `matrix`, and `matrix_market` modules.
- Added roundtrip and sample-based integration tests for all new formats.

## [1.0.0] -  2026-03-22


## [0.9.0] - 2026-03-21

### Added

- **TGF Support** (`yog_io/tgf`)
  - `serialize/1` - Serialize String graphs to Trivial Graph Format
  - `serialize_with/2` - Serialize with custom label functions
  - `parse/2` - Parse TGF string to graph with custom parsers
  - `parse_with/4` - Parse with custom node and edge parsers
  - `read/2` - Read TGF file into graph
  - `read_with/4` - Read with custom parsers
  - `write/2` - Write String graph to TGF file
  - `write_with/3` - Write with custom label functions
  - `options_with/2` - Create custom serialization options
  - `default_options/0` - Get default TGF options

- **LEDA Support** (`yog_io/leda`)
  - `serialize/1` - Serialize String graphs to LEDA format
  - `serialize_with/2` - Serialize with custom serializers
  - `parse/1` - Parse LEDA string to graph
  - `parse_with/3` - Parse with custom node and edge parsers
  - `read/1` - Read LEDA file into graph
  - `read_with/3` - Read with custom parsers
  - `write/2` - Write String graph to LEDA file
  - `write_with/3` - Write with custom serializers
  - `options_with/4` - Create custom serialization options
  - `to_string/1` - Alias for serialize

- **Pajek Support** (`yog_io/pajek`)
  - `serialize/1` - Serialize String graphs to Pajek .net format
  - `serialize_with/2` - Serialize with custom options
  - `parse/1` - Parse Pajek string to graph
  - `parse_with/3` - Parse with custom node and edge parsers
  - `read/1` - Read Pajek file into graph
  - `read_with/3` - Read with custom parsers
  - `write/2` - Write String graph to Pajek file
  - `write_with/3` - Write with custom options
  - `options_with/5` - Create custom serialization options
  - `default_options/0` - Get default Pajek options
  - `default_node_attributes/0` - Get default visual attributes
  - `to_string/1` - Alias for serialize

- **MultiGraph JSON Support** (`yog_io/json`)
  - `to_json_multi/2` - Export MultiGraph to JSON with edge IDs
  - `to_json_file_multi/3` - Export MultiGraph directly to JSON file
  - Support for parallel edges with unique edge identifiers
  - All format presets (Generic, D3Force, Cytoscape, VisJs, NetworkX) support multigraphs
  - `"multigraph": true` metadata flag in Generic and NetworkX formats

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

- **TGF Format**
  - Human-readable text format with minimal syntax
  - Auto-node creation for lenient parsing
  - Support for nodes without labels (defaults to ID)
  - Multi-word labels with space handling
  - Warning collection for malformed lines
  - 1-based node indexing

- **LEDA Format**
  - LEDA Library compatibility for academic research
  - 1-indexed sequential node IDs
  - Strict node reference validation
  - Support for typed node and edge data
  - Reversal edge indices for undirected graphs
  - Comprehensive error reporting with line numbers

- **Pajek Format**
  - Social network analysis standard (.net files)
  - Multi-word quoted labels support
  - Case-insensitive section headers
  - Visual attributes (coordinates, shapes, colors, sizes)
  - Weighted edges with optional float values
  - Comment handling (% lines)
  - Graph type auto-detection (*Arcs vs *Edges)

- **MultiGraph Support**
  - Parallel edges with unique edge IDs
  - All JSON formats support multigraphs
  - Proper edge ID assignment and tracking
  - Metadata flags for multigraph detection

- **JSON Formats**
  - Generic type support for nodes and edges (not limited to String)
  - Custom serializers for any data type
  - Multiple format presets for popular visualization libraries
  - Rich metadata support with custom fields
  - File I/O operations with comprehensive error handling
  - Pretty printing support
  - Proper handling of directed and undirected graphs
  - Edge deduplication for undirected graphs

### Testing

- Comprehensive test suite with 153 tests including:
  - **TGF**: 23 tests (serialization, parsing, roundtrip, auto-node creation, error handling)
  - **LEDA**: 22 tests (serialization, parsing, node ID mapping, strict validation, error handling)
  - **Pajek**: 18 tests (serialization, parsing, multi-word labels, visual attributes, comments)
  - **JSON**: 29 tests (Generic, D3, Cytoscape, vis.js, NetworkX formats)
  - **MultiGraph JSON**: 8 tests (parallel edges, all formats, metadata flags)
  - **GraphML**: 31 tests (serialization, deserialization, roundtrip, attributes)
  - **GDF**: 22 tests (serialization, deserialization, weighted edges, attributes)
  - Format-specific tests for each supported format
  - Custom serializer/parser tests
  - Metadata inclusion tests
  - File I/O tests
  - Edge case tests (empty graphs, single nodes, malformed input)
  - Warning collection and error reporting tests

### References

- **TGF**: [Wikipedia - Trivial Graph Format](https://en.wikipedia.org/wiki/Trivial_Graph_Format), [yEd TGF Import](https://yed.yworks.com/support/manual/tgf.html)
- **LEDA**: [LEDA Library](https://www.algorithmic-solutions.com/leda/), [NetworkX LEDA](https://networkx.org/documentation/stable/reference/readwrite/leda.html)
- **Pajek**: [Pajek Software](http://mrvar.fdv.uni-lj.si/pajek/), [Format Specification](http://mrvar.fdv.uni-lj.si/pajek/dokuwiki/doku.php?id=description_of_net_file_format)
- **JSON**: Replaces [yog/render/json](https://github.com/code-shoily/yog/blob/main/src/yog/render/json.gleam)
  - [D3.js](https://d3js.org/)
  - [Cytoscape.js](https://js.cytoscape.org/)
  - [vis.js](https://visjs.github.io/vis-network/)
  - [NetworkX](https://networkx.org/)
- **GraphML**: [GraphML Specification](http://graphml.graphdrawing.org/specification.html)
- **GDF**: [Gephi GDF Format](https://gephi.org/users/supported-graph-formats/gdf-format/)

### Format Compatibility

| Format | Directed | Undirected | Weighted | Attributes | MultiGraph | Visual |
|--------|----------|------------|----------|------------|------------|--------|
| TGF | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| LEDA | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Pajek | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| JSON (all) | ✅ | ✅ | ✅ | ✅ | ✅ | Partial |
| GraphML | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| GDF | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |

### Breaking Changes

- None (new major version 1.0.0)

### Known Limitations

- DAG export requires manual conversion via `dag.to_graph()` (no acyclicity flag in metadata yet)
- MultiGraph support only available for JSON formats (not GraphML, GDF, TGF, LEDA, or Pajek)
- JSON import/deserialization not yet implemented (export-only)

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
