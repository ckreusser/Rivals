local _, DP = ...

BINDING_NAME_RIVALS_OPEN_OVERVIEW = "Open Rivals Overview"

local function DisplayBindingKey(key)
    if not key or key == "" then return nil end
    if GetBindingText then
        local text = GetBindingText(key)
        if text and text ~= "" then return text end
    end
    return key
end

function DP.GetOverviewKeybindText()
    if not GetBindingKey then return "Not Bound" end
    local key1, key2 = GetBindingKey("RIVALS_OPEN_OVERVIEW")
    local first, second = DisplayBindingKey(key1), DisplayBindingKey(key2)
    if first and second then return first .. " / " .. second end
    return first or second or "Not Bound"
end

function DP.OpenOverviewKeybindSettings()
    -- The modern Settings keybinding page groups addon bindings under the built-in
    -- AddOns expandable section. Mirror Blizzard's own navigation pattern: expand
    -- that initializer first, then open/scroll the Keybindings category to it.
    if C_AddOns and C_AddOns.LoadAddOn then
        if not SettingsPanel then pcall(C_AddOns.LoadAddOn, "Blizzard_Settings") end
        if not (Settings and Settings.KEYBINDINGS_CATEGORY_ID) then
            pcall(C_AddOns.LoadAddOn, "Blizzard_SettingsDefinitions_Frame")
        end
    end

    if Settings and Settings.KEYBINDINGS_CATEGORY_ID and Settings.OpenToCategory then
        local targetName = (type(ADDONS) == "string" and ADDONS) or "AddOns"
        if SettingsPanel and SettingsPanel.GetCategory and SettingsPanel.GetLayout then
            local category = SettingsPanel:GetCategory(Settings.KEYBINDINGS_CATEGORY_ID)
            local layout = category and SettingsPanel:GetLayout(category)
            if layout and layout.EnumerateInitializers then
                for _, initializer in layout:EnumerateInitializers() do
                    if initializer.data and initializer.data.name == targetName then
                        initializer.data.expanded = true
                        Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, targetName)
                        return true
                    end
                end
            end
        end
        Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)
        return true
    end

    -- Older/alternate Classic UI fallback. It may not be able to scroll directly
    -- to AddOns, but still lands the user in the keybinding screen.
    if KeyBindingFrame then
        if ShowUIPanel then ShowUIPanel(KeyBindingFrame) else KeyBindingFrame:Show() end
        return true
    end
    return false
end

function DP.OpenSelectedOverview()
    -- Treat the binding as a real toggle only when Rivals is already visible on
    -- Overview. If another Rivals view is open, the same key returns to Overview.
    local overviewOpen = DP.characterPanel and DP.characterPanel:IsShown()
        and CharacterFrame and CharacterFrame:IsShown()
        and DP.GetDuelView and DP.GetDuelView() == "Overview"
    if overviewOpen and DP.ToggleRivalsCharacterPanel then
        return DP.ToggleRivalsCharacterPanel()
    end

    -- Do not change the Overview carousel mode here. WorldPvP owns and persists
    -- the user's current Duels/World PvP selection; the keybind should reopen it.
    if DP.SelectDuelView then DP.SelectDuelView("Overview") end
    if DP.ShowRivalsCharacterPanel then return DP.ShowRivalsCharacterPanel() end
    return false
end

function Rivals_OpenOverview()
    if DP.OpenSelectedOverview then return DP.OpenSelectedOverview() end
end
