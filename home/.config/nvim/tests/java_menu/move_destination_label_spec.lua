-- Regression: Move Class destinations must be distinguishable by source root.
-- Run with:
--   nvim --headless -u NONE \
--     -c "set rtp+=~/.config/nvim" \
--     -c "luafile tests/java_menu/move_destination_label_spec.lua" -c qa

local refactor = require("java_menu.refactor")

local root = "/tmp/proj"
local function dest(path, name, default)
  return {
    uri = "file://" .. path,
    displayName = name,
    isDefaultPackage = default == true,
  }
end

local app_test, app_test_dir =
  refactor._destination_label(root, dest("/tmp/proj/app/src/test/java/com/demo/lib", "com.demo.lib"))
local lib_main, lib_main_dir =
  refactor._destination_label(root, dest("/tmp/proj/lib/src/main/java/com/demo/lib", "com.demo.lib"))
local default_pkg = refactor._destination_label(root, dest("/tmp/proj/app/src/main/java", nil, true))

assert(app_test == "com.demo.lib  [app/src/test/java/com/demo/lib]", app_test)
assert(lib_main == "com.demo.lib  [lib/src/main/java/com/demo/lib]", lib_main)
assert(app_test ~= lib_main, "destinos de source roots diferentes não podem colidir")
assert(app_test_dir == "/tmp/proj/app/src/test/java/com/demo/lib", app_test_dir)
assert(lib_main_dir == "/tmp/proj/lib/src/main/java/com/demo/lib", lib_main_dir)
assert(default_pkg == "(default package)  [app/src/main/java]", default_pkg)

print("move_destination_label_spec: OK")
