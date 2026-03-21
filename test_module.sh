#!/usr/bin/env bash
# Run tests for a single module without running the full test suite.
#
# Usage:
#   ./test_module.sh <gleam_module_path>
#
# Examples:
#   ./test_module.sh yog_io/json_test
#   ./test_module.sh yog_io/tgf_test
#   ./test_module.sh yog_io_test
#
# The argument is the path under test/ without the .gleam extension.
# Slashes are converted to @ to match Erlang module naming.
#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <module_path> [function_name]"
  echo "Example: $0 yog_io/graphml_test serialize_empty_directed_graph_test"
  exit 1
fi

MODULE_PATH="$1"
FUNCTION_NAME="${2:-}" # Optional second argument
ERLANG_MODULE="${MODULE_PATH//\//@}"

echo "Building project..."
gleam build --target erlang

echo ""
if [ -n "$FUNCTION_NAME" ]; then
  echo "Running test: $ERLANG_MODULE:$FUNCTION_NAME"
  # EUnit expects the function name as an atom. 
  # We use {generator, Mod, Fun} or {test, Mod, Fun}
  EUNIT_EXPR="eunit:test({test, '${ERLANG_MODULE}', '${FUNCTION_NAME}'}, [verbose])"
else
  echo "Running all tests for: $ERLANG_MODULE"
  EUNIT_EXPR="eunit:test('${ERLANG_MODULE}', [verbose])"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PA_FLAGS=()
for dir in build/dev/erlang/*/ebin; do
  PA_FLAGS+=(-pa "$dir")
done

erl "${PA_FLAGS[@]}" -eval "$EUNIT_EXPR, init:stop()" -noshell