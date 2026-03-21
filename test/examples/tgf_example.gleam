import gleam/io
import gleam/option
import yog/model
import yog_io/tgf

/// Example demonstrating TGF (Trivial Graph Format) export
///
/// TGF is a simple text format with two sections:
/// - Node section: `id label`
/// - Edge section: `source target [label]`
/// - Sections separated by `#`
pub fn main() {
  io.println("=== TGF Format Example ===\n")

  // Create a simple social network
  let graph =
    model.new(model.Directed)
    |> model.add_node(1, "Alice")
    |> model.add_node(2, "Bob")
    |> model.add_node(3, "Carol")

  let assert Ok(graph) = model.add_edge(graph, from: 1, to: 2, with: "follows")
  let assert Ok(graph) = model.add_edge(graph, from: 2, to: 3, with: "knows")
  let assert Ok(graph) = model.add_edge(graph, from: 3, to: 1, with: "mentions")

  // Export to TGF
  let tgf_string = tgf.serialize(graph)

  io.println("Output:")
  io.println(tgf_string)
  io.println("\nFormat:")
  io.println("  - Lines 1-3: Node definitions (id label)")
  io.println("  - Line 4: Section separator (#)")
  io.println("  - Lines 5-7: Edge definitions (source target label)")

  // Example with no edge labels
  io.println("\n=== TGF Without Edge Labels ===\n")

  let graph2 =
    model.new(model.Undirected)
    |> model.add_node(1, "Node A")
    |> model.add_node(2, "Node B")

  let assert Ok(graph2) = model.add_edge(graph2, from: 1, to: 2, with: "")

  let options =
    tgf.options_with(node_label: fn(data) { data }, edge_label: fn(_) {
      option.None
    })

  let tgf_string2 = tgf.serialize_with(options, graph2)
  io.println("Output:")
  io.println(tgf_string2)
}
/// Expected Output:
///
/// === TGF Format Example ===
///
/// Output:
/// 1 Alice
/// 2 Bob
/// 3 Carol
/// #
/// 1 2 follows
/// 2 3 knows
/// 3 1 mentions
///
/// Format:
///   - Lines 1-3: Node definitions (id label)
///   - Line 4: Section separator (#)
///   - Lines 5-7: Edge definitions (source target label)
///
/// === TGF Without Edge Labels ===
///
/// Output:
/// 1 Node A
/// 2 Node B
/// #
/// 1 2
