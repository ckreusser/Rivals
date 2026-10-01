from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
xml = (ROOT / "Bindings.xml").read_text()
lua = (ROOT / "Bindings.lua").read_text()
toc = (ROOT / "Rivals.toc").read_text()

assert 'name="RIVALS_OPEN_OVERVIEW"' in xml
assert 'category="ADDONS"' in xml, 'binding must appear inside Blizzard\'s AddOns keybinding category'
assert 'header="BLANK13"' in xml, 'Rivals binding should have a one-row visual buffer above it'
assert 'HEADER_RIVALS' not in xml, 'do not create a standalone Rivals header/category row'
assert 'Rivals_OpenOverview()' in xml
assert 'BINDING_NAME_RIVALS_OPEN_OVERVIEW = "Open Rivals Overview"' in lua
assert 'DP.SelectDuelView("Overview")' in lua
assert 'DP.GetDuelView() == "Overview"' in lua
assert 'DP.ToggleRivalsCharacterPanel()' in lua
assert 'SetOverviewMode' not in lua, "keybind must preserve the user-selected Overview carousel"
views = (ROOT / "Views.lua").read_text()
assert 'DP.GetDuelView = function() return current end' in views

assert 'function DP.GetOverviewKeybindText()' in lua
assert 'function DP.OpenOverviewKeybindSettings()' in lua
assert 'Settings.KEYBINDINGS_CATEGORY_ID' in lua
assert 'initializer.data.name == targetName' in lua
assert 'Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, targetName)' in lua
assert 'Overview keybind: ' in views
assert 'UPDATE_BINDINGS' in views
assert 'Bindings.lua' in toc
assert 'Bindings.xml' not in toc, 'Bindings.xml is auto-loaded by WoW and must not be listed in the TOC'
print("PASS: Rivals Overview keybinding preserves the selected carousel")
