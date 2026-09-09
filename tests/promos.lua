local savedDB, savedSend, savedChannel = RivalsDB, SendChatMessage, GetChannelName
local savedControl, savedShift = IsControlKeyDown, IsShiftKeyDown
RivalsDB = {schemaVersion = 1}
local control, shift, channel, sends = false, false, 4, {}
IsControlKeyDown = function() return control end
IsShiftKeyDown = function() return shift end
GetChannelName = function(id) assert(id == 4); return channel end
SendChatMessage = function(text, kind, language, target)
    assert(kind == "CHANNEL" and language == nil and target == 4)
    assert(#text <= 255 and not text:find("cooldown"))
    sends[#sends + 1] = text
end
local click = RivalsCharacterPanel.logoFrame.scripts.OnMouseUp
assert(click == DP.Promos.Click and DP.Inspect.panel.logoFrame.scripts.OnMouseUp == click)
click(nil, "LeftButton")
control = true; click(nil, "LeftButton")
control, shift = false, true; click(nil, "LeftButton")
control = true; click(nil, "RightButton")
assert(#sends == 0 and RivalsDB.nextPromo == nil)
channel = 0; click(nil, "LeftButton")
assert(#sends == 0 and RivalsDB.nextPromo == nil)
channel = 4
for i = 1, 8 do
    click(nil, "LeftButton")
    assert(sends[i] == DP.Promos.messages[(i - 1) % 7 + 1] .. " " .. DP.Promos.url)
end
assert(RivalsDB.nextPromo == 2)
SendChatMessage = function() error("unavailable") end
click(nil, "LeftButton"); assert(RivalsDB.nextPromo == 2)
SendChatMessage = function() return false end
click(nil, "LeftButton"); assert(RivalsDB.nextPromo == 2)
RivalsDB, SendChatMessage, GetChannelName = savedDB, savedSend, savedChannel
IsControlKeyDown, IsShiftKeyDown = savedControl, savedShift
print("PASS: logo modifier gating, exact /4 routing, seven approved promos, wrapping, saved cursor, message lengths and send failures")
