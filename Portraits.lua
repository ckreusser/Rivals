local _, DP = ...
local P = {}
DP.Portraits = P
local slots = {1, 3, 4, 5, 15, 19} -- head, shoulders, shirt, chest, cloak, tabard
local attempts = setmetatable({}, {__mode = "k"})

-- Classic playable race IDs used to resolve saved opponents for the retained
-- session body cache.
local raceIDs = {
    Human = 1, Orc = 2, Dwarf = 3, NightElf = 4,
    Scourge = 5, Undead = 5, Tauren = 6, Gnome = 7, Troll = 8,
}

local function Call(object, method, ...)
    if object and type(object[method]) == "function" then
        local ok, value = pcall(object[method], object, ...)
        if ok then return value, true end
    end
end

local function Positive(value)
    return type(value) == "number" and value > 0 and value == math.floor(value)
end

-- Retire the old portrait-lab SavedVariables. Production now uses the
-- retained session body cache; these were diagnostic-only and can be large.
if RivalsDB then
    RivalsDB.portraitPrototypeSample = nil
    RivalsDB.portraitPrototypeSelfSample = nil
    RivalsDB.portraitPrototypeOpponentSample = nil
    RivalsDB.portraitPrototypeOpponentArchive = nil
    RivalsDB.portraitTextureProbe = nil
    RivalsDB.portraitDisplayProbe = nil
    RivalsDB.portraitRuntimeProbeText = nil
    RivalsDB.portraitLabReport = nil
end

local function ReadCapture(model)
    -- Final encounter capture can still be finishing after BuildRecord marks the
    -- identity frozen. A forced capture owns its already-bound model, so allow
    -- those bounded retries to finish instead of discarding the only chance to
    -- retain the opponent's actual gear.
    local pending = (model and model._rivalsPortraitPending) or P.pending
    if not pending or (pending.identity.portraitFrozen and not pending.allowFrozen) or not UnitGUID then return false end
    -- Nameplate/target tokens can disappear immediately after combat ends. Once
    -- SetUnit succeeded the model still contains that body; only reject the read
    -- if the token now points at a *different* GUID. A nil token is safe here.
    local liveGUID = UnitGUID(pending.unit)
    if liveGUID and liveGUID ~= pending.guid then return false end
    local ready = Call(model, "IsGeoReady")
    local snapshot = {version = 2, appearances = {}, items = {}, visible = {}, capturedAt = time and time() or 0}
    if UnitRace then
        local ok, localizedRace, raceFile, raceID = pcall(UnitRace, pending.unit)
        if ok then
            if type(raceID) == "number" and raceID > 0 then snapshot.raceID = raceID end
            if type(raceFile) == "string" and raceFile ~= "" then snapshot.raceFile = raceFile end
            if type(localizedRace) == "string" and localizedRace ~= "" then snapshot.race = localizedRace end
        end
    end
    if UnitSex then
        local ok, sex = pcall(UnitSex, pending.unit)
        if ok and (sex == 2 or sex == 3) then snapshot.sex = sex end
    end
    -- Retain the full 1..19 equipped item IDs as combat evidence. Portrait
    -- reconstruction still uses only the visual slots below; the extra IDs let
    -- History attribute ambiguous weapon/armor/ring/shield/trinket procs to the
    -- item the actor was actually wearing when the encounter was captured.
    if GetInventoryItemLink then
        for slot = 1, 19 do
            local ok, link = pcall(GetInventoryItemLink, pending.unit, slot)
            local item = ok and type(link) == "string" and tonumber(link:match("item:(%d+)"))
            if Positive(item) then snapshot.items[slot] = item end
        end
    end

    local count = 0
    for _, slot in ipairs(slots) do
        local appearance
        if ready ~= false then appearance = Call(model, "GetItemModifiedAppearanceID", slot) end
        if Positive(appearance) then
            snapshot.appearances[slot] = appearance
            count = count + 1
        elseif GetInventoryItemLink then
            local ok, link = pcall(GetInventoryItemLink, pending.unit, slot)
            local item = ok and type(link) == "string" and tonumber(link:match("item:(%d+)"))
            if Positive(item) then snapshot.items[slot] = item; count = count + 1 end
        end
        if type(model.IsSlotVisible) == "function" then
            local visible, vok = Call(model, "IsSlotVisible", slot)
            if vok and type(visible) == "boolean" then snapshot.visible[slot] = visible end
        end
    end
    -- No gear evidence means no reconstruction. Never save frames or RT handles.
    -- Replace atomically rather than mixing outfits from different observations.
    if count > 0 then
        snapshot.slotCount = count
        pending.identity.portraitAppearance = snapshot
        return true
    end
    return false
end

local function ConcealCaptureModel(model)
    -- DressUpModel's 3D render can remain visible despite frame SetAlpha(0).
    -- Keep loading enabled, but move the entire viewport outside UIParent and
    -- suppress the model renderer independently of the frame's opacity.
    Call(model, "SetClampedToScreen", false)
    Call(model, "SetAlpha", 0)
    Call(model, "SetModelAlpha", 0)
    Call(model, "EnableMouse", false)
    Call(model, "ClearAllPoints")
    Call(model, "SetPoint", "TOPRIGHT", UIParent, "BOTTOMLEFT", -256, -256)
end

local function ConfigureCaptureModel(model)
    if not model then return nil end
    model:SetSize(64, 64)
    model:Hide()
    ConcealCaptureModel(model)
    Call(model, "SetKeepModelOnHide", true)
    model:SetScript("OnModelLoaded", function(self)
        ConcealCaptureModel(self)
        ReadCapture(self)
    end)
    return model
end

local function NewCaptureModel()
    local ok, model = pcall(CreateFrame, "DressUpModel", nil, UIParent)
    if not ok or not model then return nil end
    return ConfigureCaptureModel(model)
end

local function AcquireForcedCaptureModel()
    P.forcedCaptureModels = P.forcedCaptureModels or {}
    for _, model in ipairs(P.forcedCaptureModels) do
        if not model._rivalsPortraitBusy then
            model._rivalsPortraitBusy = true
            return model
        end
    end
    -- A normal encounter rarely has more than a few simultaneously visible
    -- enemies, but keep this bounded so pathological fights cannot grow frames
    -- forever. Eight concurrent final snapshots is plenty for the UI use-case.
    if #P.forcedCaptureModels >= 8 then return nil end
    local model = NewCaptureModel()
    if not model then return nil end
    model._rivalsPortraitBusy = true
    P.forcedCaptureModels[#P.forcedCaptureModels + 1] = model
    return model
end

function P.Capture(identity, unit, force)
    if not identity or identity.portraitFrozen or not identity.guid or not UnitGUID or
        UnitGUID(unit) ~= identity.guid or not CreateFrame then return false end
    local now = GetTime and GetTime() or 0
    if not force and attempts[identity] and now - attempts[identity] < 3 then return false end
    attempts[identity] = now
    local model
    if force then
        -- Encounter finalization may need to snapshot several visible enemies at
        -- once. The old single shared model meant each enemy replaced the prior
        -- one's pending retry, so only the last participant could finish loading.
        model = AcquireForcedCaptureModel()
    else
        if not P.captureModel then P.captureModel = NewCaptureModel() end
        model = P.captureModel
    end
    if not model then return false end

    if not force then P.pending = nil end
    model._rivalsPortraitPending = nil
    Call(model, "ClearModel")
    Call(model, "SetAutoDress", true)
    -- Shown for loading, physically off-screen for safety. Never anchor these
    -- private capture models at screen center, even for a single render frame.
    ConcealCaptureModel(model)
    model:Show()

    -- Bind only after SetUnit succeeds; ClearModel/SetUnit may fire callbacks.
    local result, ok = Call(model, "SetUnit", unit, false, true)
    ConcealCaptureModel(model)
    if not ok or result == false then
        model:Hide()
        model._rivalsPortraitBusy = nil
        return false
    end

    local pending = {identity = identity, unit = unit, guid = identity.guid, allowFrozen = force and true or false}
    model._rivalsPortraitPending = pending
    if not force then P.pending = pending end
    local captured = ReadCapture(model)

    local function FinishCapture()
        if model._rivalsPortraitPending ~= pending then return end
        model:Hide()
        model._rivalsPortraitPending = nil
        model._rivalsPortraitBusy = nil
        if P.pending == pending then P.pending = nil end
    end

    if C_Timer and C_Timer.After then
        for _, delay in ipairs({.1, .4, 1}) do
            C_Timer.After(delay, function()
                if model._rivalsPortraitPending ~= pending then return end
                ReadCapture(model)
                if delay == 1 then FinishCapture() end
            end)
        end
    else
        FinishCapture()
    end
    return captured
end

local function Dress(model)
    local snapshot = model._rivalsAppearance
    if not snapshot or model._rivalsDressing then return end
    model._rivalsDressing = true
    Call(model, "Undress")
    local calls, matched, failed = 0, 0, 0
    for _, slot in ipairs(slots) do
        local appearance = snapshot.appearances and snapshot.appearances[slot]
        local item = snapshot.items and snapshot.items[slot]
        local visible = not snapshot.visible or snapshot.visible[slot] ~= false
        if visible and (Positive(appearance) or Positive(item)) then
            -- The in-game matrix established that numeric TryOn is the reliable
            -- replay path on a player-character base. Keep SetItemTransmogInfo as
            -- a fallback only for item-only snapshots or future client changes.
            local result, ok = Call(model, "TryOn", Positive(appearance) and appearance or ("item:" .. item))
            if (not ok or result == false or (type(result) == "number" and result ~= 0)) and
                    Positive(appearance) and model.SetItemTransmogInfo then
                result, ok = Call(model, "SetItemTransmogInfo", {
                    appearanceID = appearance, secondaryAppearanceID = 0, illusionID = 0,
                }, slot, false)
            end
            calls = calls + 1
            if not ok or result == false or (type(result) == "number" and result ~= 0) then failed = failed + 1 end
            local actual = Call(model, "GetItemModifiedAppearanceID", slot)
            if Positive(appearance) and actual == appearance then matched = matched + 1 end
        end
    end
    Call(model, "SetPortraitZoom", 1)
    Call(model, "SetCamDistanceScale", .88)
    Call(model, "SetRotation", 0, false)
    Call(model, "RefreshCamera")
    Call(model, "FreezeAnimation", 0, 0, 0)
    model._rivalsGearDiagnostic = calls .. " attempted, " .. matched .. " IDs verified, " .. failed .. " failed"
    model._rivalsDressing = nil

    local function Verify()
        if model._rivalsAppearance ~= snapshot then return end
        local verified, expected, detail = 0, 0, {}
        for _, slot in ipairs(slots) do
            local wanted = snapshot.appearances and snapshot.appearances[slot]
            local visible = not snapshot.visible or snapshot.visible[slot] ~= false
            if Positive(wanted) and visible then
                expected = expected + 1
                local actual = Call(model, "GetItemModifiedAppearanceID", slot)
                local info = Call(model, "GetItemTransmogInfo", slot)
                if type(info) == "table" and Positive(info.appearanceID) then actual = info.appearanceID end
                if actual == wanted then verified = verified + 1 end
                detail[#detail + 1] = slot .. ":" .. wanted .. "/" .. tostring(actual)
            end
        end
        model._rivalsGearVerified = verified
        model._rivalsGearExpected = expected
        model._rivalsGearDiagnostic = calls .. " attempted, " .. verified .. "/" .. expected .. " IDs verified, " .. failed .. " failed"
        model._rivalsGearReadback = table.concat(detail, " ")
        if model._rivalsDiagnosticChanged then model._rivalsDiagnosticChanged() end
    end
    Verify()
    if not model._rivalsVerifyScheduled and C_Timer and C_Timer.After then
        model._rivalsVerifyScheduled = true
        C_Timer.After(.15, Verify)
        C_Timer.After(.5, Verify)
        C_Timer.After(1, function() model._rivalsVerifyScheduled = nil; Verify() end)
    end
end

function P.Reset(model)
    if model then
        model._rivalsGeneration = (model._rivalsGeneration or 0) + 1
        model._rivalsAppearance = nil
        model._rivalsGearVerified = nil
        model._rivalsGearExpected = nil
        model._rivalsDiagnosticChanged = nil
        Call(model, "SetScript", "OnModelLoaded", nil)
        Call(model, "ClearModel")
        model:Hide()
    end
end

local function ResolveRace(identity, snapshot)
    local raceID = snapshot and tonumber(snapshot.raceID)
    if not Positive(raceID) then
        local race = snapshot and snapshot.raceFile or identity and identity.raceFile
        if not race and identity and DP.WorldPvP and DP.WorldPvP.RACE_KEY_BY_NAME then
            race = DP.WorldPvP.RACE_KEY_BY_NAME[tostring(identity.race or "")]
        end
        raceID = raceIDs[tostring(race or "")]
    end
    local sex = tonumber(snapshot and snapshot.sex or identity and (identity.portraitSex or identity.sex))
    if not Positive(raceID) or (sex ~= 2 and sex ~= 3) then return nil end
    return raceID, sex
end

-- Classic Era's working arbitrary-race portrait path is
-- ModelSceneActor:SetModelByUnit(..., customRaceID). It keeps the dressable
-- player-character renderer while the live donor supplies sex.
local DRESSUP_SCENE_ID = 596

local function UnitIsUsablePlayer(unit)
    if not unit or not UnitExists or not UnitExists(unit) then return false end
    if UnitIsPlayer and not UnitIsPlayer(unit) then return false end
    -- Let SetModelByUnit and the actor's own readiness decide whether it can
    -- load. A transient UI-readiness hint must not prevent even starting it.
    return true
end

local function UnitGuidEquals(unit, guid)
    if not guid or not UnitIsUsablePlayer(unit) or not UnitGUID then return false end
    local ok, value = pcall(UnitGUID, unit)
    return ok and value == guid
end

-- The actor race override keeps the donor unit's sex. Prefer the actual opponent
-- while it is still addressable (that also preserves their exact face/hair), then
-- any same-sex player as a body donor. The override supplies the saved race.
local observedDonorUnits = {}
local function FindBodyDonors(identity, sex, raceID)
    local units = {}
    local seen = {}
    local function Add(unit)
        if unit and not seen[unit] then seen[unit] = true; units[#units + 1] = unit end
    end
    Add("target"); Add("mouseover"); Add("focus"); Add("player")
    Add("targettarget"); Add("mouseovertarget"); Add("focustarget")
    -- Nameplate tokens are not limited to nameplate1..40. Preserve the actual
    -- tokens delivered by events and enumerate currently active nameplates.
    for unit in pairs(observedDonorUnits) do
        if UnitIsUsablePlayer(unit) then Add(unit) else observedDonorUnits[unit] = nil end
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do Add(plate.namePlateUnitToken) end
        end
    end
    for i = 1, 40 do Add("nameplate" .. i) end
    for i = 1, 4 do Add("party" .. i) end
    for i = 1, 40 do Add("raid" .. i) end

    -- Best possible source: the actual opponent. This retains their exact live
    -- customization and needs no race override at all.
    for _, unit in ipairs(units) do
        if UnitGuidEquals(unit, identity and identity.guid) then return unit, nil, true end
    end

    local sameRace, sameSex
    if UnitSex then
        for _, unit in ipairs(units) do
            if UnitIsUsablePlayer(unit) then
                local sok, value = pcall(UnitSex, unit)
                if sok and value == sex then
                    local unitRaceID
                    if UnitRace then
                        local rok, _, _, rid = pcall(UnitRace, unit)
                        if rok then unitRaceID = rid end
                    end
                    if unitRaceID == raceID and not sameRace then sameRace = unit end
                    if not sameSex then sameSex = unit end
                end
            end
        end
    end
    return sameRace, sameSex, false
end

local function EnsurePortraitScene(card)
    if not card then return nil end
    if card.portraitScene and card.portraitActor then return card.portraitScene, card.portraitActor end
    if not CreateFrame then return nil end
    local parent = card.portraitViewport or card.portraitFrame or card
    -- Classic Era has the ModelScene widget but not the Mainline dressing-room
    -- scene data that 596 relies on. Prefer the full frame template when it is
    -- available, then fall back to the mixin template/bare widget. We create a
    -- camera ourselves below, so rendering does not depend on scene 596 existing.
    local ok, scene = pcall(CreateFrame, "ModelScene", nil, parent, "ModelSceneFrameTemplate")
    if not ok or not scene then ok, scene = pcall(CreateFrame, "ModelScene", nil, parent, "ModelSceneMixinTemplate") end
    if not ok or not scene then ok, scene = pcall(CreateFrame, "ModelScene", nil, parent) end
    if not ok or not scene then return nil end

    -- Put the ModelScene exactly where the legacy DressUpModel portrait lived so
    -- OPPONENTS medallion placement stays unchanged.
    if card.portraitModel and type(scene.SetAllPoints) == "function" then
        scene:SetAllPoints(card.portraitModel)
    else
        scene:SetSize(46, 46)
        scene:SetPoint("CENTER", parent, "CENTER", 0, 0)
    end
    if scene.SetFrameLevel and parent.GetFrameLevel then scene:SetFrameLevel(parent:GetFrameLevel() + 1) end
    scene:EnableMouse(false)
    -- Portrait scenes must start paused. Previously the scene was created/shown
    -- live and only paused after dressing/framing, which allowed a fraction of an
    -- idle animation to play every time a history row was opened.
    if type(scene.SetPaused) == "function" then pcall(scene.SetPaused, scene, true, false) end
    -- Force the 3D renderer to honor the portrait viewport bounds. SetClipsChildren
    -- on the parent catches widget overflow; zero view insets keeps the scene's own
    -- render target aligned exactly to the 44px medallion viewport.
    if type(scene.SetViewInsets) == "function" then pcall(scene.SetViewInsets, scene, 0, 0, 0, 0) end
    scene:Show()

    -- Scene 596 is a Mainline dressing-room scene. Some Classic Era builds expose
    -- TransitionToModelSceneID but have no data for 596; the call then returns nil
    -- without creating either a camera or actor. Check the data first instead of
    -- treating a successful pcall as proof that the preset exists.
    local sceneReady = false
    local presetHasData = false
    if C_ModelInfo and type(C_ModelInfo.GetModelSceneInfoByID) == "function" then
        local qok, sceneType, cameraIDs, actorIDs = pcall(C_ModelInfo.GetModelSceneInfoByID, DRESSUP_SCENE_ID)
        presetHasData = qok and sceneType ~= nil and type(cameraIDs) == "table" and #cameraIDs > 0 and
            type(actorIDs) == "table" and #actorIDs > 0
    end
    if presetHasData and type(scene.TransitionToModelSceneID) == "function" then
        local immediate = _G.CAMERA_TRANSITION_TYPE_IMMEDIATE or 0
        local discard = _G.CAMERA_MODIFICATION_TYPE_DISCARD or 0
        pcall(scene.TransitionToModelSceneID, scene, DRESSUP_SCENE_ID, immediate, discard, true)
        sceneReady = type(scene.GetActiveCamera) == "function" and select(2, pcall(scene.GetActiveCamera, scene)) ~= nil
    end
    if presetHasData and not sceneReady and type(scene.SetFromModelSceneID) == "function" then
        pcall(scene.SetFromModelSceneID, scene, DRESSUP_SCENE_ID, true)
        sceneReady = type(scene.GetActiveCamera) == "function" and select(2, pcall(scene.GetActiveCamera, scene)) ~= nil
    end

    local actor
    if type(scene.GetPlayerActor) == "function" then
        local okActor, value = pcall(scene.GetPlayerActor, scene)
        if okActor then actor = value end
    end
    if not actor and type(scene.CreateActor) == "function" then
        local okActor, value = pcall(scene.CreateActor, scene)
        if okActor then actor = value end
    end
    if not actor then scene:Hide(); return nil end
    if type(actor.Show) == "function" then pcall(actor.Show, actor) end

    card.portraitScene, card.portraitActor = scene, actor
    card._portraitScenePreset = sceneReady and "dressup-596" or (presetHasData and "596-no-camera" or "classic-manual")
    return scene, actor
end

-- Classic Era exposes ModelSceneActor:SetModelByUnit(..., customRaceID), but its
-- ordinary DressUpFrame is still the old DressUpModel and the Mainline scene 596
-- may not exist. The 1.0.5 diagnostic proved this exact failure mode: actor loaded,
-- shown and 4/4 gear IDs verified while GetActiveCamera() remained nil. Build the
-- OrbitCamera ourselves so a valid reconstructed actor can actually be seen.
local function PrimeOrbitCamera(camera)
    if not camera then return end
    -- Classic's ModelSceneFrameTemplate can hand us a live OrbitCamera that did
    -- not pass through OrbitCameraMixin:ApplyFromModelSceneCameraInfo(). Its
    -- OnUpdate path nevertheless assumes these offsets are numeric and crashes
    -- every frame when either is nil. Always initialize them, including for an
    -- already-active template camera.
    if camera.panningXOffset == nil then camera.panningXOffset = 0 end
    if camera.panningYOffset == nil then camera.panningYOffset = 0 end
    if not camera.modelSceneCameraInfo then camera.modelSceneCameraInfo = {flags = 0} end

    -- A hand-created camera normally gets these from OnAdded. Be defensive on
    -- Era builds/templates that expose the mixin incompletely.
    if not camera.buttonModes then camera.buttonModes = {} end
    if type(camera.ResetDefaultInputModes) == "function" then
        pcall(camera.ResetDefaultInputModes, camera)
    end
end

local function EnsurePortraitCamera(scene)
    if not scene then return nil, "no-scene" end
    local camera
    if type(scene.GetActiveCamera) == "function" then
        local ok, value = pcall(scene.GetActiveCamera, scene)
        if ok and value then camera = value end
    end
    if camera then
        PrimeOrbitCamera(camera)
        return camera, "template-orbit"
    end

    if CameraRegistry and type(CameraRegistry.CreateCameraByType) == "function" and type(scene.AddCamera) == "function" then
        local ok, value = pcall(CameraRegistry.CreateCameraByType, CameraRegistry, "OrbitCamera")
        if ok and value then
            camera = value
            PrimeOrbitCamera(camera)
            local added = pcall(scene.AddCamera, scene, camera)
            if added and type(scene.SetActiveCamera) == "function" then pcall(scene.SetActiveCamera, scene, camera) end
            -- Give the camera a real info table when Classic has the generic camera
            -- preset Narcissus also uses. This keeps OrbitCamera:OnUpdate/UpdateLight
            -- safe. The portrait framing below overwrites target/orientation/zoom.
            if C_ModelInfo and type(C_ModelInfo.GetModelSceneCameraInfoByID) == "function" and
                    type(camera.ApplyFromModelSceneCameraInfo) == "function" then
                local iok, info = pcall(C_ModelInfo.GetModelSceneCameraInfoByID, 114)
                if iok and info then
                    pcall(camera.ApplyFromModelSceneCameraInfo, camera, info,
                        _G.CAMERA_TRANSITION_TYPE_IMMEDIATE or 1,
                        _G.CAMERA_MODIFICATION_TYPE_DISCARD or 1)
                end
            end
            PrimeOrbitCamera(camera)
            return camera, "manual-orbit"
        end
    end
    return nil, "no-orbit-camera"
end

local function ReadActorBounds(actor)
    if not actor or type(actor.GetActiveBoundingBox) ~= "function" then return nil end
    local ok, a, b, c, d, e, f = pcall(actor.GetActiveBoundingBox, actor)
    if not ok then return nil end
    -- Classic returns six numbers. Keep a Vector3 fallback for newer widget
    -- signatures so the same code remains harmless if Blizzard changes it.
    if type(a) == "number" and type(f) == "number" then return a, b, c, d, e, f end
    if a and b and type(a.GetXYZ) == "function" and type(b.GetXYZ) == "function" then
        local aok, ax, ay, az = pcall(a.GetXYZ, a)
        local bok, bx, by, bz = pcall(b.GetXYZ, b)
        if aok and bok then return ax, ay, az, bx, by, bz end
    end
end

local function CaptureActorBaseBounds(actor)
    local minX, minY, minZ, maxX, maxY, maxZ = ReadActorBounds(actor)
    if minX and maxZ then
        actor._rivalsBaseBounds = {minX, minY, minZ, maxX, maxY, maxZ}
        return true
    end
    return false
end

local function CopyBounds(bounds)
    if type(bounds) ~= "table" or #bounds < 6 then return nil end
    return {bounds[1], bounds[2], bounds[3], bounds[4], bounds[5], bounds[6]}
end

local function HoldActorPortrait(actor, scene)
    if not actor then return end
    -- Scene-level pause is not completely sticky on Classic when a shown
    -- ModelScene is reparented. Pause the actor itself too so the frozen pose
    -- survives parking/attachment without advancing an idle frame.
    if type(actor.SetPaused) == "function" then pcall(actor.SetPaused, actor, true, false) end
    if scene and type(scene.SetPaused) == "function" then pcall(scene.SetPaused, scene, true, false) end
end

local function FreezeActorPortrait(actor, scene)
    if not actor then return end
    -- Establish the neutral portrait pose only during hidden priming/dressing.
    -- Visible attachment must not call SetAnimation again: resetting the
    -- animation is itself capable of exposing a one-frame pose jump.
    if type(actor.StopAnimationKit) == "function" then pcall(actor.StopAnimationKit, actor) end
    if type(actor.SetAnimationBlendOperation) == "function" then
        local none = Enum and Enum.ModelBlendOperation and Enum.ModelBlendOperation.None or 0
        pcall(actor.SetAnimationBlendOperation, actor, none)
    end
    -- A tiny nonzero speed still advances looping stand/idle animation. That was
    -- the remaining source of visible motion on Human males, Night Elf females,
    -- and other models. Use a literal zero-speed stand pose before pausing.
    if type(actor.SetAnimation) == "function" then pcall(actor.SetAnimation, actor, 0, nil, 0, 0) end
    HoldActorPortrait(actor, scene)
end

local function ReassertPortraitLighting(scene)
    if not scene then return end
    -- OrbitCameraMixin can rewrite ModelScene lighting from its camera-info row
    -- during OnUpdate on Classic Era. That produces the synchronized red/orange
    -- pulse seen across otherwise frozen opponent portraits. Keep portrait light
    -- deliberately neutral and reassert it after Blizzard's own frame update.
    if type(scene.SetLightVisible) == "function" then pcall(scene.SetLightVisible, scene, true) end
    if type(scene.SetLightAmbientColor) == "function" then pcall(scene.SetLightAmbientColor, scene, .82, .82, .82) end
    if type(scene.SetLightDiffuseColor) == "function" then pcall(scene.SetLightDiffuseColor, scene, .72, .72, .72) end
    if type(scene.SetLightDirection) == "function" then pcall(scene.SetLightDirection, scene, -.35, -.8, -.45) end
    if type(scene.SetLightType) == "function" then
        local directional = Enum and Enum.ModelLightType and Enum.ModelLightType.Directional
        if directional == nil then directional = _G.LE_MODEL_LIGHT_TYPE_DIRECTIONAL end
        if directional ~= nil then pcall(scene.SetLightType, scene, directional) end
    end
end

local function SetupPortraitLighting(scene)
    if not scene then return end
    if type(scene.ClearFog) == "function" then pcall(scene.ClearFog, scene) end
    if type(scene.SetCameraNearClip) == "function" then pcall(scene.SetCameraNearClip, scene, .05) end
    if type(scene.SetCameraFarClip) == "function" then pcall(scene.SetCameraFarClip, scene, 100) end
    if type(scene.SetCameraFieldOfView) == "function" then pcall(scene.SetCameraFieldOfView, scene, 2 * math.atan((46 / 35) * math.tan(.30 / 2))) end
    ReassertPortraitLighting(scene)

    -- Do this once per scene. HookScript runs after the ModelScene's existing
    -- OnUpdate handler, so any camera-driven tint written that frame is replaced
    -- before the portrait is presented. Hidden/parked scenes are skipped.
    if not scene._rivalsPortraitLightingLock and type(scene.HookScript) == "function" then
        scene._rivalsPortraitLightingLock = true
        scene:HookScript("OnUpdate", function(self)
            if type(self.IsShown) == "function" and not self:IsShown() then return end
            local alpha = type(self.GetAlpha) == "function" and self:GetAlpha() or 1
            if alpha and alpha <= 0 then return end
            ReassertPortraitLighting(self)
        end)
    end
end

-- Vertical head composition, relative to the stable naked-body height. The
-- second value is the vertical span visible in the portrait, NOT a body zoom.
-- Broad shoulders and the donor's bounding-box width must never set head size.
local portraitHeadProfiles = {
    [1] = {center = .80, span = .25}, -- Human
    [2] = {center = .80, span = .30}, -- Orc, tusks
    [3] = {center = .76, span = .36}, -- Dwarf
    [4] = {center = .83, span = .27}, -- Night Elf, ears
    [5] = {center = .80, span = .29}, -- Undead posture
    [6] = {center = .82, span = .38}, -- Tauren horns
    [7] = {center = .67, span = .48}, -- Gnome's proportionally large head
    [8] = {center = .82, span = .34}, -- Troll ears/hair/tusks
}
-- Sex-specific dimensions come from the undressed body cache. Do not compensate
-- for dressed/stale bounds with a higher target: that can push the face below
-- the viewport. Further profile calibration needs actual client observations.
local portraitHeadSexProfiles = {}
local function HeadCameraProfile(raceID, base, sex)
    local variants = portraitHeadSexProfiles[tonumber(raceID)]
    local profile = (variants and variants[tonumber(sex)]) or
        portraitHeadProfiles[tonumber(raceID)] or portraitHeadProfiles[1]
    local height = math.max(.1, base[6] - base[3])
    return base[3] + height * profile.center,
        math.max(.75, height * profile.span / (2 * math.tan(.30 / 2)))
end

-- Read the model's own portrait focus, rather than deriving face location from
-- its full-body box. A single off-screen probe is used per model file/session;
-- it is cleared after reading. No textures, screenshots, or external files.
local nativePortraitCameras = {}
local function ReadNativePortraitTarget(model)
    if not (model.GetCameraTarget and model.MakeCurrentCameraCustom and model.SetPortraitZoom) then return nil end
    local function Read(zoom)
        Call(model, "RefreshCamera")
        Call(model, "SetPortraitZoom", zoom)
        Call(model, "MakeCurrentCameraCustom")
        local ok, x, y, z = pcall(model.GetCameraTarget, model)
        if ok and type(x) == "number" and type(y) == "number" and type(z) == "number" and
            x == x and y == y and z == z and math.abs(x) < 100 and math.abs(y) < 100 and z > 0 and z < 100 then
            return {x, y, z}
        end
    end
    local body, head = Read(0), Read(1)
    -- Reject getters that return the unchanged/default camera for both modes.
    local evidence = {body = body, head = head}
    if body and head and head[3] > body[3] + .01 then return head, evidence end
    return nil, evidence
end

local function RequestNativePortraitTarget(actor, callback)
    local fileID = Call(actor, "GetModelFileID")
    if not Positive(fileID) or not CreateFrame or not (C_Timer and C_Timer.After) then return nil, false end
    local cached = nativePortraitCameras[fileID]
    if cached then
        if cached.pending then cached.callbacks[#cached.callbacks + 1] = callback end
        return cached.target, cached.pending
    end
    cached = {pending = true, callbacks = {callback}}
    nativePortraitCameras[fileID] = cached
    local ok, model = pcall(CreateFrame, "PlayerModel", nil, UIParent)
    if not ok or not model then cached.pending = false; cached.callbacks = nil; return nil, false end
    Call(model, "SetSize", 64, 64)
    ConcealCaptureModel(model)
    Call(model, "SetPosition", 0, 0, 0)
    Call(model, "SetFacing", 0)
    Call(model, "SetModelScale", 1)
    local function Finish(target)
        if not cached.pending then return end
        cached.target, cached.pending = target, false
        Call(model, "SetScript", "OnModelLoaded", nil)
        Call(model, "ClearModel")
        Call(model, "Hide")
        local callbacks = cached.callbacks
        cached.callbacks = nil
        for _, ready in ipairs(callbacks) do if ready then ready() end end
    end
    local function Read()
        if not cached.pending then return end
        if Call(model, "GetModelFileID") ~= fileID then return end
        local target, evidence = ReadNativePortraitTarget(model)
        cached.evidence = evidence
        if target then Finish(target) end
    end
    Call(model, "SetScript", "OnModelLoaded", function()
        ConcealCaptureModel(model)
        C_Timer.After(.05, Read)
    end)
    Call(model, "Show")
    Call(model, "SetModel", fileID)
    ConcealCaptureModel(model)
    C_Timer.After(.1, Read)
    C_Timer.After(.4, Read)
    C_Timer.After(1, function() Read(); if cached.pending then Finish(nil) end end)
    return nil, true
end

local calibratedPortraitCameras = {
    ["1:2"] = {0.0332901100662825, 0.0906269440530419, 1.84545311927795, 1.83121285009363},
    ["1:3"] = {-0.0348058555461049, 0.0250795027303192, 1.75496909618378, 1.59262071978437},
    ["2:2"] = {0.216829130923255, 0.14593482478899, 1.85764322280884, 2.45708694861221},
    ["2:3"] = {-0.036490856134608, 0.059512271486673, 1.8151575088501, 2.13928807335739},
    ["3:2"] = {0.0152961329918686, 0.0611709152378916, 1.30513761043549, 1.82145488272498},
    ["3:3"] = {-0.0486477388462722, 0.0267894542776289, 1.29950250387192, 1.70987770965598},
    ["4:2"] = {0.0670286979573096, 0.0455107761621309, 2.1975418806076, 2.32003055148451},
    ["4:3"] = {0.0858056685938935, 0.100960789659118, 2.04545867443085, 1.91168416198217},
    ["5:2"] = {0.168356321146381, 0.144659749336346, 1.66101570129395, 2.0229975427046},
    ["5:3"] = {0.134875022044744, 0.0805391342403849, 1.63498954772949, 1.97624503938095},
    ["6:2"] = {0.352719936767911, 0.189962390678454, 1.69587683677673, 2.84072161011828},
    ["6:3"] = {0.22916661496533, 0.145100673558131, 1.93733444213867, 2.81284304322452},
    ["7:2"] = {0.0370596588976704, 0.0581141122504242, 0.812435185909271, 2.26898417331487},
    ["7:3"] = {0.0319607224851423, 0.0306379574003295, 0.732896077632904, 2.10917323654302},
    ["8:2"] = {0.351541489674527, 0.160648123359647, 2.03420701026916, 2.81604166644651},
    ["8:3"] = {0.0431299352213593, -0.0219815879527497, 2.1619503736496, 2.10525214284267},
}

local function EnsureSavedPortraitCalibrations()
    if P._savedPortraitCalibrationsLoaded then return end
    P._savedPortraitCalibrationsLoaded = true
    local saved = RivalsDB and RivalsDB.portraitTestResults or nil
    if type(saved) ~= "table" then return end
    for key, row in pairs(saved) do
        local targetX = tonumber(row and row.targetX)
        local targetY = tonumber(row and row.targetY)
        local targetZ = tonumber(row and row.targetZ)
        local distance = tonumber(row and row.distance)
        if targetX and targetY and targetZ and distance then
            calibratedPortraitCameras[tostring(key)] = {
                targetX = targetX,
                targetY = targetY,
                targetZ = targetZ,
                distance = distance,
                cameraPitchDegrees = tonumber(row.cameraPitchDegrees),
                actorYawDegrees = tonumber(row.actorYawDegrees),
            }
        end
    end
end

local function FrameActorPortrait(scene, actor)
    if not scene or not actor then return end
    if type(actor.Show) == "function" then pcall(actor.Show, actor) end
    if type(actor.SetAlpha) == "function" then pcall(actor.SetAlpha, actor, 1) end
    if type(actor.SetPosition) == "function" then pcall(actor.SetPosition, actor, 0, 0, 0) end
    -- Camera coordinates and cached bounds must share the raw model's origin
    -- and scale, even if a scene preset supplied different actor transforms.
    Call(actor, "SetUseCenterForOrigin", false)
    Call(actor, "SetScale", 1)

    SetupPortraitLighting(scene)
    local camera, cameraSource = EnsurePortraitCamera(scene)
    scene._rivalsCameraSource = cameraSource

    -- SetModelByUnit can finish asynchronously. Once bounds exist, frame the upper
    -- half from the actual model dimensions instead of assuming every Classic race
    -- is human-sized. Each race has its own head crop.
    -- Frame from the undressed player body, not the currently dressed bounds.
    -- Large shoulders/helms can otherwise push the active bounding box outward
    -- and make the same race jump between close-up and tiny portraits depending
    -- on the opponent's gear. The body pool retains this box from donor priming.
    local base = actor._rivalsBaseBounds
    local minX, minY, minZ, maxX, maxY, maxZ
    if type(base) == "table" and #base >= 6 then
        minX, minY, minZ, maxX, maxY, maxZ = base[1], base[2], base[3], base[4], base[5], base[6]
    else
        minX, minY, minZ, maxX, maxY, maxZ = ReadActorBounds(actor)
    end
    local targetX, targetY, targetZ, distance = 0, 0, 1.25, 7.5
    if minX and maxZ then
        local width = math.max(.5, maxX - minX)
        local depth = math.max(.5, maxY - minY)
        local height = math.max(1, maxZ - minZ)
        -- Player models share a stable root at the origin. Do not let hair,
        -- ears, beard, or an idle pose move the camera sideways/depth-wise.
        -- Bounding-box centers vary by donor customization even within the same
        -- race/sex and were making portraits drift around the medallion.
        targetX = 0
        targetY = 0
        -- Compose the head using a stable race profile. Gear and body breadth
        -- cannot change this projection; the camera sees a prescribed head span.
        targetZ, distance = HeadCameraProfile(scene._rivalsRaceID, {minX,minY,minZ,maxX,maxY,maxZ}, scene._rivalsSex)
        scene._rivalsBounds = string.format("%.2fx%.2fx%.2f", width, depth, height)
        scene._rivalsFraming = "race-head-span"
    else
        scene._rivalsBounds = "pending"
    end

    -- Live testing on Classic Era proved the relative facing for this scene is
    -- the opposite of the retail/Narcissus convention we initially borrowed:
    -- with the OrbitCamera at yaw=pi, actor yaw=pi shows the BACK of the head,
    -- +/-pi/2 shows the profiles, and actor yaw=0 faces the camera. Keep the
    -- camera fixed and use the measured Classic-facing value here.
    -- Blizzard's generated unit/NPC portraits are not straight-on mugshots. They
    -- use a mild three-quarter turn with the camera slightly above the face. Match
    -- that composition so reconstructed rivals read like native WoW portraits.
    EnsureSavedPortraitCalibrations()
    local actorYaw = math.rad(22)
    local cameraPitch = math.rad(-6)
    local nativeTarget = actor._rivalsNativePortraitTarget
    if nativeTarget then
        targetX = nativeTarget[1] * math.cos(actorYaw) - nativeTarget[2] * math.sin(actorYaw)
        targetY = nativeTarget[1] * math.sin(actorYaw) + nativeTarget[2] * math.cos(actorYaw)
        targetZ = nativeTarget[3]
        scene._rivalsFraming = "native-portrait-target"
    end
    local calibrated = calibratedPortraitCameras[tostring(scene._rivalsRaceID) .. ":" .. tostring(scene._rivalsSex)]
    if calibrated then
        if calibrated[1] then
            targetX, targetY, targetZ, distance = unpack(calibrated)
        else
            targetX = tonumber(calibrated.targetX) or targetX
            targetY = tonumber(calibrated.targetY) or targetY
            targetZ = tonumber(calibrated.targetZ) or targetZ
            distance = tonumber(calibrated.distance) or distance
            if tonumber(calibrated.cameraPitchDegrees) then cameraPitch = math.rad(tonumber(calibrated.cameraPitchDegrees)) end
            if tonumber(calibrated.actorYawDegrees) then actorYaw = math.rad(tonumber(calibrated.actorYawDegrees)) end
        end
        scene._rivalsFraming = "calibrated-race-sex"
    end
    if type(actor.SetYaw) == "function" then pcall(actor.SetYaw, actor, actorYaw) end
    if type(actor.SetPitch) == "function" then pcall(actor.SetPitch, actor, 0) end
    scene._rivalsActorYaw = actorYaw

    if camera then
        camera.panningXOffset, camera.panningYOffset = 0, 0
        if type(camera.SetTargetSpline) == "function" then pcall(camera.SetTargetSpline, camera, nil) end
        if type(camera.SetOrientationSpline) == "function" then pcall(camera.SetOrientationSpline, camera, nil) end
        if type(camera.SetZoomSpline) == "function" then pcall(camera.SetZoomSpline, camera, nil) end
        if type(camera.SetTarget) == "function" then pcall(camera.SetTarget, camera, targetX, targetY, targetZ) end
        if type(camera.SetMinZoomDistance) == "function" then pcall(camera.SetMinZoomDistance, camera, .75) end
        if type(camera.SetMaxZoomDistance) == "function" then pcall(camera.SetMaxZoomDistance, camera, 15) end
        if type(camera.SetZoomDistance) == "function" then pcall(camera.SetZoomDistance, camera, distance) end
        local cameraYaw = math.pi
        if type(camera.SetYaw) == "function" then pcall(camera.SetYaw, camera, cameraYaw) end
        if type(camera.SetPitch) == "function" then pcall(camera.SetPitch, camera, cameraPitch) end
        if type(camera.SetRoll) == "function" then pcall(camera.SetRoll, camera, 0) end
        scene._rivalsCameraYaw = cameraYaw
        scene._rivalsCameraPitch = cameraPitch
        if type(camera.SnapAllInterpolatedValues) == "function" then pcall(camera.SnapAllInterpolatedValues, camera) end
        if type(camera.UpdateCameraOrientationAndPosition) == "function" then
            pcall(camera.UpdateCameraOrientationAndPosition, camera)
        elseif type(camera.SynchronizeCamera) == "function" then
            pcall(camera.SynchronizeCamera, camera)
        end
        scene._rivalsPortraitZoom = distance
        scene._rivalsTargetZ = targetZ
    else
        -- Last-resort raw ModelScene camera. The normal Classic route above uses
        -- CameraRegistry, but this still produces a view on clients that expose the
        -- widget without the Lua camera registry.
        if type(scene.SetCameraPosition) == "function" then
            pcall(scene.SetCameraPosition, scene, targetX, targetY - distance, targetZ)
        end
        if type(scene.SetCameraOrientationByYawPitchRoll) == "function" then
            pcall(scene.SetCameraOrientationByYawPitchRoll, scene, math.pi, math.rad(-6), 0)
        end
        scene._rivalsPortraitZoom = distance
        scene._rivalsTargetZ = targetZ
    end

    if type(scene.SetViewTranslation) == "function" then pcall(scene.SetViewTranslation, scene, 0, 0) end
end


-- Session body cache ---------------------------------------------------------
--
-- Classic Era cannot serialize a player body across /reload: live player
-- DressUpModels report displayID 0, raw model files replay untextured, and the
-- ModelScene actor-info rows used by other WoW branches are absent here. What
-- *does* work is ModelSceneActor:SetModelByUnit(unit, ..., customRaceID): the
-- unit lends its sex/player skin pipeline and customRaceID supplies the race.
--
-- If no compatible unit exists, use a textured humanoid display of the recorded
-- race/sex. Bare ChrRaces displays (49/50/etc.) have no DisplayInfoExtra skin;
-- useActivePlayerCustomizations does NOT supply a usable skin on Era (1.0.88).
-- Allocate only for foreground requests; keep completed actors for reuse.
-- Joined CreatureDisplayInfo -> CreatureDisplayInfoExtra; UnitSex uses 2/3,
-- whereas the source Gender field uses 0/1. These bodies carry their own skins.
-- Data: https://github.com/ArtaDBM/DBC (see tests/portrait_body_displays.json).
-- API: Blizzard_APIDocumentationGenerated/FrameAPIModelSceneFrameActorBaseDocumentation.lua
local playerBodyDisplays = {
    [1] = {[2]={1294,1289,1408,1426,1437,1516,3703,1276}, [3]={3292,1287,1444,3485,4140,1295,1439,1441}},
    [2] = {[2]={1374,1275,1314,1323,1382,3890,1320,1375}, [3]={1360,1325,1358,1878,1333,1380,1381,1874}},
    [3] = {[2]={3053,1282,1354,1406,1847,3044,3046,3488}, [3]={1286,2286,1401,1620,1766,3062,3063,1404}},
    [4] = {[2]={1706,1703,1709,1770,2270,1729,1854,1896}, [3]={1937,1682,1710,1716,1719,1727,1702,1714}},
    [5] = {[2]={1599,1576,1583,1589,1606,2046,1027,1565}, [3]={1592,1415,1603,3130,1029,1593,1594,1601}},
    [6] = {[2]={2103,1904,3794,2026,2083,2084,2105,2106}, [3]={3820,2107,1905,2109,2579,3781,3797,3807}},
    [7] = {[2]={3055,1832,3110,4895,1930,2180,3040,3109}, [3]={3108,3119,3106,3121,3588,3120,3124,3125}},
    [8] = {[2]={4242,2025,4711,2588,4013,4047,4099,4228}, [3]={4231,1897,4087,2589,4089,4241,4357,4358}},
}
-- Stable across records, reloads, and click order. This is an approximation of
-- facial features, not recovered opponent customization data.
function P.BodyDisplay(identity, raceID, sex)
    local choices = playerBodyDisplays[raceID] and playerBodyDisplays[raceID][sex]
    if not choices then return nil end
    local key = tostring(identity and (identity.guid or identity.name) or "Rivals")
    local hash = 0
    for index = 1, #key do hash = (hash * 33 + string.byte(key, index)) % 104729 end
    return choices[(hash % #choices) + 1]
end
local BODY_POOL_LIMIT_PER_RACE = 6
local EXACT_BODY_LIMIT = 24
local bodyPool = {entries = {}, byKey = {}, frameBounds = {}}
-- Exact opponent bodies are retained separately from the generic race/sex donor
-- pool. SetModelByUnit(unit) clones the live player's face/hair/skin choices;
-- keeping that actor alive lets History preserve those choices for the rest of
-- the current UI session instead of reducing every same-race opponent to one
-- donor face. Blizzard does not expose those customization choices as a
-- serializable table, so this cache intentionally contains live widget state.
local exactBodies = setmetatable({}, {__mode = "k"})
local exactEntries = {}
bodyPool.exactBodies = exactBodies
bodyPool.exactEntries = exactEntries
P.bodyPool = bodyPool
local function BodyPoolKey(raceID, sex)
    return tostring(raceID) .. ":" .. tostring(sex)
end
local pendingBodyCards = setmetatable({}, {__mode = "k"})
local wantedPreparedCards = setmetatable({}, {__mode = "k"})
local refreshBodiesScheduled = false
local foregroundUntil = 0
local ResetPreparedEntry

-- A small session trace makes engine load stalls distinguishable from queue or
-- lease bugs after an in-game test. No per-frame logging or unbounded archive.
local traceSessionStarted
function P.TraceLoad(event, key, entry, reason)
    if not RivalsDB then return end
    local trace = RivalsDB.portraitLoadTrace
    if not traceSessionStarted or not trace or trace.version ~= "1.0.90" then
        local archive = RivalsDB.portraitLoadTraceArchive or {}
        RivalsDB.portraitLoadTraceArchive = archive
        if trace and trace.events and #trace.events > 0 then archive[#archive + 1] = trace end
        while #archive > 3 do table.remove(archive, 1) end
        trace = {version = "1.0.90", events = {}, startedAt = GetTime and GetTime() or 0,
            wallTime = date and date("%Y-%m-%d %H:%M:%S") or nil,
            build = GetBuildInfo and GetBuildInfo() or nil}
        RivalsDB.portraitLoadTrace = trace
        traceSessionStarted = true
    end
    local rows = trace.events
    local actor = entry and entry.actor
    local details
    if actor then
        details = {unit = entry.donorUnit, displayID = entry.displayID,
            requestedDisplayID = entry.requestedDisplayID, faceGUID = entry.faceGUID,
            tryOn = type(actor.TryOn) == "function",
            setItemInfo = type(actor.SetItemTransmogInfo) == "function",
            getAppearance = type(actor.GetItemModifiedAppearanceID) == "function",
            getItemInfo = type(actor.GetItemTransmogInfo) == "function",
            loaded = Call(actor, "IsLoaded"), geometryReady = Call(actor, "IsGeoReady"),
            modelFileID = Call(actor, "GetModelFileID"),
            gear = actor._rivalsGearReadback,
            binding = entry.bindingDiagnostic}
    end
    rows[#rows + 1] = {t = GetTime and GetTime() or 0, event = event, key = key,
        raceID = entry and entry.raceID, sex = entry and entry.sex,
        exact = entry and entry.exact or nil, bodies = #bodyPool.entries, reason = reason,
        source = entry and entry.bodySource, displayID = entry and entry.displayID,
        body = entry and entry.key and (entry.key .. "/" .. tostring(entry.variantIndex)) or nil,
        details = details}
    if event:find("failed", 1, true) or event:find("timeout", 1, true) then
        trace.failures = trace.failures or {}
        trace.failures[#trace.failures + 1] = rows[#rows]
        if #trace.failures > 20 then table.remove(trace.failures, 1) end
    end
    if #rows > 120 then table.remove(rows, 1) end
end

local function ForegroundBusy()
    if (GetTime and GetTime() or 0) < foregroundUntil then return true end
    for card in pairs(wantedPreparedCards) do
        if card._portraitViewportActive and (not card.IsShown or card:IsShown()) then return true end
    end
    for _, entries in ipairs({bodyPool.entries, exactEntries}) do
        for _, entry in ipairs(entries) do
            local card = entry.card
            if card and card._portraitViewportActive and (not card.IsShown or card:IsShown()) then return true end
        end
    end
    return false
end

local function WantedPreparedKey(key)
    if not key then return false end
    for card, wanted in pairs(wantedPreparedCards) do
        if card and wanted == key and card._portraitViewportActive then return true end
    end
    return false
end

function P.WantPrepared(card, identity)
    if not card or not identity then return nil end
    local key = P.CacheKey and P.CacheKey(identity) or nil
    if wantedPreparedCards[card] ~= key then
        local raceID, sex = ResolveRace(identity, identity.portraitAppearance)
        P.TraceLoad("requested", key, {raceID = raceID, sex = sex})
    end
    wantedPreparedCards[card] = key
    if P.WaitForBody then P.WaitForBody(card, identity) end
    foregroundUntil = (GetTime and GetTime() or 0) + 2
    return key
end

function P.ReleaseWanted(card)
    if not card then return end
    local key = wantedPreparedCards[card]
    wantedPreparedCards[card] = nil
    pendingBodyCards[card] = nil
    if not key or WantedPreparedKey(key) or not ResetPreparedEntry then return end
    for _, entries in ipairs({bodyPool.entries, exactEntries}) do
        for _, entry in ipairs(entries) do
            if not entry.card and entry.preparing and entry.reservedKey == key then
                P.TraceLoad("cancelled", key, entry)
                ResetPreparedEntry(entry)
            end
        end
    end
end

function P.WaitForBody(card, identity)
    if not card or not identity or not identity.portraitAppearance then return end
    local raceID, sex = ResolveRace(identity, identity.portraitAppearance)
    if raceID then pendingBodyCards[card] = {identity = identity, raceID = raceID, sex = sex} end
end

local function RefreshWaitingBodyCards()
    if refreshBodiesScheduled or not (C_Timer and C_Timer.After) then return end
    refreshBodiesScheduled = true
    C_Timer.After(.01, function()
        refreshBodiesScheduled = false
        local retry = {}
        for card, pending in pairs(pendingBodyCards) do
            if not card._portraitViewportActive or card.enemy ~= pending.identity then
                pendingBodyCards[card] = nil
            else
                local list = bodyPool.byKey[BodyPoolKey(pending.raceID, pending.sex)] or {}
                for _, entry in ipairs(list) do
                    if entry.ready and not entry.card then retry[#retry + 1] = {card, pending.identity}; break end
                end
            end
        end
        for _, row in ipairs(retry) do
            pendingBodyCards[row[1]] = nil
            -- Body readiness can start dressing immediately; don't wait for the
            -- UI's increasingly slow spinner retry interval to notice it.
            if P.PrepareImmediate then P.PrepareImmediate(row[2], true) end
            if DP.WorldPvP and DP.WorldPvP.ApplyOpponentPortrait then
                DP.WorldPvP.ApplyOpponentPortrait(row[1], row[2])
            end
        end
    end)
end

local function EnsureBodyPoolHolder()
    if bodyPool.holder then return bodyPool.holder end
    if not CreateFrame then return nil end
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(2, 2)
    holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
    if holder.EnableMouse then holder:EnableMouse(false) end
    if holder.SetAlpha then holder:SetAlpha(0) end
    holder:Show()
    bodyPool.holder = holder
    return holder
end

local function ParkBodyEntry(entry)
    if not entry or not entry.scene then return end
    local holder = EnsureBodyPoolHolder()
    if not holder then return end
    if type(entry.scene.SetAlpha) == "function" then pcall(entry.scene.SetAlpha, entry.scene, 0) end
    entry.scene:SetParent(holder)
    entry.scene:ClearAllPoints()
    entry.scene:SetSize(46, 46)
    entry.scene:SetPoint("CENTER", holder, "CENTER", 0, 0)
    if entry.scene.SetFrameLevel and holder.GetFrameLevel then
        entry.scene:SetFrameLevel(holder:GetFrameLevel() + 1)
    end
    entry.scene:Show()
end

local function ReleaseBodyEntry(card)
    if not card then return false end
    P.ReleaseWanted(card)
    card._portraitLoadRetryGeneration = (tonumber(card._portraitLoadRetryGeneration) or 0) + 1
    card._portraitCommittedKey = nil
    -- Scroll-out uses ReleaseBody directly, not ResetCard. Invalidate every
    -- outstanding dress/reveal callback before this actor can be borrowed again.
    card._portraitApplyToken = (tonumber(card._portraitApplyToken) or 0) + 1
    card._rivalsPortraitReady = nil
    local entry = card and card._portraitBodyEntry
    if not entry then return false end
    if entry.card ~= card then
        card._portraitBodyEntry, card.portraitScene, card.portraitActor = nil, nil, nil
        return false
    end
    entry.card = nil
    if entry.actor and type(entry.actor.SetOnModelLoadedCallback) == "function" then
        pcall(entry.actor.SetOnModelLoadedCallback, entry.actor, nil)
    end
    if entry.scene and type(entry.scene.SetPaused) == "function" then
        pcall(entry.scene.SetPaused, entry.scene, true, false)
    end
    entry.lastUsed = GetTime and GetTime() or 0
    ParkBodyEntry(entry)
    card._portraitBodyEntry = nil
    card.portraitScene = nil
    card.portraitActor = nil
    RefreshWaitingBodyCards()
    return true
end
P.ReleaseBody = ReleaseBodyEntry

local function AttachBodyEntry(card, entry)
    if not (card and entry and entry.scene and entry.actor) then return nil end
    if card._portraitBodyEntry and card._portraitBodyEntry ~= entry then
        ReleaseBodyEntry(card)
    end
    if entry.card and entry.card ~= card then return nil end
    entry.card = card
    entry.lastUsed = GetTime and GetTime() or 0
    card._portraitBodyEntry = entry
    card.portraitScene = entry.scene
    card.portraitActor = entry.actor
    card._portraitScenePreset = entry._portraitScenePreset or "retained-session-body"

    local parent = card.portraitViewport or card.portraitFrame or card
    -- Hide by alpha and hard-pause the ACTOR before reparenting. ModelScene's
    -- scene pause alone can briefly lose the race with Classic's renderer during
    -- SetParent; actor pause is persistent across the move.
    if type(entry.scene.SetAlpha) == "function" then pcall(entry.scene.SetAlpha, entry.scene, 0) end
    HoldActorPortrait(entry.actor, entry.scene)
    entry.scene:SetParent(parent)
    entry.scene:ClearAllPoints()
    if card.portraitModel and type(entry.scene.SetAllPoints) == "function" then
        entry.scene:SetAllPoints(card.portraitModel)
    else
        entry.scene:SetSize(46, 46)
        entry.scene:SetPoint("CENTER", parent, "CENTER", 0, 0)
    end
    if type(entry.scene.SetViewInsets) == "function" then pcall(entry.scene.SetViewInsets, entry.scene, 0, 0, 0, 0) end
    if entry.scene.SetFrameLevel and parent.GetFrameLevel then
        entry.scene:SetFrameLevel(parent:GetFrameLevel() + 1)
    end
    -- Reassert both pause layers after the parent/anchor move. The parked scene
    -- stays shown at alpha zero, so do not call Show() here: even a redundant
    -- Show on ModelScene can kick its animation/render lifecycle.
    HoldActorPortrait(entry.actor, entry.scene)
    return entry.scene, entry.actor
end

local function DonorKey(unit)
    if not unit then return nil end
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, unit)
        if ok and guid and not (issecretvalue and issecretvalue(guid)) then return tostring(guid) end
    end
    if UnitName then
        local ok, name, realm = pcall(UnitName, unit)
        if ok and name then return tostring(name) .. "-" .. tostring(realm or "") end
    end
    return tostring(unit)
end

local function PrimeBodyEntry(entry, captureBounds)
    if not (entry and entry.actor and entry.scene) then return end
    local actor, scene = entry.actor, entry.scene
    Call(actor, "SetUseCenterForOrigin", false)
    Call(actor, "SetScale", 1)

    -- Normalize every retained body to the exact same neutral stand pose *before*
    -- reading its dimensions. 1.0.34 captured GetActiveBoundingBox while the donor
    -- was still somewhere in its idle animation; that made two Human males, for
    -- example, get visibly different zoom/vertical framing.
    FreezeActorPortrait(actor, scene)

    if captureBounds then
        CaptureActorBaseBounds(actor)
        local key = BodyPoolKey(entry.raceID, entry.sex)
        -- All variants of one race/sex share one camera profile for the session.
        -- Later donor diversification changes face/hair/skin only, never portrait
        -- scale or placement. This makes same-race plaques line up consistently.
        if not bodyPool.frameBounds[key] and actor._rivalsBaseBounds then
            bodyPool.frameBounds[key] = CopyBounds(actor._rivalsBaseBounds)
        end
        entry.baseBounds = CopyBounds(bodyPool.frameBounds[key] or actor._rivalsBaseBounds)
        actor._rivalsBaseBounds = CopyBounds(entry.baseBounds)
    elseif entry.baseBounds then
        actor._rivalsBaseBounds = CopyBounds(entry.baseBounds)
    end

    if entry._cameraWaiting then return end
    local generation = entry._primeGeneration
    local target
    EnsureSavedPortraitCalibrations()
    local hasCalibration = calibratedPortraitCameras[BodyPoolKey(entry.raceID, entry.sex)] ~= nil
    if not hasCalibration then
        entry._cameraWaiting = true
        local pending
        target, pending = RequestNativePortraitTarget(actor, function()
            if entry.actor ~= actor or entry._primeGeneration ~= generation or entry.card then return end
            entry._cameraWaiting = nil
            PrimeBodyEntry(entry, false)
        end)
        if pending then entry.ready = nil; return end
        entry._cameraWaiting = nil
    end
    -- Every Classic race/sex currently has a calibrated production camera. In
    -- that normal path there is no reason to spend up to a second probing the
    -- native PlayerModel portrait camera first, because FrameActorPortrait would
    -- immediately replace that target with the saved calibration anyway.
    actor._rivalsNativePortraitTarget = target
    FrameActorPortrait(scene, actor)
    -- Bounded engine measurements for diagnosing framing after a normal reload.
    -- This records numeric camera data only, once per race/sex; no screen capture.
    if RivalsDB then
        if not RivalsDB.portraitCameraReport or RivalsDB.portraitCameraReport.version ~= "1.0.50" then
            RivalsDB.portraitCameraReport = {version = "1.0.50", entries = {}}
        end
        local fileID = Call(actor, "GetModelFileID")
        local cached = fileID and nativePortraitCameras[fileID]
        RivalsDB.portraitCameraReport.entries[BodyPoolKey(entry.raceID, entry.sex)] = {
            fileID = fileID, bounds = CopyBounds(entry.baseBounds),
            target = target, evidence = cached and cached.evidence,
            framing = scene._rivalsFraming, targetZ = scene._rivalsTargetZ,
            distance = scene._rivalsPortraitZoom,
        }
    end
    FreezeActorPortrait(actor, scene)
    entry.ready = entry.baseBounds ~= nil
    if entry.ready then
        entry.primeFailed = nil
        P.TraceLoad("body-ready", entry.reservedKey, entry)
        RefreshWaitingBodyCards()
    end
end

local function ScheduleBodyPrime(entry)
    if not (entry and entry.actor) then return end
    local actor = entry.actor
    local generation = (entry._primeGeneration or 0) + 1
    entry._primeGeneration = generation
    entry.primeFailed = nil
    local startedAt = GetTime and GetTime() or 0

    local function Normalize()
        if entry.actor ~= actor or entry.card or entry._primeGeneration ~= generation then return end
        if entry.ready or entry._normalizingGeneration == generation then return end
        if type(actor.IsLoaded) == "function" then
            local ok, loaded = pcall(actor.IsLoaded, actor)
            if not ok or not loaded then return end
        end
        entry._normalizingGeneration = generation
        -- SetModelByUnit can restore the donor's clothing after the pre-load
        -- Undress. Strip the LOADED model, then let geometry update before
        -- capturing bounds. Otherwise one donor's shoulders define every camera
        -- of this race/sex for the rest of the session.
        if type(actor.SetAutoDress) == "function" then pcall(actor.SetAutoDress, actor, false) end
        if type(actor.Undress) == "function" then pcall(actor.Undress, actor) end
        FreezeActorPortrait(actor, entry.scene)
        if C_Timer and C_Timer.After then
            C_Timer.After(.05, function()
                if entry.actor == actor and not entry.card and entry._primeGeneration == generation then
                    entry._normalizingGeneration = nil
                    PrimeBodyEntry(entry, true)
                end
            end)
        else
            entry._normalizingGeneration = nil
            PrimeBodyEntry(entry, true)
        end
    end

    entry._checkLoaded = Normalize
    -- A previous visible borrower must never leave a stale model-loaded closure
    -- attached to a pooled actor that is later reseeded from another donor.
    if type(actor.SetOnModelLoadedCallback) == "function" then
        pcall(actor.SetOnModelLoadedCallback, actor, Normalize)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(.10, Normalize)
        -- Model-loaded callbacks are not guaranteed after late streaming. Keep
        -- checking this actor, without restarting its model load every retry.
        local function Watch()
            if entry.actor ~= actor or entry.card or entry._primeGeneration ~= generation or entry.ready then return end
            Normalize()
            if (GetTime and GetTime() or 0) - startedAt >= 8 then
                entry.primeFailed = true
                P.TraceLoad("body-timeout", entry.reservedKey, entry)
                return
            end
            C_Timer.After(.20, Watch)
        end
        C_Timer.After(.32, Watch)
    else
        Normalize()
    end
end

local function SeedBodyEntry(entry, donorUnit, dormant, directOnly)
    if not (entry and entry.actor and Positive(entry.raceID) and (entry.sex == 2 or entry.sex == 3)) then return false end
    if entry.card then return false end
    -- Cancel the previous binding's callbacks even when this binding is rejected.
    entry._primeGeneration = (entry._primeGeneration or 0) + 1
    entry._normalizingGeneration, entry._checkLoaded, entry.ready = nil, nil, nil
    local actor = entry.actor
    entry.scene._rivalsRaceID = entry.raceID
    entry.scene._rivalsSex = entry.sex
    if type(entry.scene.SetAlpha) == "function" then pcall(entry.scene.SetAlpha, entry.scene, 0) end
    if type(actor.SetPaused) == "function" then pcall(actor.SetPaused, actor, false, false) end
    if type(entry.scene.SetPaused) == "function" then pcall(entry.scene.SetPaused, entry.scene, false, false) end
    if type(actor.SetOnModelLoadedCallback) == "function" then pcall(actor.SetOnModelLoadedCallback, actor, nil) end
    if type(actor.Undress) == "function" then pcall(actor.Undress, actor) end
    actor._rivalsBaseBounds = nil
    actor._rivalsNativePortraitTarget = nil
    entry._cameraWaiting = nil
    entry.baseBounds = nil
    local ok, result = false, "no compatible unit"
    entry.bodySource, entry.displayID = nil, nil
    entry.bindingDiagnostic = {}
    if not directOnly and (not entry.requestedDisplayID or UnitGuidEquals(donorUnit, entry.faceGUID)) and
            UnitIsUsablePlayer(donorUnit) and UnitSex(donorUnit) == entry.sex and
            type(actor.SetModelByUnit) == "function" then
        ok, result = pcall(actor.SetModelByUnit, actor, donorUnit, false, false, false, true, false, entry.raceID)
        entry.bindingDiagnostic.unit = {token=donorUnit, ok=ok, result=tostring(result)}
        if ok and result ~= false then entry.bodySource = "unit" end
    end
    if not ok or result == false then
        local choices = playerBodyDisplays[entry.raceID] and playerBodyDisplays[entry.raceID][entry.sex]
        local displayID = entry.requestedDisplayID or (choices and choices[1])
        if displayID and type(actor.SetModelByCreatureDisplayID) == "function" then
            -- Preserve this display's own skin/customizations. Applying the
            -- local player's customizations here produced white bodies on Era.
            ok, result = pcall(actor.SetModelByCreatureDisplayID, actor, displayID, false)
            entry.bindingDiagnostic.display = {id=displayID, customizations=false, ok=ok, result=tostring(result)}
            entry.displayID = displayID
            if ok and result ~= false then entry.bodySource = "display" end
        end
    end
    if not ok or result == false then
        if not entry.bindFailed then P.TraceLoad("body-bind-failed", nil, entry, tostring(result)) end
        entry.bindFailed, entry.primeFailed = true, true
        entry.retryAt = (GetTime and GetTime() or 0) + 1
        return false
    end
    entry.bindFailed, entry.retryAt = nil, nil
    entry.donorUnit = entry.bodySource == "unit" and donorUnit or nil
    entry.donorKey = entry.donorUnit and DonorKey(donorUnit) or nil
    -- Reseeding changes the underlying face/body. Any outfit prepared against
    -- the previous retained actor is no longer safe to show.
    entry._prepareGeneration = (tonumber(entry._prepareGeneration) or 0) + 1
    entry.preparing = nil
    entry.preparedKey = nil
    entry.preparedIdentityKey = nil
    entry.preparedReady = nil
    entry.ready = nil
    entry.seededAt = GetTime and GetTime() or 0
    entry.dormant = dormant and true or nil
    ParkBodyEntry(entry)
    if entry.dormant then
        HoldActorPortrait(actor, entry.scene)
        entry.scene:Hide()
        P.TraceLoad("body-retained", nil, entry)
    else
        P.TraceLoad("body-start", nil, entry, entry.bodySource == "display" and
            ("textured display " .. entry.displayID) or "live unit")
        ScheduleBodyPrime(entry)
    end
    return true
end

local function ActivateBodyEntry(entry)
    if not entry or not entry.dormant then return end
    entry.dormant = nil
    ParkBodyEntry(entry)
    Call(entry.actor, "SetPaused", false, false)
    Call(entry.scene, "SetPaused", false, false)
    P.TraceLoad("body-start", nil, entry, "retained donor template")
    ScheduleBodyPrime(entry)
end

local function CreateBodyEntry(raceID, sex, donorUnit, dormant, identity)
    if not (playerBodyDisplays[raceID] and playerBodyDisplays[raceID][sex]) then return nil end
    local holder = EnsureBodyPoolHolder()
    if not holder then return nil end
    local key = BodyPoolKey(raceID, sex)
    bodyPool.createRetryAt = bodyPool.createRetryAt or {}
    if (GetTime and GetTime() or 0) < (bodyPool.createRetryAt[key] or 0) then return nil end

    -- EnsurePortraitScene only needs portraitFrame/portraitModel fields, so a
    -- plain pool entry can use the same proven Classic camera/actor creation as
    -- a visible card. The holder is shown but alpha-zero so model loading is not
    -- deferred while nothing is on screen.
    local entry = {portraitFrame = holder, raceID = raceID, sex = sex, dormant = dormant and true or nil,
        requestedDisplayID = identity and P.BodyDisplay(identity, raceID, sex), faceGUID = identity and identity.guid}
    local scene, actor = EnsurePortraitScene(entry)
    if not scene or not actor or (type(actor.SetModelByUnit) ~= "function" and type(actor.SetModelByCreatureDisplayID) ~= "function") then
        if scene then scene:Hide() end
        P.TraceLoad("body-create-failed", nil, entry, not scene and "no scene/actor" or "SetModelByUnit unavailable")
        bodyPool.createRetryAt[key] = (GetTime and GetTime() or 0) + 1
        return nil
    end

    entry.scene, entry.actor = scene, actor
    entry.key = BodyPoolKey(raceID, sex)
    entry.createdAt = GetTime and GetTime() or 0
    local list = bodyPool.byKey[entry.key]
    if type(list) ~= "table" then list = {}; bodyPool.byKey[entry.key] = list end
    entry.variantIndex = #list + 1
    list[#list + 1] = entry
    bodyPool.entries[#bodyPool.entries + 1] = entry
    ParkBodyEntry(entry)

    if not SeedBodyEntry(entry, donorUnit, dormant) then
        -- A not-yet-ready live unit can reject binding. Retain this widget for
        -- the next attempt instead of allocating another ModelScene every tick.
        ParkBodyEntry(entry)
        if entry.dormant then HoldActorPortrait(actor, scene); scene:Hide() end
    end
    return entry
end


ResetPreparedEntry = function(entry)
    if not entry then return end
    entry._prepareGeneration = (tonumber(entry._prepareGeneration) or 0) + 1
    entry.preparing = nil
    entry.preparingPriority = nil
    entry.reservedKey = nil
    entry.preparedKey = nil
    entry.preparedIdentityKey = nil
    entry.preparedReady = nil
end

local function SeedExactBodyEntry(entry, identity, unit, raceID, sex)
    if not (entry and entry.actor and entry.scene and identity and UnitGuidEquals(unit, identity.guid)) then return false end
    local actor, scene = entry.actor, entry.scene
    entry.raceID, entry.sex = raceID, sex
    entry.exactIdentity = identity
    entry.exactIdentityKey = tostring(identity.guid or identity.name or identity)
    entry.lastExactUse = GetTime and GetTime() or 0
    scene._rivalsRaceID, scene._rivalsSex = raceID, sex
    if type(scene.SetAlpha) == "function" then pcall(scene.SetAlpha, scene, 0) end
    if type(actor.SetPaused) == "function" then pcall(actor.SetPaused, actor, false, false) end
    if type(scene.SetPaused) == "function" then pcall(scene.SetPaused, scene, false, false) end
    if type(actor.SetOnModelLoadedCallback) == "function" then pcall(actor.SetOnModelLoadedCallback, actor, nil) end
    if type(actor.Undress) == "function" then pcall(actor.Undress, actor) end
    actor._rivalsBaseBounds = nil
    actor._rivalsNativePortraitTarget = nil
    entry._cameraWaiting = nil
    entry.baseBounds = nil
    ResetPreparedEntry(entry)
    entry.ready = nil
    -- No customRaceID here: the point of this actor is to clone the actual unit's
    -- customization choices, not merely borrow another player's sex/body pipeline.
    local ok, result = pcall(actor.SetModelByUnit, actor, unit, false, false, false, true, false)
    if not ok or result == false then return false end
    entry.donorUnit = unit
    entry.donorKey = DonorKey(unit)
    ParkBodyEntry(entry)
    ScheduleBodyPrime(entry)
    exactBodies[identity] = entry
    return true
end

local function NewExactBodyEntry(identity, unit, raceID, sex)
    local holder = EnsureBodyPoolHolder()
    if not holder then return nil end
    local entry = {portraitFrame = holder, raceID = raceID, sex = sex, exact = true}
    local scene, actor = EnsurePortraitScene(entry)
    if not scene or not actor or type(actor.SetModelByUnit) ~= "function" then
        if scene then scene:Hide() end
        return nil
    end
    entry.scene, entry.actor = scene, actor
    entry.createdAt = GetTime and GetTime() or 0
    exactEntries[#exactEntries + 1] = entry
    ParkBodyEntry(entry)
    if not SeedExactBodyEntry(entry, identity, unit, raceID, sex) then
        exactEntries[#exactEntries] = nil
        scene:Hide()
        return nil
    end
    return entry
end

local function ReusableExactEntry()
    local candidate
    local desiredDisplay = P.BodyDisplay(identity, raceID, sex)
    for _, entry in ipairs(exactEntries) do
        if entry and not entry.card and not entry.preparing then
            if not candidate or (tonumber(entry.lastExactUse) or 0) < (tonumber(candidate.lastExactUse) or 0) then
                candidate = entry
            end
        end
    end
    return candidate
end

function P.RetainIdentityBody(identity, unit)
    if not (identity and identity.guid and UnitGuidEquals(unit, identity.guid) and UnitRace and UnitSex) then return false end
    local existing = exactBodies[identity]
    if existing and existing.actor and existing.scene then
        existing.lastExactUse = GetTime and GetTime() or existing.lastExactUse
        return true
    end
    -- Live capture is opportunistic; never start a batch of exact clones while
    -- the selected History encounter is waiting on the renderer.
    if ForegroundBusy() then return false end
    local rok, _, raceFile, raceID = pcall(UnitRace, unit)
    local sok, sex = pcall(UnitSex, unit)
    if not rok or not sok or not Positive(raceID) or (sex ~= 2 and sex ~= 3) then return false end
    identity.raceFile = identity.raceFile or raceFile
    identity.portraitSex = identity.portraitSex or sex

    local entry
    if #exactEntries < EXACT_BODY_LIMIT then
        entry = NewExactBodyEntry(identity, unit, raceID, sex)
    else
        entry = ReusableExactEntry()
        if entry then
            if entry.exactIdentity then exactBodies[entry.exactIdentity] = nil end
            entry.exactIdentity = nil
            entry.exactIdentityKey = nil
            if not SeedExactBodyEntry(entry, identity, unit, raceID, sex) then entry = nil end
        end
    end
    return entry ~= nil
end

local function BodyCount(raceID, sex)
    local list = bodyPool.byKey[BodyPoolKey(raceID, sex)]
    return type(list) == "table" and #list or 0
end

local function PortraitVariantIndex(identity, count)
    count = math.max(1, tonumber(count) or 1)
    local key = tostring(identity and (identity.guid or identity.name) or "Rivals")
    local hash = 0
    for index = 1, #key do hash = (hash * 33 + string.byte(key, index)) % 104729 end
    return (hash % count) + 1
end

local function FindFreeBody(raceID, sex, identity)
    local list = bodyPool.byKey[BodyPoolKey(raceID, sex)]
    if type(list) ~= "table" or #list == 0 then return nil end
    local preferred = PortraitVariantIndex(identity, #list)
    for offset = 0, #list - 1 do
        local index = ((preferred - 1 + offset) % #list) + 1
        local entry = list[index]
        if entry and entry.ready and entry.baseBounds and not entry.card and not entry.preparing and entry.scene and entry.actor then return entry end
    end
end

-- Remember addressable units, but do not bind eight models every time a new sex
-- is observed. Missing donors now have a direct display path, so startup warming
-- is unnecessary and competes with the encounter the user actually selected.
function P.ObserveUnit(unit)
    if not UnitIsUsablePlayer(unit) or not UnitSex then return 0, 0 end
    local ok, sex = pcall(UnitSex, unit)
    if not ok or (sex ~= 2 and sex ~= 3) then return 0, 0 end
    observedDonorUnits[unit] = true
    bodyPool.donorUnitBySex = bodyPool.donorUnitBySex or {}
    bodyPool.donorUnitBySex[sex] = unit
    -- Give the selected encounter the first request before retaining siblings.
    for card in pairs(wantedPreparedCards) do
        local identity = card.enemy
        local _, wantedSex = ResolveRace(identity, identity and identity.portraitAppearance)
        if card._portraitViewportActive and wantedSex == sex and P.PrepareImmediate then
            P.PrepareImmediate(identity, true)
        end
    end
    return 0, 0
end

function P.DiscoverDonors()
    for sex = 2, 3 do
        local sameRace, sameSex = FindBodyDonors(nil, sex, 1)
        local unit = sameRace or sameSex
        if unit then P.ObserveUnit(unit) end
    end
end

local function AcquireBodyEntry(card, raceID, sex, donorUnit, identity)
    local held = card and card._portraitBodyEntry
    if held and held.raceID == raceID and held.sex == sex and held.scene and held.actor then
        local scene, actor = AttachBodyEntry(card, held)
        return scene, actor, held
    elseif held then
        ReleaseBodyEntry(card)
    end

    local entry = FindFreeBody(raceID, sex, identity)
    if not entry and UnitIsUsablePlayer(donorUnit) then
        P.ObserveUnit(donorUnit)
        entry = FindFreeBody(raceID, sex, identity)
        -- The viewport should not need more than the retained four, but if a
        -- custom layout temporarily asks for another visible body while a donor
        -- is addressable, allow an overflow actor rather than dropping fidelity.
        if not entry then entry = CreateBodyEntry(raceID, sex, donorUnit) end
    end
    if not entry then return nil end
    local scene, actor = AttachBodyEntry(card, entry)
    if not scene or not actor then return nil end
    return scene, actor, entry
end

-- Capture the state even if no actor ever finishes priming. The previous report
-- was written only on success, making initialization failures invisible.
function P.SaveCameraReport(event)
    if not RivalsDB then return end
    local report = {version = "1.0.50", event = event, entries = {}}
    for raceID = 1, 8 do
        for sex = 2, 3 do
            local key = BodyPoolKey(raceID, sex)
            local list = bodyPool.byKey[key] or {}
            local row = {count = #list, ready = 0, waiting = 0, dormant = 0}
            report.entries[key] = row
            for _, entry in ipairs(list) do
                if entry.ready then row.ready = row.ready + 1 end
                if entry.dormant then row.dormant = row.dormant + 1 end
                if entry._cameraWaiting then row.waiting = row.waiting + 1 end
                if not row.fileID then
                    row.fileID = Call(entry.actor, "GetModelFileID")
                    local loaded, ok = Call(entry.actor, "IsLoaded")
                    row.loaded = ok and tostring(loaded) or "unavailable"
                    row.bounds = CopyBounds(entry.baseBounds)
                    row.primeGeneration = entry._primeGeneration
                    row.normalizing = entry._normalizingGeneration
                    local cached = row.fileID and nativePortraitCameras[row.fileID]
                    row.probePending = cached and cached.pending or false
                    row.evidence = cached and cached.evidence
                    row.target = cached and cached.target
                    row.framing = entry.scene and entry.scene._rivalsFraming
                    row.targetZ = entry.scene and entry.scene._rivalsTargetZ
                end
            end
        end
    end
    RivalsDB.portraitCameraReport = report
end

-- Seed the viewer's own sex automatically and opportunistically learn the
-- opposite sex from any player nameplate/target/mouseover seen later. This is
-- session-only by design: Blizzard does not expose a serializable player body.
if CreateFrame then
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("PLAYER_LOGOUT")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
    watcher:RegisterEvent("PLAYER_FOCUS_CHANGED")
    watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
    watcher:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    watcher:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_LOGOUT" or (event == "ADDON_LOADED" and unit == "Rivals") then
            P.SaveCameraReport(event)
        elseif event == "PLAYER_ENTERING_WORLD" then
            P.DiscoverDonors()
        elseif event == "PLAYER_TARGET_CHANGED" then
            P.ObserveUnit("target")
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            P.ObserveUnit("mouseover")
        elseif event == "PLAYER_FOCUS_CHANGED" then
            P.ObserveUnit("focus")
        elseif event == "GROUP_ROSTER_UPDATE" then
            P.DiscoverDonors()
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            P.ObserveUnit(unit)
        end
    end)
    P.bodyPoolWatcher = watcher
end

local function ReadActorAppearance(actor, slot)
    local actual = Call(actor, "GetItemModifiedAppearanceID", slot)
    local info = Call(actor, "GetItemTransmogInfo", slot)
    if type(info) == "table" and Positive(info.appearanceID) then actual = info.appearanceID end
    return actual
end

local function DressActor(actor, snapshot, stableBaseBounds)
    if not actor or not snapshot then return "no actor" end
    if type(actor.SetAutoDress) == "function" then pcall(actor.SetAutoDress, actor, false) end
    if type(actor.SetUseTransmogChoices) == "function" then pcall(actor.SetUseTransmogChoices, actor, false) end
    if type(actor.SetObeyHideInTransmogFlag) == "function" then pcall(actor.SetObeyHideInTransmogFlag, actor, false) end
    if type(actor.Undress) == "function" then pcall(actor.Undress, actor) end
    -- Pooled actors already captured trustworthy naked body bounds while their
    -- donor model was fully loaded and unpaused. Do NOT overwrite those bounds
    -- immediately after Undress(): on Classic Era the bounding box often updates
    -- a frame later, so the immediate read can still describe the previous Rival's
    -- shoulders/helm. That stale box was the source of the random clipped/offset
    -- portraits seen when switching encounters.
    if stableBaseBounds then
        actor._rivalsBaseBounds = CopyBounds(stableBaseBounds)
    else
        CaptureActorBaseBounds(actor)
    end
    local attempted, verified, failed, expected = 0, 0, 0, 0
    local rows = {}
    local readback = {}
    actor._rivalsGearReadback = readback
    for _, slot in ipairs(slots) do
        local appearance = snapshot.appearances and snapshot.appearances[slot]
        local item = snapshot.items and snapshot.items[slot]
        local visible = not snapshot.visible or snapshot.visible[slot] ~= false
        if visible and (Positive(appearance) or Positive(item)) then
            attempted = attempted + 1
            local ok, result
            if type(actor.TryOn) == "function" then
                ok, result = pcall(actor.TryOn, actor, Positive(appearance) and appearance or ("item:" .. item))
            end
            local detail = {slot=slot, expected=appearance, itemID=item,
                tryOnOK=ok or false, tryOnResult=tostring(result)}
            readback[#readback + 1] = detail
            -- Some actor bindings ignore numeric TryOn without throwing. Use
            -- the explicit slot API on readback mismatch as well as rejection.
            if Positive(appearance) and ReadActorAppearance(actor, slot) ~= appearance and
                    type(actor.SetItemTransmogInfo) == "function" then
                ok, result = pcall(actor.SetItemTransmogInfo, actor, {
                    appearanceID=appearance, secondaryAppearanceID=0, illusionID=0,
                }, slot, false)
                detail.setItemOK, detail.setItemResult = ok, tostring(result)
            end
            if not ok or result == false or (type(result) == "number" and result ~= 0) then
                failed = failed + 1
            end
            if Positive(appearance) then
                expected = expected + 1
                local actual = ReadActorAppearance(actor, slot)
                detail.actual = actual
                if actual == appearance then verified = verified + 1 end
                rows[#rows + 1] = slot .. ":" .. appearance .. "/" .. tostring(actual)
            end
        end
    end
    return attempted .. " attempted, " .. verified .. "/" .. expected .. " IDs verified, " .. failed .. " failed",
        table.concat(rows, " "), attempted, verified, expected, failed
end

-- A visible History plaque must never be the place where an outfit is built.
-- ModelScene/TryOn settles asynchronously on Classic Era, so rebuilding after a
-- click exposes either a blank medallion or a few frames of movement. Prepare
-- bounded retained actors while the Rivals pane is opening, then only attach a
-- fully dressed, frozen actor to a visible card.
local function PortraitIdentityKey(identity)
    if not identity then return "?" end
    return tostring(identity.guid or identity.name or identity.id or "?")
end

local function PortraitSnapshotSignature(snapshot)
    if type(snapshot) ~= "table" then return "none" end
    local parts = {tostring(snapshot.raceID or ""), tostring(snapshot.sex or ""), tostring(snapshot.slotCount or 0)}
    for _, slot in ipairs(slots) do
        local appearance = snapshot.appearances and snapshot.appearances[slot] or ""
        local item = snapshot.items and snapshot.items[slot] or ""
        local visible = not snapshot.visible or snapshot.visible[slot] ~= false
        parts[#parts + 1] = tostring(slot) .. ":" .. tostring(appearance or "") .. ":" .. tostring(item or "") .. ":" .. (visible and "1" or "0")
    end
    return table.concat(parts, "|")
end

function P.CacheKey(identity)
    local snapshot = identity and identity.portraitAppearance
    local raceID, sex = ResolveRace(identity, snapshot)
    return PortraitIdentityKey(identity) .. "#" .. tostring(raceID or "?") .. ":" .. tostring(sex or "?") .. "#" .. PortraitSnapshotSignature(snapshot)
end

local function FindPreparedBody(raceID, sex, preparedKey)
    if not preparedKey then return nil end
    local list = bodyPool.byKey[BodyPoolKey(raceID, sex)] or {}
    for _, entry in ipairs(list) do
        if entry and entry.ready and entry.preparedReady and entry.preparedKey == preparedKey and
                not entry.card and not entry.preparing and entry.scene and entry.actor then
            return entry
        end
    end
end

local function FindExactPreparedBody(identity, raceID, sex, preparedKey)
    local entry = identity and exactBodies[identity]
    if entry and entry.ready and entry.preparedReady and entry.preparedKey == preparedKey and
            entry.raceID == raceID and entry.sex == sex and not entry.card and not entry.preparing and
            entry.scene and entry.actor then
        entry.lastExactUse = GetTime and GetTime() or entry.lastExactUse
        return entry
    end
end

local function ReservePreloadBody(raceID, sex, identity, preparedKey)
    if FindExactPreparedBody(identity, raceID, sex, preparedKey) or FindPreparedBody(raceID, sex, preparedKey) then
        return nil, true
    end
    local exact = identity and exactBodies[identity]
    local list = bodyPool.byKey[BodyPoolKey(raceID, sex)] or {}
    local function Matches(entry)
        return entry and not entry.card and entry.preparing and entry.reservedKey == preparedKey
    end
    if Matches(exact) then return nil, true end
    for _, entry in ipairs(list) do if Matches(entry) then return nil, true end end

    local function Available(entry)
        return entry and entry.ready and entry.baseBounds and not entry.card and entry.scene and entry.actor and
            (GetTime and GetTime() or 0) >= (entry.dressRetryAt or 0) and
            (entry.reservedKey == preparedKey or not WantedPreparedKey(entry.reservedKey or entry.preparedKey))
    end
    local candidate
    if exact and exact.raceID == raceID and exact.sex == sex and Available(exact) then
        candidate = exact
    else
        for _, entry in ipairs(list) do
            if Available(entry) and (not candidate or
                    (entry.displayID == desiredDisplay and candidate.displayID ~= desiredDisplay) or
                    ((entry.displayID == desiredDisplay) == (candidate.displayID == desiredDisplay) and
                     (tonumber(entry.lastUsed or entry.preparedAt) or 0) < (tonumber(candidate.lastUsed or candidate.preparedAt) or 0))) then
                candidate = entry
            end
        end
    end
    if candidate then
        -- A rapid encounter switch can abandon an in-flight dress operation.
        -- Its generation is cancelled before this actor serves the new card.
        ResetPreparedEntry(candidate)
        candidate.preparing = "reserved"
        candidate.preparingPriority = "foreground"
        candidate.reservedKey = preparedKey
        return candidate, false
    end
end

local function PrepareBodyEntry(entry, identity, snapshot, raceID, sex, preparedKey, priority)
    if not (entry and identity and snapshot and preparedKey) then return false end
    if entry.card or not entry.ready or not entry.actor or not entry.scene then entry.preparing = nil; return false end
    local actor, scene = entry.actor, entry.scene
    local generation = (tonumber(entry._prepareGeneration) or 0) + 1
    entry._prepareGeneration = generation
    entry.preparing = true
    entry.preparingPriority = priority == "foreground" and "foreground" or "background"
    entry.reservedKey = preparedKey
    entry.preparedReady = nil
    entry.preparedKey = nil
    entry.preparedIdentityKey = nil
    P.TraceLoad("dress-start", preparedKey, entry)
    if type(actor.SetOnModelLoadedCallback) == "function" then pcall(actor.SetOnModelLoadedCallback, actor, nil) end
    ParkBodyEntry(entry)
    scene._rivalsRaceID, scene._rivalsSex = raceID, sex
    if type(scene.SetAlpha) == "function" then pcall(scene.SetAlpha, scene, 0) end

    local lastVerified, lastExpected, lastFailed = 0, 0, 0
    local function Current()
        return entry._prepareGeneration == generation and entry.preparing and not entry.card and entry.actor == actor and entry.scene == scene
    end
    local function Pass(reframe)
        if not Current() then return end
        local _, _, _, verified, expected, failed = DressActor(actor, snapshot, entry.baseBounds)
        lastVerified, lastExpected = tonumber(verified) or 0, tonumber(expected) or 0
        lastFailed = tonumber(failed) or 0
        P.TraceLoad("dress-readback", preparedKey, entry)
        if reframe then FrameActorPortrait(scene, actor) end
        FreezeActorPortrait(actor, scene)
    end
    local function FinishPrepare(finalAttempt)
        if not Current() then return end
        -- Read again without Undress/TryOn: asynchronous equipment must be
        -- allowed to settle without restarting the same operation every poll.
        lastVerified = 0
        local latestReadback = {}
        for _, detail in ipairs(actor._rivalsGearReadback or {}) do
            local latest = {}
            for field, value in pairs(detail) do latest[field] = value end
            if Positive(detail.expected) then
                latest.actual = ReadActorAppearance(actor, detail.slot)
                if latest.actual == detail.expected then lastVerified = lastVerified + 1 end
            end
            latestReadback[#latestReadback + 1] = latest
        end
        actor._rivalsGearReadback = latestReadback
        if lastVerified < lastExpected or lastFailed > 0 then
            if not finalAttempt then return end
            P.TraceLoad("dress-failed", preparedKey, entry, lastVerified .. "/" .. lastExpected .. " verified; " .. lastFailed .. " rejected")
            ResetPreparedEntry(entry)
            entry.dressRetryAt = (GetTime and GetTime() or 0) + 2
            ParkBodyEntry(entry)
            return
        end
        entry.dressRetryAt = nil
        FreezeActorPortrait(actor, scene)
        if type(scene.SetPaused) == "function" then pcall(scene.SetPaused, scene, true, false) end
        entry.preparedKey = preparedKey
        entry.preparedIdentityKey = PortraitIdentityKey(identity)
        entry.preparedReady = true
        entry.preparing = nil
        entry.preparingPriority = nil
        entry.reservedKey = nil
        entry.preparedAt = GetTime and GetTime() or 0
        P.TraceLoad("prepared", preparedKey, entry, tostring(lastVerified) .. "/" .. tostring(lastExpected) .. " gear IDs verified")
        ParkBodyEntry(entry)
        if DP.WorldPvP and DP.WorldPvP.OnOpponentPortraitPrepared then
            pcall(DP.WorldPvP.OnOpponentPortraitPrepared, identity, preparedKey)
        end
    end

    Pass(true)
    if C_Timer and C_Timer.After then
        -- Most already-loaded retained actors verify their entire outfit on the
        -- first TryOn pass. Finish those quickly; only genuinely incomplete gear
        -- pays the longer retry window.
        C_Timer.After(.08, function()
            if not Current() then return end
            if lastExpected == 0 or lastVerified >= lastExpected then FinishPrepare()
            else Pass(false) end
        end)
        C_Timer.After(.17, function()
            if Current() and lastExpected > 0 and lastVerified < lastExpected then Pass(false) end
        end)
        C_Timer.After(.28, function() FinishPrepare(false) end)
        C_Timer.After(.60, function() FinishPrepare(false) end)
        C_Timer.After(1, function() FinishPrepare(true) end)
    else
        FinishPrepare(true)
    end
    return true
end

function P.PrepareImmediate(identity, allowEvict)
    local snapshot = identity and identity.portraitAppearance
    if not snapshot or not snapshot.slotCount or snapshot.slotCount < 1 then return false end
    local raceID, sex = ResolveRace(identity, snapshot)
    local preparedKey = raceID and P.CacheKey(identity) or nil
    if not (raceID and preparedKey) then return false end
    foregroundUntil = (GetTime and GetTime() or 0) + 2
    if FindExactPreparedBody(identity, raceID, sex, preparedKey) or FindPreparedBody(raceID, sex, preparedKey) then
        return true
    end
    local entry, already = ReservePreloadBody(raceID, sex, identity, preparedKey)
    if already then return true end
    if entry and entry.preparing == "reserved" and not entry.card then
        local desiredDisplay = P.BodyDisplay(identity, raceID, sex)
        local exactUnit = entry.bodySource == "unit" and identity.guid and entry.donorKey == identity.guid
        if not entry.exact and not exactUnit and entry.displayID ~= desiredDisplay then
            -- An actor's clothing and facial features are separate state. A
            -- recycled race/sex body must adopt this player's stable face before
            -- dressing, or every later rival inherits the first rival's face.
            ResetPreparedEntry(entry)
            entry.requestedDisplayID, entry.faceGUID = desiredDisplay, identity.guid
            entry.reseeded, entry.dressRetryAt = nil, nil
            SeedBodyEntry(entry, nil, false, true)
            entry.reservedKey = preparedKey
            return false
        end
        return PrepareBodyEntry(entry, identity, snapshot, raceID, sex, preparedKey, "foreground") and true or false
    end

    local list = bodyPool.byKey[BodyPoolKey(raceID, sex)] or {}
    for _, candidate in ipairs(list) do
        if not candidate.card and candidate.dressRetryAt and (GetTime and GetTime() or 0) < candidate.dressRetryAt then
            return false -- keep one rejected actor; do not allocate on every retry
        end
    end
    -- Reuse one initializing body, rather than creating four identical model
    -- loads in the first four spinner retries. Late callbacks also get a fresh
    -- readiness check here after the bounded priming watchdog has stopped.
    local pending
    for _, candidate in ipairs(list) do
        if not candidate.card and not candidate.ready then pending = candidate; break end
    end
    if pending and pending.dormant and not pending.bindFailed then ActivateBodyEntry(pending) end
    if pending and pending._checkLoaded then pending._checkLoaded() end
    if pending and not pending.primeFailed then return false end

    local exactOrSameRace, anySameSex = FindBodyDonors(identity, sex, raceID)
    local donor = exactOrSameRace or anySameSex
    if pending then
        -- One recovery attempt per retained widget. Switch a stalled unit bind
        -- to the independent display source instead of repeating the same bind.
        if pending.bindFailed then
            if (GetTime and GetTime() or 0) >= (pending.retryAt or 0) then SeedBodyEntry(pending, donor) end
        elseif not pending.reseeded then
            pending.reseeded = true
            P.TraceLoad("body-reseed", preparedKey, pending)
            SeedBodyEntry(pending, donor, false, pending.bodySource == "unit")
        end
    elseif #list < BODY_POOL_LIMIT_PER_RACE then
        local created = CreateBodyEntry(raceID, sex, donor, false, identity)
        if created then created.reservedKey = preparedKey end
    end
    return false
end

-- Compatibility entry point for integrations. Catalog-wide work is disabled;
-- visible cards use WantPrepared/PrepareImmediate directly.
function P.PreloadIdentities(identities, limit, allowEvict, priority)
    if type(identities) ~= "table" or priority ~= "foreground" then return 0 end
    local started = 0
    for index, identity in ipairs(identities) do
        if index > (tonumber(limit) or 1) then break end
        if P.PrepareImmediate(identity, allowEvict) then started = started + 1 end
    end
    return started
end

function P.IsPrepared(identity)
    local snapshot = identity and identity.portraitAppearance
    if not snapshot or not snapshot.slotCount or snapshot.slotCount < 1 then return true end
    local raceID, sex = ResolveRace(identity, snapshot)
    if not raceID then return false end
    local preparedKey = P.CacheKey(identity)
    if exactBodies[identity] and FindExactPreparedBody(identity, raceID, sex, preparedKey) then
        return true
    end
    return FindPreparedBody(raceID, sex, preparedKey) ~= nil
end

function P.ApplyPrepared(card, identity)
    local snapshot = identity and identity.portraitAppearance
    if not card or not snapshot or not snapshot.slotCount or snapshot.slotCount < 1 then return false end
    local raceID, sex = ResolveRace(identity, snapshot)
    if not raceID then return false end
    local preparedKey = P.CacheKey(identity)
    local entry = card._portraitBodyEntry
    if not (entry and entry.preparedReady and entry.preparedKey == preparedKey and entry.raceID == raceID and entry.sex == sex) then
        entry = exactBodies[identity] and FindExactPreparedBody(identity, raceID, sex, preparedKey) or nil
        if not entry then entry = FindPreparedBody(raceID, sex, preparedKey) end
    end
    if not entry then return false end
    local scene, actor = AttachBodyEntry(card, entry)
    if not scene or not actor then return false end
    card._portraitLoadRetryGeneration = (tonumber(card._portraitLoadRetryGeneration) or 0) + 1
    card._portraitApplyToken = (tonumber(card._portraitApplyToken) or 0) + 1
    local applyToken = card._portraitApplyToken
    P.TraceLoad("attached", preparedKey, entry)
    -- The actor was already posed/frozen during hidden preparation. Keep the
    -- ModelScene transparent for one UI tick after SetParent, because Classic can
    -- briefly reconsider actor pause state during the reparent itself. Re-hold
    -- first, then reveal. If a static fallback is being upgraded, leave it visible
    -- until this exact moment so there is never a blank medallion.
    HoldActorPortrait(actor, scene)
    if type(scene.SetAlpha) == "function" then pcall(scene.SetAlpha, scene, 0) end
    if card.portraitModel then card.portraitModel:Hide() end
    if card.portraitRoundCover then card.portraitRoundCover:Show() end
    local attachedEntry = entry
    -- Every Classic player model gets a short hidden settle after reparenting.
    -- SetParent can briefly resume a ModelScene even when both actor and scene
    -- were paused while parked. Keeping alpha at zero through two neutral-pose
    -- assertions prevents the momentary idle animation seen on Human males,
    -- Night Elf females, and several other combinations.
    FreezeActorPortrait(actor, scene)
    local function RevealFrozen()
        if card._portraitApplyToken ~= applyToken or card._portraitBodyEntry ~= attachedEntry or card.portraitScene ~= scene or card.portraitActor ~= actor then return end
        FreezeActorPortrait(actor, scene)
        if type(scene.SetAlpha) == "function" then pcall(scene.SetAlpha, scene, 1) end
        if card.portraitSpinnerFrame then
            card.portraitSpinnerFrame:Hide()
            card.portraitSpinnerFrame._phase = 0
        end
        card._portraitLoading = nil
        P.TraceLoad("revealed", preparedKey, entry)
        if card._portraitHideStaticOnReveal then
            card._portraitHideStaticOnReveal = nil
            if card.portrait then card.portrait:Hide() end
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(.025, function()
            if card._portraitApplyToken == applyToken and card._portraitBodyEntry == attachedEntry and card.portraitScene == scene and card.portraitActor == actor then
                FreezeActorPortrait(actor, scene)
            end
        end)
        C_Timer.After(.055, function()
            if card._portraitApplyToken == applyToken and card._portraitBodyEntry == attachedEntry and card.portraitScene == scene and card.portraitActor == actor then
                FreezeActorPortrait(actor, scene)
            end
        end)
        C_Timer.After(.085, RevealFrozen)
    else
        RevealFrozen()
    end
    P.ReleaseWanted(card)
    card._portraitReconstructed = true
    card._portraitBaseRaceID = raceID
    card._portraitBaseSex = sex
    card._portraitDiagnostic = (entry.exact and "prepared exact opponent portrait" or ("prepared retained portrait " .. tostring(entry.variantIndex or "?")))
    -- Some Classic clients reconsider pause state a frame after SetParent. Catch
    -- that with pause-only reassertions; never mutate the animation pose here.
    if C_Timer and C_Timer.After then
        local function Rehold()
            if card._portraitApplyToken == applyToken and card._portraitBodyEntry == attachedEntry and card.portraitScene == scene and card.portraitActor == actor then
                HoldActorPortrait(actor, scene)
            end
        end
        C_Timer.After(.03, Rehold)
        C_Timer.After(.10, Rehold)
        C_Timer.After(.22, Rehold)
    end
    return true
end

function P.ReassertFrozen(card)
    if not (card and card.portraitScene and card.portraitActor) then return false end
    -- Pause-only reassertion: safe on a visible portrait and incapable of the
    -- SetAnimation pose reset that caused the old flash.
    HoldActorPortrait(card.portraitActor, card.portraitScene)
    return true
end

local function ApplyActor(card, identity, snapshot, raceID, sex)
    local exactOrSameRace, anySameSex, exact = FindBodyDonors(identity, sex, raceID)
    local scene, actor, pooledEntry

    -- Production opponent cards borrow a retained race/sex body. If a same-sex
    -- player is visible now, seed all eight races before borrowing so the body
    -- remains available after that player leaves.
    if card._rivalsUsePortraitBodyPool then
        local donor = exactOrSameRace or anySameSex
        scene, actor, pooledEntry = AcquireBodyEntry(card, raceID, sex, donor, identity)
    end

    if not scene or not actor then
        scene, actor = EnsurePortraitScene(card)
    end
    if not scene or not actor then
        card._portraitDiagnostic = "ModelScene actor unavailable"
        return false
    end

    local function Finish(label)
        local token = (tonumber(card._portraitApplyToken) or 0) + 1
        card._portraitApplyToken = token
        local stableBounds = pooledEntry and pooledEntry.baseBounds or nil
        local function StillCurrent()
            return card._portraitApplyToken == token and
                card.portraitScene == scene and card.portraitActor == actor and
                (not pooledEntry or (card._portraitBodyEntry == pooledEntry and pooledEntry.card == card))
        end
        local lastVerified, lastExpected = 0, 0
        local revealed = false
        local function DressPass(reframe)
            if not StillCurrent() or revealed then return end
            scene._rivalsRaceID = raceID
            scene._rivalsSex = sex
            if type(scene.SetPaused) == "function" then pcall(scene.SetPaused, scene, true, false) end
            local diag, readback, _, verified, expected = DressActor(actor, snapshot, stableBounds)
            lastVerified, lastExpected = tonumber(verified) or 0, tonumber(expected) or 0
            card._portraitGearDiagnostic = diag
            card._portraitGearReadback = readback
            if reframe then FrameActorPortrait(scene, actor) end
            FreezeActorPortrait(actor, scene)
            if card._rivalsDiagnosticChanged then card._rivalsDiagnosticChanged() end
        end
        local function Reveal()
            if not StillCurrent() or revealed then return end
            -- Do not reveal on the same tick as the final Undress/TryOn pass.
            -- Classic can finish a model/appearance load just after TryOn returns,
            -- producing the brief shoulder/head twitch seen in 1.0.35. Keep the
            -- ModelScene transparent until it has spent a quiet interval frozen.
            FreezeActorPortrait(actor, scene)
            if type(scene.SetPaused) == "function" then pcall(scene.SetPaused, scene, true, false) end
            scene:Show()
            if type(scene.SetAlpha) == "function" then pcall(scene.SetAlpha, scene, 1) end
            revealed = true
            if type(card._rivalsPortraitReady) == "function" then
                local ready = card._rivalsPortraitReady
                card._rivalsPortraitReady = nil
                pcall(ready, card)
            end
        end
        -- Retained actors are already loaded and are reseeded later. Do not leave
        -- a card/snapshot closure installed on a pooled actor; that stale callback
        -- can redress the wrong rival the next time a new donor reseeds it.
        if not pooledEntry and type(actor.SetOnModelLoadedCallback) == "function" then
            pcall(actor.SetOnModelLoadedCallback, actor, function()
                DressPass(true)
                Reveal()
            end)
        elseif pooledEntry and type(actor.SetOnModelLoadedCallback) == "function" then
            pcall(actor.SetOnModelLoadedCallback, actor, nil)
        end

        -- Keep the already-shown scene alpha-zero while Undress/TryOn and the
        -- initial camera pass settle. Do not show a temporary generic portrait.
        if type(scene.SetAlpha) == "function" then pcall(scene.SetAlpha, scene, 0) end
        scene:Show()
        DressPass(true)
        if C_Timer and C_Timer.After then
            -- Never use "gear IDs verified" as permission to reveal immediately.
            -- Classic can report the right outfit before the actor has finished its
            -- asynchronous visual update. Retry only incomplete outfits, then keep
            -- the actor frozen through a real quiet interval before alpha becomes 1.
            C_Timer.After(.14, function()
                if not StillCurrent() or revealed then return end
                if lastExpected > 0 and lastVerified < lastExpected then DressPass(false)
                else FreezeActorPortrait(actor, scene) end
            end)
            C_Timer.After(.32, function()
                if not StillCurrent() or revealed then return end
                if lastExpected > 0 and lastVerified < lastExpected then DressPass(false)
                else FreezeActorPortrait(actor, scene) end
            end)
            C_Timer.After(.58, Reveal)
        else
            Reveal()
        end
        if card.portraitModel then card.portraitModel:Hide() end
        local actorLoaded = type(actor.IsLoaded) == "function" and select(2, pcall(actor.IsLoaded, actor)) or nil
        local actorShown = type(actor.IsShown) == "function" and select(2, pcall(actor.IsShown, actor)) or nil
        card._portraitDiagnostic = label ..
            "; scene=" .. tostring(card._portraitScenePreset) ..
            "; camera=" .. tostring(scene._rivalsCameraSource) ..
            "; loaded=" .. tostring(actorLoaded) .. "; shown=" .. tostring(actorShown) ..
            "; zoom=" .. tostring(scene._rivalsPortraitZoom) ..
            "; targetZ=" .. tostring(scene._rivalsTargetZ) ..
            "; framing=" .. tostring(scene._rivalsFraming) ..
            "; yaw=" .. tostring(scene._rivalsActorYaw) ..
            "; bounds=" .. tostring(scene._rivalsBounds)
        card._portraitReconstructed = true
        card._portraitBaseRaceID = raceID
        card._portraitBaseSex = sex
        return true
    end

    if pooledEntry then
        local source = pooledEntry.donorKey and ("; variant " .. tostring(pooledEntry.variantIndex or "?") .. " donor " .. tostring(pooledEntry.donorKey)) or ""
        return Finish("retained session body race " .. tostring(raceID) .. "/sex " .. tostring(sex) .. source)
    end

    -- 1) Exact opponent or a same-race/same-sex live player. SetModelByUnit is
    -- still the highest-fidelity player renderer when the necessary body exists.
    if exactOrSameRace and type(actor.SetModelByUnit) == "function" then
        local override = exact and nil or raceID
        local ok, result = pcall(actor.SetModelByUnit, actor, exactOrSameRace, false, false, false, true, false, override)
        if ok and result ~= false then
            return Finish(exact and "exact unit actor" or ("same-race body donor " .. exactOrSameRace))
        end
    end

    -- 2) Any same-sex live player can lend the sex and customRaceID supplies the
    -- saved race. This can inherit the donor's skin/hair, but it remains a real
    -- player renderer and therefore accepts composited armor.
    --
    -- Foreground History and the test panel use pooled bodies above, including
    -- direct player-display bindings with active customizations. This legacy
    -- unpooled path only handles addressable units.
    if anySameSex and type(actor.SetModelByUnit) == "function" then
        local ok, result = pcall(actor.SetModelByUnit, actor, anySameSex, false, false, false, true, false, raceID)
        if ok and result ~= false then
            return Finish("race " .. raceID .. " on same-sex donor " .. anySameSex)
        end
    end

    card._portraitDiagnostic = "no exact/same-race unit and no same-sex player donor"
    scene:Hide()
    return false
end


local function ApplyLegacyDressUp(card, identity, snapshot, raceID, sex)
    local model = card and card.portraitModel
    if not model or not model.TryOn or not model.SetUnit or not model.SetCustomRace then return false end
    P.Reset(model)
    local customGender = sex - 2
    Call(model, "ClearModel")
    local result, ok = Call(model, "SetUnit", "none", false)
    if not ok or result == false then return false end
    result, ok = Call(model, "SetCustomRace", raceID, customGender)
    if not ok or result == false then return false end
    model._rivalsAppearance = snapshot
    Dress(model)
    model:Show()
    card._portraitDiagnostic = "legacy DressUpModel custom-race path"
    card._portraitGearDiagnostic = model._rivalsGearDiagnostic
    card._portraitReconstructed = true
    card._portraitBaseRaceID = raceID
    card._portraitBaseSex = sex
    return true
end

function P.ResetCard(card)
    if not card then return end
    P.ReleaseWanted(card)
    if card.portraitRoundCover then card.portraitRoundCover:Hide() end
    pendingBodyCards[card] = nil
    card._portraitApplyToken = (tonumber(card._portraitApplyToken) or 0) + 1
    local released = ReleaseBodyEntry(card)
    if not released and card.portraitScene then card.portraitScene:Hide() end
    if card.portraitModel then P.Reset(card.portraitModel) end
    card._portraitDiagnostic = nil
    card._portraitGearDiagnostic = nil
    card._portraitGearReadback = nil
    card._portraitReconstructed = false
    card._portraitBaseRaceID = nil
    card._portraitBaseSex = nil
end

-- Rebuild a saved opponent portrait. ModelSceneActor is the primary Classic Era
-- path; the old SetCustomRace DressUpModel code remains only as a compatibility
-- fallback for clients where that deprecated method still exists.
function P.Apply(card, identity)
    local snapshot = identity and identity.portraitAppearance
    if not card or not snapshot or not snapshot.slotCount or snapshot.slotCount < 1 then return false end
    local raceID, sex = ResolveRace(identity, snapshot)
    if not raceID then card._portraitDiagnostic = "missing saved race/sex"; return false end
    P.ResetCard(card)
    if ApplyActor(card, identity, snapshot, raceID, sex) then
        if card.portraitRoundCover then card.portraitRoundCover:Show() end
        return true
    end
    local actorFailure = card._portraitDiagnostic
    if ApplyLegacyDressUp(card, identity, snapshot, raceID, sex) then
        if card.portraitRoundCover then card.portraitRoundCover:Show() end
        return true
    end
    card._portraitDiagnostic = tostring(actorFailure or "actor reconstruction failed") .. "; no legacy custom-race API"
    return false
end

-- Lightweight portrait-cache diagnostic. The experimental portrait lab and its
-- reconstruction matrices were removed after the retained-body path was proven
-- in production. Normal portrait capture/reconstruction is automatic.
SLASH_RIVALSPORTRAIT1 = "/rivalsportrait"
SlashCmdList = SlashCmdList or {}

function P.AdjustTestCamera(card, vertical, zoom, horizontal, pitchDegrees, actorRotationDegrees)
    if not card or not card._rivalsTest or not card.portraitScene or not card.portraitActor then return false end
    local scene, actor = card.portraitScene, card.portraitActor
    FrameActorPortrait(scene, actor)
    local camera = EnsurePortraitCamera(scene)
    if not camera or not camera.GetTarget then return false end
    local ok, x, y, z = pcall(camera.GetTarget, camera)
    if not ok or type(z) ~= "number" then return false end
    vertical = math.max(-2, math.min(2, tonumber(vertical) or 0))
    zoom = math.max(.5, math.min(2, tonumber(zoom) or 1))
    horizontal = math.max(-2, math.min(2, tonumber(horizontal) or 0))
    pitchDegrees = math.max(-40, math.min(40, tonumber(pitchDegrees) or 0))
    actorRotationDegrees = math.max(-90, math.min(90, tonumber(actorRotationDegrees) or 0))
    local targetX, targetY, targetZ = x, y, z + vertical
    if horizontal ~= 0 then
        if not camera.GetRightVector then return false end
        local rok, rx, ry, rz = pcall(camera.GetRightVector, camera)
        if not rok or type(rx) ~= "number" or type(ry) ~= "number" or type(rz) ~= "number" then return false end
        -- Move the camera opposite screen-right so a positive offset moves the
        -- portrait itself right, independent of the orbit camera's world yaw.
        targetX, targetY, targetZ = x-horizontal*rx, y-horizontal*ry, targetZ-horizontal*rz
    end
    local distance = math.max(.75, math.min(15, (scene._rivalsPortraitZoom or 1) * zoom))
    local baseCameraPitch = scene._rivalsCameraPitch or math.rad(-6)
    local cameraPitch = baseCameraPitch + math.rad(pitchDegrees)
    local baseActorYaw = scene._rivalsActorYaw or math.rad(22)
    local actorYaw = baseActorYaw + math.rad(actorRotationDegrees)
    Call(camera, "SetTarget", targetX, targetY, targetZ)
    Call(camera, "SetZoomDistance", distance)
    -- Orbit-camera pitch changes the camera's elevation around the same target
    -- while SetZoomDistance remains untouched, so this is a true fixed-distance
    -- above/below-face adjustment rather than another vertical pan.
    Call(camera, "SetPitch", cameraPitch)
    Call(actor, "SetYaw", actorYaw)
    HoldActorPortrait(actor, scene)
    Call(camera, "SnapAllInterpolatedValues")
    Call(camera, "UpdateCameraOrientationAndPosition")
    return true, {baseZ = z, targetZ = targetZ, targetX = targetX, targetY = targetY, distance = distance,
        vertical = vertical, horizontal = horizontal, zoom = zoom, framing = scene._rivalsFraming,
        pitchDeltaDegrees = pitchDegrees, cameraPitchDegrees = math.deg(cameraPitch),
        rotationDeltaDegrees = actorRotationDegrees, actorYawDegrees = math.deg(actorYaw)}
end

function P.TestBodyAvailable(raceID, sex)
    if FindFreeBody(raceID, sex, {name = "portrait-test"}) then return true end
    -- Calibration is also a foreground consumer; activate its chosen template.
    foregroundUntil = (GetTime and GetTime() or 0) + 2
    for _, entry in ipairs(bodyPool.byKey[BodyPoolKey(raceID, sex)] or {}) do
        if entry.dormant then ActivateBodyEntry(entry); return false end
    end
    if BodyCount(raceID, sex) == 0 then
        local sameRace, sameSex = FindBodyDonors(nil, sex, raceID)
        local donor = sameRace or sameSex
        CreateBodyEntry(raceID, sex, donor)
    end
    return false
end

function P.AddPortraitCover(parent)
    local cover = parent:CreateTexture(nil, "ARTWORK")
    cover:SetSize(56, 56)
    cover:SetPoint("CENTER")
    cover:SetTexture("Interface\\AddOns\\Rivals\\Textures\\PortraitRoundCover_v2.tga")
    cover:Hide()
    return cover
end

local function BodyPoolTotals(sex)
    local total, free = 0, 0
    for raceID = 1, 8 do
        local list = bodyPool.byKey[BodyPoolKey(raceID, sex)] or {}
        total = total + #list
        for _, entry in ipairs(list) do
            if not entry.card then free = free + 1 end
        end
    end
    return total, free
end

SlashCmdList.RIVALSPORTRAIT = function(message)
    local lower = string.lower(tostring(message or "")):match("^%s*(.-)%s*$")
    if lower == "test" then
        if P.OpenTest then P.OpenTest() end
        return
    end
    if lower == "loads" then
        local trace = RivalsDB and RivalsDB.portraitLoadTrace
        local rows = trace and trace.events or {}
        for index = math.max(1, #rows - 11), #rows do
            local row = rows[index]
            print(string.format("Rivals portrait %.2fs: %s  %s  %s  pool=%d%s", row.t or 0, row.event or "?",
                row.key and tostring(row.key):match("^[^#]+") or "",
                row.raceID and (tostring(row.raceID) .. ":" .. tostring(row.sex)) or "", row.bodies or 0,
                row.reason and (" (" .. tostring(row.reason) .. ")") or ""))
        end
        if #rows == 0 then print("Rivals: no portrait load events recorded yet.") end
        return
    end
    if lower == "pool warm" then
        local unit = UnitExists and UnitExists("target") and "target" or "player"
        local made, diversified = 0, 0
        if P.ObserveUnit then made, diversified = P.ObserveUnit(unit) end
        print("Rivals portrait cache: retained body templates from " .. tostring(unit) .. ".")
        return
    end
    if lower == "pool detail" then
        local raceNames = {"Human", "Orc", "Dwarf", "NightElf", "Undead", "Tauren", "Gnome", "Troll"}
        for _, sex in ipairs({2, 3}) do
            local label = sex == 2 and "male" or "female"
            local parts = {}
            for raceID = 1, 8 do
                local list = bodyPool.byKey[BodyPoolKey(raceID, sex)] or {}
                local free, donors = 0, {}
                for _, entry in ipairs(list) do
                    if not entry.card then free = free + 1 end
                    if entry.donorKey then donors[entry.donorKey] = true end
                end
                local unique = 0; for _ in pairs(donors) do unique = unique + 1 end
                parts[#parts + 1] = raceNames[raceID] .. "=" .. #list .. "/" .. free .. "f/" .. unique .. "v"
            end
            print("Rivals portrait " .. label .. ": " .. table.concat(parts, "  "))
        end
        return
    end
    if lower == "pool" or lower == "" then
        local male, maleFree = BodyPoolTotals(2)
        local female, femaleFree = BodyPoolTotals(3)
        print("Rivals portrait cache: male=" .. male .. " (" .. maleFree .. " free), female=" .. female .. " (" .. femaleFree .. " free).")
        return
    end
    print("Rivals portrait commands: /rivalsportrait test  |  loads  |  pool  |  pool detail  |  pool warm")
end

-- BEGIN PORTRAIT TEST PANEL
do
local _, DP = ...
local P = DP.Portraits
local races = {"Human", "Orc", "Dwarf", "Night Elf", "Undead", "Tauren", "Gnome", "Troll"}
local window

local function Sample(raceID, sex)
    local observers = RivalsDB and RivalsDB.observers or {}
    local fallback
    for _, observer in pairs(observers) do
        for _, record in ipairs(observer.worldPvP and observer.worldPvP.encounters or {}) do
            for _, enemy in ipairs(record.enemies or {}) do
                local a = enemy.portraitAppearance
                if a and (a.slotCount or 0) > 0 then
                    fallback = fallback or enemy
                    if (a.raceID == raceID or enemy.race == races[raceID]) and
                        (a.sex or enemy.portraitSex or enemy.sex) == sex then return enemy, false end
                end
            end
        end
    end
    return fallback, true
end

function P.OpenTest()
    if window then window:Show(); window:Refresh(); return end
    local f = CreateFrame("Frame", "RivalsPortraitTest", UIParent, "BackdropTemplate")
    window = f
    f:SetSize(630, 540); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16})
    f:SetBackdropColor(.035,.04,.05,1)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local function Label(text, x, y, width)
        local t=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        t:SetPoint("TOPLEFT",x,y); t:SetWidth(width); t:SetJustifyH("LEFT"); t:SetText(text); return t
    end
    local function Button(text,x,y,width,action)
        local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
        b:SetSize(width,24); b:SetPoint("TOPLEFT",x,y); b:SetText(text); b:SetScript("OnClick",action); return b
    end
    Label("Rivals portrait test - preview changes only",18,-18,570)
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT")
    close:SetScript("OnClick",function() f:Hide() end)
    UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,"RivalsPortraitTest")
    f.raceID, f.sex, f.settings = 1, 3, {}
    for raceID=1,8 do
        local r=raceID
        Label(races[r],18,-59-(r-1)*32,86)
        for sex=2,3 do
            local s=sex
            Button(s==2 and "Male" or "Female",106+(s-2)*62,-52-(r-1)*32,60,function()
                f.raceID,f.sex=r,s; f:Refresh()
            end)
        end
    end
    f.selection=Label("",275,-54,330)
    -- Same 46px viewport and 56px ring as History, enlarged uniformly for QA.
    local previewAnchor=CreateFrame("Frame",nil,f)
    previewAnchor:SetSize(140,140); previewAnchor:SetPoint("TOPLEFT",365,-82)
    local card=CreateFrame("Frame",nil,previewAnchor)
    card:SetSize(56,56); card:SetPoint("CENTER",previewAnchor,"CENTER",0,0); card:SetScale(2.5)
    card._rivalsUsePortraitBodyPool=true; card._rivalsTest=true
    card.portraitFrame=card
    card.portraitViewport=CreateFrame("Frame",nil,card)
    card.portraitViewport:SetSize(46,46); card.portraitViewport:SetPoint("CENTER")
    card.portraitViewport:SetClipsChildren(true)
    card.portraitModel=CreateFrame("DressUpModel",nil,card.portraitViewport)
    card.portraitModel:SetSize(46,46); card.portraitModel:SetPoint("CENTER"); card.portraitModel:Hide()
    local ringFrame=CreateFrame("Frame",nil,card); ringFrame:SetAllPoints(card)
    ringFrame:SetFrameLevel(card:GetFrameLevel()+30)
    card.portraitRoundCover = P.AddPortraitCover(ringFrame)
    local ring=ringFrame:CreateTexture(nil,"OVERLAY"); ring:SetAllPoints(card)
    ring:SetAtlas("AdventureMap-combatally-ring",false)
    f.status=Label("",275,-348,330)
    f.values=Label("",275,-392,330)
    Label("Select a race/sex. Preview helms are always hidden.\nTarget controls pan the face; Camera up/down orbits at a fixed distance.\nRotate changes character yaw. Saved calibrations resume after relogging.",18,-447,590)
    local function Settings()
        local key=f.raceID..":"..f.sex
        if not f.settings[key] then
            -- Restore the last explicitly saved calibration for this race/sex.
            -- These values live in RivalsDB, so exiting the game writes them to
            -- SavedVariables and a future test session resumes exactly where the
            -- user left off instead of silently returning to zeroed controls.
            local saved = RivalsDB and RivalsDB.portraitTestResults and RivalsDB.portraitTestResults[key]
            f.settings[key] = {
                vertical = tonumber(saved and saved.vertical) or 0,
                horizontal = tonumber(saved and saved.horizontal) or 0,
                zoom = tonumber(saved and saved.zoom) or 1,
                pitch = tonumber(saved and saved.pitchDeltaDegrees) or 0,
                rotation = tonumber(saved and saved.rotationDeltaDegrees) or 0,
            }
        end
        return f.settings[key], key
    end
    function f:Adjust()
        local s=Settings()
        local ok, result=P.AdjustTestCamera(card,s.vertical,s.zoom,s.horizontal,s.pitch,s.rotation)
        self.result=ok and result or nil
        if ok then
            self.values:SetText(string.format("Target V %+.3f | H %+.3f | zoom %.2fx\nCamera pitch %+.1f° | Character yaw %+.1f°\n%s",
                s.vertical,s.horizontal,s.zoom,result.cameraPitchDegrees or -6,result.actorYawDegrees or 22,result.framing or "unknown"))
        else self.values:SetText("Camera not ready.") end
    end
    function f:Refresh()
        self.generation=(self.generation or 0)+1
        local generation=self.generation
        P.ResetCard(card); self.result=nil
        self.selection:SetText(races[self.raceID].." / "..(self.sex==2 and "Male" or "Female"))
        self.values:SetText("")
        local sample, borrowed=Sample(self.raceID,self.sex)
        if not sample then self.status:SetText("No saved equipment samples available."); return end
        if not P.TestBodyAvailable(self.raceID,self.sex) then
            self.status:SetText("No free body ready. Target a "..(self.sex==2 and "male" or "female").." player, then click Retry."); return
        end
        local original=sample.portraitAppearance
        local snapshot={}
        for k,v in pairs(original) do snapshot[k]=v end
        -- The calibration tool is for face/camera composition, not gear QA.
        -- Clone the nested equipment tables before changing them so the saved
        -- encounter snapshot remains completely untouched, then suppress slot 1
        -- (head) for the preview only. Production History portraits still honor
        -- the opponent's real helm visibility exactly as captured.
        snapshot.appearances={}
        for k,v in pairs(original.appearances or {}) do snapshot.appearances[k]=v end
        snapshot.items={}
        for k,v in pairs(original.items or {}) do snapshot.items[k]=v end
        snapshot.visible={}
        for k,v in pairs(original.visible or {}) do snapshot.visible[k]=v end
        snapshot.appearances[1]=nil
        snapshot.items[1]=nil
        snapshot.visible[1]=false
        snapshot.raceID,snapshot.sex=self.raceID,self.sex
        local identity={name="portrait-test",portraitAppearance=snapshot}
        self.sampleName=sample.name
        if not P.Apply(card,identity) then self.status:SetText(card._portraitDiagnostic or "Reconstruction unavailable."); return end
        self.status:SetText("Gear: "..tostring(sample.name)..(borrowed and " (borrowed outfit)" or "").."\nBody face/hair are approximate.")
        card._rivalsPortraitReady=function()
            if f:IsShown() and f.generation==generation then f:Adjust() end
        end
        self:Adjust()
    end
    Button("Aim up",275,-225,75,function() local s=Settings(); s.vertical=math.min(2,s.vertical+.025); f:Adjust() end)
    Button("Aim down",352,-225,85,function() local s=Settings(); s.vertical=math.max(-2,s.vertical-.025); f:Adjust() end)
    Button("Zoom in",439,-225,75,function() local s=Settings(); s.zoom=math.max(.5,s.zoom-.05); f:Adjust() end)
    Button("Zoom out",516,-225,85,function() local s=Settings(); s.zoom=math.min(2,s.zoom+.05); f:Adjust() end)
    Button("Move left",275,-252,160,function() local s=Settings(); s.horizontal=math.max(-2,s.horizontal-.025); f:Adjust() end)
    Button("Move right",439,-252,160,function() local s=Settings(); s.horizontal=math.min(2,s.horizontal+.025); f:Adjust() end)
    Button("Camera up",275,-279,160,function() local s=Settings(); s.pitch=math.max(-40,s.pitch-1); f:Adjust() end)
    Button("Camera down",439,-279,160,function() local s=Settings(); s.pitch=math.min(40,s.pitch+1); f:Adjust() end)
    Button("Rotate left",275,-306,160,function() local s=Settings(); s.rotation=math.max(-90,s.rotation-2); f:Adjust() end)
    Button("Rotate right",439,-306,160,function() local s=Settings(); s.rotation=math.min(90,s.rotation+2); f:Adjust() end)
    Button("Reset",18,-319,64,function() local s=Settings(); s.vertical,s.horizontal,s.zoom,s.pitch,s.rotation=0,0,1,0,0; f:Adjust() end)
    Button("Retry",86,-319,64,function()
        P.ObserveUnit("player"); P.ObserveUnit("target")
        local generation=f.generation
        C_Timer.After(1.5,function() if f:IsShown() and generation==f.generation then f:Refresh() end end)
    end)
    Button("Save result",18,-498,110,function()
        if not f.result or not RivalsDB then f.status:SetText("No ready camera to save."); return end
        local _,key=Settings()
        RivalsDB.portraitTestResults=RivalsDB.portraitTestResults or {}
        local result={}
        for k,v in pairs(f.result) do result[k]=v end
        result.sample=f.sampleName; result.raceID=f.raceID; result.sex=f.sex
        RivalsDB.portraitTestResults[key]=result
        P._savedPortraitCalibrationsLoaded = nil
        EnsureSavedPortraitCalibrations()
        f.status:SetText("Result saved for "..races[f.raceID]..".\n/reload when finished to write results to disk.")
    end)
    f:SetScript("OnHide",function() f.generation=(f.generation or 0)+1; P.ResetCard(card); f.result=nil end)
    f:Refresh()
end

end
-- END PORTRAIT TEST PANEL
