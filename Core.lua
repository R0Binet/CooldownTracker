-- Core.lua
-- Logique principale : détection via filtres Blizzard natifs,
-- icônes persistantes avec cycle buff → CD → disponible

local addonName, CT = ...

-- ============================================================
-- DEFAULTS
-- ============================================================
local DEFAULTS = {
    cd_info_flags         = 7,
    glow_on_active_off    = true,
    glow_on_active_def    = true,
    show_chat_message     = false,
    filter_self           = false,
    persistent_icons_off  = true,
    persistent_icons_def  = true,
    num_rows              = 2,
    icons_per_row         = 4,
    icon_size             = 32,
    icon_spacing          = 2,
    show_offensive        = true,
    anchor_point_off      = "LEFT",
    anchor_offset_x_off   = -2,
    anchor_offset_y_off   = 0,
    show_defensive        = true,
    anchor_point_def      = "LEFT",
    anchor_offset_x_def   = 0,
    anchor_offset_y_def   = 0,
}

-- ============================================================
-- DEBUG LOGGING (chat + fichier SavedVariable)
-- ============================================================
local debugEnabled = false
local fileLogEnabled = false
local LOG_MAX_LINES = 2000  -- limite pour éviter un fichier énorme

local function DebugLog(category, msg, ...)
    if not debugEnabled and not fileLogEnabled then return end
    local ok, text = pcall(string.format, msg, ...)
    if not ok then text = msg end
    local timestamp = string.format("%.2f", GetTime() % 10000)

    -- Log dans le chat
    if debugEnabled then
        local color = "|cff888888"
        if category == "AURA"  then color = "|cff44ff44"
        elseif category == "CD"    then color = "|cffffff44"
        elseif category == "STYLE" then color = "|cff44aaff"
        elseif category == "SCAN"  then color = "|cffaa44ff"
        elseif category == "EVENT" then color = "|cffff8844"
        elseif category == "CLOG"  then color = "|cffff44ff"
        end
        print(string.format("|cff666666[CT-DBG]|r %s[%s]|r %s", color, category, text))
    end

    -- Log dans la SavedVariable (fichier)
    if fileLogEnabled then
        if not CooldownTrackerLog then CooldownTrackerLog = {} end
        local line = string.format("[%s] [%s] %s", timestamp, category, text)
        CooldownTrackerLog[#CooldownTrackerLog + 1] = line
        -- Purger si trop de lignes
        if #CooldownTrackerLog > LOG_MAX_LINES then
            local new = {}
            for i = #CooldownTrackerLog - LOG_MAX_LINES + 1, #CooldownTrackerLog do
                new[#new + 1] = CooldownTrackerLog[i]
            end
            CooldownTrackerLog = new
        end
    end
end

-- ============================================================
-- HELPERS
-- ============================================================
local function FormatTime(s)
    if s >= 60 then
        return string.format("%dm%ds", math.floor(s / 60), s % 60)
    end
    return string.format("%.0fs", math.floor(s))
end
CT.FormatTime = FormatTime

local function GetDB()
    return CooldownTrackerDB
end

-- ============================================================
-- IDENTIFICATION DES SORTS (contournement des secret values Midnight 12.0)
-- ============================================================
-- Problème : spellId, C_Spell.GetSpellName(), auraData.name, tostring(),
-- tooltip, texture probe → TOUT retourne des secret values.
--
-- SOLUTION : UNIT_SPELLCAST_SUCCEEDED. Quand un joueur lance un sort,
-- cet event fournit un spellId NORMAL. On l'utilise pour identifier
-- le buff qui apparaît ensuite via UNIT_AURA.

-- Cache des buffs connus actifs, alimenté par UNIT_SPELLCAST_SUCCEEDED
-- knownBuffs[unit][spellName] = { dbInfo, groupKey, spellId, spellIcon, appliedAt }
local knownBuffs = {}

-- Clés persistantes pour les icônes inconnues (les auraInstanceID changent entre casts)
-- unknownKeyCounter[unit] = int  — prochain numéro séquentiel
-- unknownAuraMap[unit][auraID] = persistentKey ("unk_off_1", "unk_def_2", …)
local unknownKeyCounter = {}
local unknownAuraMap = {}

-- ============================================================
-- DIAGNOSTIC : teste TOUTES les méthodes d'identification sur une aura
-- ============================================================
local scanTip = CreateFrame("GameTooltip", "CTScanTip", nil, "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")
local probeFrame = CreateFrame("Frame", nil, UIParent)
probeFrame:Hide()
local probeTex = probeFrame:CreateTexture(nil, "BACKGROUND")

local function DiagnoseAura(unit, auraInfo, groupKey)
    local auraID = auraInfo.auraInstanceID
    local spellId = auraInfo.spellId

    -- Test 1 : spellId est-il secret ?
    local idNil = (spellId == nil)
    local idSecret = (not idNil) and issecretvalue(spellId) or false
    DebugLog("DIAG", "  aura=%d spellId: nil=%s secret=%s", auraID, tostring(idNil), tostring(idSecret))

    -- Test 2 : C_Spell.GetSpellName(secret) → secret ?
    if not idNil then
        local ok, name = pcall(C_Spell.GetSpellName, spellId)
        local nameSecret = ok and name ~= nil and issecretvalue(name) or false
        DebugLog("DIAG", "  C_Spell.GetSpellName: ok=%s nil=%s secret=%s",
            tostring(ok), tostring(name == nil), tostring(nameSecret))
    end

    -- Test 3 : Tooltip scanning
    local tooltipResult = "FAIL"
    local ok3 = pcall(function()
        scanTip:SetOwner(UIParent, "ANCHOR_NONE")
        scanTip:ClearLines()
        scanTip:SetSpellByID(spellId)
    end)
    if ok3 then
        local line = CTScanTipTextLeft1
        if line then
            local text = line:GetText()
            if text == nil then
                tooltipResult = "text=nil"
            elseif issecretvalue(text) then
                tooltipResult = "SECRET"
            else
                tooltipResult = "NORMAL:" .. text
            end
        else
            tooltipResult = "no_line"
        end
    else
        tooltipResult = "SetSpellByID_failed"
    end
    DebugLog("DIAG", "  Tooltip: %s", tooltipResult)

    -- Test 4 : Texture probe
    local texResult = "FAIL"
    local ok4 = pcall(function()
        probeTex:SetTexture(C_Spell.GetSpellTexture(spellId))
    end)
    if ok4 then
        local texId = probeTex:GetTexture()
        if texId == nil then
            texResult = "texId=nil"
        elseif issecretvalue(texId) then
            texResult = "SECRET"
        else
            texResult = "NORMAL:" .. tostring(texId)
        end
    else
        texResult = "SetTexture_failed"
    end
    DebugLog("DIAG", "  TextureProbe: %s", texResult)

    -- Test 5 : AuraUtil.FindAuraByName (reverse lookup depuis notre DB)
    local auraUtilResult = "NO_DB"
    local unitClass = select(2, UnitClass(unit))
    if unitClass and CT.Spells and CT.Spells[unitClass] then
        auraUtilResult = "NOT_FOUND"
        local classData = CT.Spells[unitClass]
        local tested = 0
        for key, bucket in pairs(classData) do
            if type(bucket) == "table" then
                for sid, info in pairs(bucket) do
                    if type(sid) == "number" and type(info) == "table" and info.name then
                        tested = tested + 1
                        if AuraUtil and AuraUtil.FindAuraByName then
                            local aOk, aName = pcall(AuraUtil.FindAuraByName, info.name, unit, "HELPFUL")
                            if aOk and aName ~= nil then
                                local aNameSecret = issecretvalue(aName)
                                auraUtilResult = string.format("FOUND:%s(secret=%s)", info.name, tostring(aNameSecret))
                                -- on continue pour tester tous, mais on log le premier trouvé
                            end
                        else
                            auraUtilResult = "API_MISSING"
                            break
                        end
                    end
                end
            end
        end
        DebugLog("DIAG", "  AuraUtil: %s (tested %d spells for %s)", auraUtilResult, tested, unitClass)
    else
        DebugLog("DIAG", "  AuraUtil: %s (class=%s)", auraUtilResult, tostring(unitClass))
    end

    -- Test 6 : auraData.name secret ?
    local nameField = auraInfo.spellName
    local nameNil = (nameField == nil)
    local nameSecret = (not nameNil) and issecretvalue(nameField) or false
    DebugLog("DIAG", "  auraData.name: nil=%s secret=%s", tostring(nameNil), tostring(nameSecret))
end

-- Flag pour limiter le diagnostic (une seule fois par session de log)
local diagDone = {}

local function GetUnitByGUID(guid)
    if not guid then return nil end
    for _, u in ipairs({"player", "party1", "party2", "party3", "party4"}) do
        if UnitExists(u) and UnitGUID(u) == guid then return u end
    end
    return nil
end

-- === Index inversé par nom : { ["Combustion"] = spellInfo, ... } ===
local spellNameIndex = {}  -- [className] = { [spellName] = spellInfo }

local function BuildNameIndex(className)
    if spellNameIndex[className] then return spellNameIndex[className] end
    local classData = CT.Spells and CT.Spells[className]
    if not classData then return nil end

    local index = {}
    for key, bucket in pairs(classData) do
        if type(bucket) == "table" then
            for spellId, info in pairs(bucket) do
                if type(info) == "table" and info.name then
                    index[info.name] = info
                end
            end
        end
    end
    spellNameIndex[className] = index
    return index
end

-- Cherche un sort dans notre DB Spells.lua par NOM (string normale)
-- Retourne spellInfo { name, type, cooldown, ... } ou nil
local function LookupSpellDB(spellName, unit)
    if not spellName or not CT.Spells then return nil end
    local unitClass = select(2, UnitClass(unit))
    if not unitClass then return nil end
    local index = BuildNameIndex(unitClass)
    if not index then return nil end
    return index[spellName]
end

-- ============================================================
-- STATE
-- ============================================================
-- unitAuraStates[unit] = {
--   defensive = { [auraInstanceID] = AuraInfo },
--   offensive = { [auraInstanceID] = AuraInfo },
-- }
local unitAuraStates = {}

-- memberAnchors[unit] = {
--   offensive = { container, icons = {[spellName] = frame} },
--   defensive = { container, icons = {[spellName] = frame} },
-- }
local memberAnchors = {}
local unitWatchers  = {}

-- ============================================================
-- FILTRES BLIZZARD NATIFS
-- ============================================================
local ALL_FILTERS = {
    "HELPFUL|BIG_DEFENSIVE",
    "HELPFUL|EXTERNAL_DEFENSIVE",
    "HELPFUL|IMPORTANT",
}

-- ============================================================
-- UNIT FRAME LOOKUP
-- ============================================================
local function GetUnitFrame(unit)
    for i = 1, 5 do
        local f = _G["CompactPartyFrameMember" .. i]
        if f and f:IsShown() then
            local u = f.unit
            if f.GetAttribute then u = f:GetAttribute("unit") or u end
            if u and UnitIsUnit(u, unit) then return f end
        end
    end
    for i = 1, 40 do
        local f = _G["CompactRaidFrame" .. i]
        if f and f:IsShown() then
            local u = f.unit
            if f.GetAttribute then u = f:GetAttribute("unit") or u end
            if u and UnitIsUnit(u, unit) then return f end
        end
    end
    for g = 1, 8 do
        for m = 1, 5 do
            local f = _G["CompactRaidGroup" .. g .. "Member" .. m]
            if f and f:IsShown() then
                local u = f.unit
                if f.GetAttribute then u = f:GetAttribute("unit") or u end
                if u and UnitIsUnit(u, unit) then return f end
            end
        end
    end
    return nil
end

-- ============================================================
-- ITERATE AURAS
-- ============================================================
local function IterateAuras(unit, filter, callback)
    local auras = C_UnitAuras.GetUnitAuras(unit, filter)
    if not auras then return end
    for _, auraData in ipairs(auras) do
        local durationInfo = C_UnitAuras.GetAuraDuration(unit, auraData.auraInstanceID)
        local start = durationInfo and durationInfo:GetStartTime()
        local duration = durationInfo and durationInfo:GetTotalDuration()
        -- start/duration peuvent être des secret values — ne jamais comparer
        if start ~= nil and duration ~= nil then
            callback(auraData, start, duration)
        end
    end
end

-- ============================================================
-- INTERESTED IN (filtre les UNIT_AURA non pertinents)
-- ============================================================
local function InterestedIn(unit, updateInfo)
    if not updateInfo or updateInfo.isFullUpdate then
        return true
    end

    if updateInfo.addedAuras then
        for _, aura in ipairs(updateInfo.addedAuras) do
            local id = aura.auraInstanceID
            if id then
                for _, filter in ipairs(ALL_FILTERS) do
                    if not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, id, filter) then
                        return true
                    end
                end
            end
        end
    end

    if updateInfo.updatedAuras then
        for _, aura in ipairs(updateInfo.updatedAuras) do
            local id = aura.auraInstanceID
            if id then
                for _, filter in ipairs(ALL_FILTERS) do
                    if not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, id, filter) then
                        return true
                    end
                end
            end
        end
    end

    if updateInfo.removedAuraInstanceIDs and #updateInfo.removedAuraInstanceIDs > 0 then
        -- Vérifier dans unitAuraStates (sorts détectés par filtres)
        local state = unitAuraStates[unit]
        if state then
            for _, id in ipairs(updateInfo.removedAuraInstanceIDs) do
                if (state.defensive and state.defensive[id])
                or (state.offensive and state.offensive[id]) then
                    return true
                end
            end
        end
        -- AUSSI vérifier si on a des icônes affichées pour cette unité
        -- (sorts connus via AuraUtil qui ne sont pas dans unitAuraStates)
        local anchor = memberAnchors[unit]
        if anchor then
            for _, groupKey in ipairs({"offensive", "defensive"}) do
                local group = anchor[groupKey]
                if group and group.icons then
                    for _ in pairs(group.icons) do
                        return true  -- on a des icônes → il faut mettre à jour
                    end
                end
            end
        end
    end

    return false
end

-- ============================================================
-- REBUILD UNIT STATE (détection via filtres Blizzard)
-- ============================================================
local function RebuildUnitState(unit)
    local db = GetDB()
    if not db then return end
    if db.filter_self and unit == "player" then return end

    if not UnitExists(unit) or not UnitIsConnected(unit) or not UnitIsVisible(unit) then
        unitAuraStates[unit] = { defensive = {}, offensive = {} }
        return
    end

    local defensive = {}
    local offensive = {}
    local seen = {}

    -- Helper : construire les données d'une aura avec détection normal/secret
    local function BuildAuraEntry(auraData, start, duration, isExternal)
        local id = auraData.auraInstanceID
        -- Midnight 12.0 : les sorts de ta propre classe sont NORMAUX,
        -- les sorts d'autres classes sont SECRETS.
        local nameIsNormal = auraData.name ~= nil and not issecretvalue(auraData.name)
        local normalName = nameIsNormal and auraData.name or nil
        local normalIcon = nil
        if auraData.spellId ~= nil and not issecretvalue(auraData.spellId) then
            normalIcon = C_Spell.GetSpellTexture(auraData.spellId)
        end
        -- Source du buff (important pour les CDs externes)
        local sourceUnit = nil
        if auraData.sourceUnit ~= nil then
            if not issecretvalue(auraData.sourceUnit) then
                sourceUnit = auraData.sourceUnit
            end
        end
        return {
            spellId = auraData.spellId, spellName = auraData.name,
            spellIcon = auraData.icon, startTime = start,
            duration = duration, auraInstanceID = id,
            normalName = normalName,  -- string normale ou nil (secret)
            normalIcon = normalIcon,  -- texture normale ou nil
            sourceUnit = sourceUnit,  -- unitId du lanceur (nil si secret)
            isExternal = isExternal or false,  -- true si EXTERNAL_DEFENSIVE
        }
    end

    if db.show_defensive then
        IterateAuras(unit, "HELPFUL|BIG_DEFENSIVE", function(auraData, start, duration)
            local isDefensive = C_UnitAuras.AuraIsBigDefensive(auraData.spellId)
            if issecretvalue(isDefensive) or isDefensive then
                local id = auraData.auraInstanceID
                defensive[id] = BuildAuraEntry(auraData, start, duration, false)
                seen[id] = true
            end
        end)

        IterateAuras(unit, "HELPFUL|EXTERNAL_DEFENSIVE", function(auraData, start, duration)
            local id = auraData.auraInstanceID
            if not seen[id] then
                defensive[id] = BuildAuraEntry(auraData, start, duration, true)
                seen[id] = true
            end
        end)
    end

    if db.show_offensive then
        IterateAuras(unit, "HELPFUL|IMPORTANT", function(auraData, start, duration)
            local id = auraData.auraInstanceID
            if not seen[id] then
                local isImportant = C_Spell.IsSpellImportant(auraData.spellId)
                if issecretvalue(isImportant) or isImportant then
                    offensive[id] = BuildAuraEntry(auraData, start, duration, false)
                    seen[id] = true
                end
            end
        end)
    end

    unitAuraStates[unit] = { defensive = defensive, offensive = offensive }
end

-- ============================================================
-- GLOW
-- ============================================================
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

local function ApplyGlow(iconFrame, active, auraType)
    local db = GetDB()
    if not LCG then return end
    local glowKey = auraType == "offensive" and "glow_on_active_off" or "glow_on_active_def"
    if active and db and db[glowKey] then
        local color = auraType == "offensive"
            and {1, 0.6, 0, 1}
            or  {1, 0.85, 0, 1}
        pcall(LCG.ProcGlow_Start, iconFrame, { color = color, duration = 1, startAnim = true })
        iconFrame._ctGlowActive = true
    elseif iconFrame._ctGlowActive then
        pcall(LCG.ProcGlow_Stop, iconFrame)
        iconFrame._ctGlowActive = nil
    end
end

-- ============================================================
-- STYLES VISUELS
-- ============================================================

-- Buff actif : bordure vive, glow, roue = durée du buff
local function ApplyStyleActive(iconFrame, tracked)
    iconFrame:SetAlpha(1.0)
    if tracked.groupKey == "offensive" then
        iconFrame:SetBackdropBorderColor(1.0, 0.5, 0.1, 1)   -- orange
    else
        iconFrame:SetBackdropBorderColor(0.2, 1.0, 0.4, 1)    -- vert
    end
    -- Roue = durée du buff (secret values acceptées par SetCooldown)
    if iconFrame.cdOverlay and tracked.auraInfo.startTime ~= nil and tracked.auraInfo.duration ~= nil then
        iconFrame.cdOverlay:SetCooldown(tracked.auraInfo.startTime, tracked.auraInfo.duration)
    end
    iconFrame:SetScript("OnUpdate", nil)
end

-- En cooldown : icône assombrie, bordure grisée, roue = durée du CD
local function ApplyStyleCooldown(iconFrame, tracked)
    iconFrame:SetAlpha(0.55)
    iconFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    ApplyGlow(iconFrame, false, tracked.groupKey)

    -- Roue CD : début = maintenant, durée = cooldown de notre DB
    if iconFrame.cdOverlay and tracked.dbInfo and tracked.dbInfo.cooldown then
        iconFrame.cdOverlay:SetCooldown(GetTime(), tracked.dbInfo.cooldown)
    elseif iconFrame.cdOverlay then
        iconFrame.cdOverlay:SetCooldown(0, 0)
    end

    -- OnUpdate pour détecter la fin du CD
    if tracked.cdExpires then
        iconFrame:SetScript("OnUpdate", function(self)
            local now = GetTime()
            if now >= tracked.cdExpires then
                self._ctState = "available"
                self:SetScript("OnUpdate", nil)
                -- Appliquer le style disponible
                self:SetAlpha(1.0)
                if tracked.groupKey == "offensive" then
                    self:SetBackdropBorderColor(0.9, 0.15, 0.15, 1)
                else
                    self:SetBackdropBorderColor(0.15, 0.45, 0.9, 1)
                end
                if self.cdOverlay then self.cdOverlay:SetCooldown(0, 0) end
                DebugLog("CD", "%s [%s] CD expiré → DISPONIBLE", self.playerName or "?", tracked.spellName or "?")
            end
        end)
    end

    DebugLog("STYLE", "%s [%s] → EN CD (expire dans %.0fs)", iconFrame.playerName or "?", tracked.spellName or "?", (tracked.cdExpires or 0) - GetTime())
end

-- Disponible : icône pleine, bordure colorée, pas de roue
local function ApplyStyleAvailable(iconFrame, tracked)
    iconFrame:SetAlpha(1.0)
    if tracked.groupKey == "offensive" then
        iconFrame:SetBackdropBorderColor(0.9, 0.15, 0.15, 1)
    else
        iconFrame:SetBackdropBorderColor(0.15, 0.45, 0.9, 1)
    end
    if iconFrame.cdOverlay then iconFrame.cdOverlay:SetCooldown(0, 0) end
    iconFrame:SetScript("OnUpdate", nil)
    ApplyGlow(iconFrame, false, tracked.groupKey)
end

-- ============================================================
-- CRÉATION D'UNE ICÔNE PERSISTANTE
-- ============================================================
local function CreatePersistentIcon(tracked, unit, playerName)
    local db   = GetDB()
    local size = db and db.icon_size or 32
    local auraInfo = tracked.auraInfo

    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(size, size)
    f:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 6,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0, 0, 0, 0.85)

    f.auraType   = tracked.groupKey
    f.unit       = unit
    f.playerName = playerName

    -- Texture du sort
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT",     f, "TOPLEFT",     1, -1)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- spellIcon peut être secret — SetTexture l'accepte
    if auraInfo.spellIcon ~= nil then
        tex:SetTexture(auraInfo.spellIcon)
    end
    f.iconTex = tex

    -- Roue de cooldown
    local flags = db and db.cd_info_flags or 7
    local showTimer   = bit.band(flags, 1) ~= 0
    local showOverlay = bit.band(flags, 2) ~= 0

    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints(f)
    cd:SetDrawEdge(showOverlay)
    cd:SetDrawSwipe(showOverlay)
    cd:SetHideCountdownNumbers(not showTimer)
    cd:SetCooldown(0, 0)
    f.cdOverlay = cd

    -- Tooltip
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        local db2 = GetDB()
        local flags2 = db2 and db2.cd_info_flags or 7
        if bit.band(flags2, 4) == 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local sid = tracked.spellId
        if sid then
            GameTooltip:SetSpellByID(sid)
        elseif auraInfo.spellName ~= nil then
            GameTooltip:SetText(tostring(auraInfo.spellName))
        else
            GameTooltip:SetText("?")
        end
        GameTooltip:AddLine(" ")
        -- Pour les CDs externes, afficher source et cible
        if self._ctIsExternal then
            local sourceName = self._ctSourceUnit and UnitName(self._ctSourceUnit) or nil
            if sourceName then
                GameTooltip:AddLine("|cff00ccffLancé par :|r " .. sourceName)
            else
                GameTooltip:AddLine("|cff00ccffLancé par :|r |cff888888source inconnue|r")
            end
            GameTooltip:AddLine("|cff00ccffSur :|r " .. (playerName or "?"))
        else
            GameTooltip:AddLine("|cff00ccffJoueur :|r " .. (playerName or "?"))
        end
        local typeColor = tracked.groupKey == "offensive" and "|cffff5555" or "|cff5599ff"
        local typeLabel = tracked.groupKey == "offensive" and "Offensif" or "Défensif"
        GameTooltip:AddLine("|cff00ccffType :|r " .. typeColor .. typeLabel .. "|r")
        local currentState = self._ctState or "active"
        if currentState == "active" then
            GameTooltip:AddLine("|cff00ff44Buff actif|r")
        elseif currentState == "cooldown" and self._ctCDExpires then
            local rem = self._ctCDExpires - GetTime()
            if rem > 0 then
                GameTooltip:AddLine("|cffffd700CD restant :|r " .. FormatTime(rem))
            else
                GameTooltip:AddLine("|cff00ff00Disponible|r")
            end
        else
            GameTooltip:AddLine("|cff00ff00Disponible|r")
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f:SetAlpha(1.0)
    return f
end

-- ============================================================
-- POSITIONNEMENT DES ICÔNES
-- ============================================================
local function LayoutAnchorGroup(group)
    local db      = GetDB()
    local size    = db and db.icon_size    or 32
    local spacing = db and db.icon_spacing or 2
    local perRow  = db and db.icons_per_row or 5
    local numRows = db and db.num_rows     or 1

    local list = {}
    for _, iconFrame in pairs(group.icons) do
        list[#list + 1] = iconFrame
    end

    local count    = #list
    local colCount = numRows > 1 and math.max(math.min(count, perRow), math.ceil(count / numRows)) or count
    local containerW = math.max(colCount * (size + spacing), 1)
    local containerH = math.max(numRows * size + (numRows - 1) * spacing, size)
    group.container:SetSize(containerW, containerH)

    for i, f in ipairs(list) do
        local row = math.ceil(i / perRow)
        if row > numRows then row = numRows end
        local col = i - (row - 1) * perRow
        f:ClearAllPoints()
        f:SetParent(group.container)
        f:SetSize(size, size)
        f:SetPoint("TOPRIGHT", group.container, "TOPRIGHT",
            -(col - 1) * (size + spacing),
            -(row - 1) * (size + spacing))
        f:Show()
    end
end

local function LayoutAnchorGroupsMerged(offGroup, defGroup)
    local db      = GetDB()
    local size    = db and db.icon_size    or 32
    local spacing = db and db.icon_spacing or 2
    local perRow  = db and db.icons_per_row or 5
    local numRows = db and db.num_rows     or 1

    local list = {}
    for _, f in pairs(offGroup.icons) do list[#list + 1] = f end
    for _, f in pairs(defGroup.icons) do list[#list + 1] = f end

    local count    = #list
    local colCount = numRows > 1 and math.max(math.min(count, perRow), math.ceil(count / numRows)) or count
    local containerW = math.max(colCount * (size + spacing), 1)
    local containerH = math.max(numRows * size + (numRows - 1) * spacing, size)

    offGroup.container:SetSize(containerW, containerH)
    defGroup.container:SetSize(1, 1)

    for i, f in ipairs(list) do
        local row = math.ceil(i / perRow)
        if row > numRows then row = numRows end
        local col = i - (row - 1) * perRow
        f:ClearAllPoints()
        f:SetParent(offGroup.container)
        f:SetSize(size, size)
        f:SetPoint("TOPRIGHT", offGroup.container, "TOPRIGHT",
            -(col - 1) * (size + spacing),
            -(row - 1) * (size + spacing))
        f:Show()
    end
end

local function RelayoutUnit(unit)
    local anchor = memberAnchors[unit]
    if not anchor then return end
    local db = GetDB()
    local apOff = db and db.anchor_point_off or "LEFT"
    local apDef = db and db.anchor_point_def or "LEFT"
    if apOff == apDef then
        LayoutAnchorGroupsMerged(anchor.offensive, anchor.defensive)
    else
        LayoutAnchorGroup(anchor.offensive)
        LayoutAnchorGroup(anchor.defensive)
    end
end

-- ============================================================
-- ANCHOR CONFIG
-- ============================================================
local ANCHOR_CONFIG = {
    LEFT   = { selfPoint = "RIGHT",  relPoint = "LEFT"   },
    RIGHT  = { selfPoint = "LEFT",   relPoint = "RIGHT"  },
    TOP    = { selfPoint = "BOTTOM", relPoint = "TOP"    },
    BOTTOM = { selfPoint = "TOP",    relPoint = "BOTTOM" },
}

local function MakeGroup(parentFrame, apKey, offXKey, offYKey)
    local db   = GetDB()
    local ap   = db and db[apKey]   or "LEFT"
    local offX = db and db[offXKey] or -4
    local offY = db and db[offYKey] or 0
    local cfg  = ANCHOR_CONFIG[ap] or ANCHOR_CONFIG["LEFT"]
    local size = db and db.icon_size or 32

    local container = CreateFrame("Frame", nil, UIParent)
    container:SetSize(1, size)
    container:SetPoint(cfg.selfPoint, parentFrame, cfg.relPoint, offX, offY)
    container:Show()
    return { container = container, icons = {} }
end

-- ============================================================
-- UPDATE UNIT DISPLAY
-- Clé d'icône = spellName (si identifié) ou clé persistante "unk_off/def_N" (inconnu).
-- Quand le buff expire : icône passe en CD (si DB connue) ou "available" (persistant).
-- ============================================================
local function UpdateUnitDisplay(unit)
    local anchor = memberAnchors[unit]
    if not anchor then return end

    local state = unitAuraStates[unit]
    if not state then return end

    -- Protection : unité invalide → nettoyer les icônes
    if not UnitExists(unit) or not UnitIsConnected(unit) or not UnitIsVisible(unit) then
        for _, groupKey in ipairs({"offensive", "defensive"}) do
            local group = anchor[groupKey]
            if group then
                for key, f in pairs(group.icons) do
                    f._ctGlowActive = nil
                    f:SetScript("OnUpdate", nil)
                    f:Hide()
                    f:SetParent(nil)
                end
                wipe(group.icons)
            end
        end
        return
    end

    local db = GetDB()
    local playerName = UnitName(unit) or unit
    local changed = false

    -- Nettoyer les mappings d'auras expirées dans unknownAuraMap
    if unknownAuraMap[unit] then
        for auraID, _ in pairs(unknownAuraMap[unit]) do
            local found = false
            if state then
                for _, gk in ipairs({"offensive", "defensive"}) do
                    if state[gk] and state[gk][auraID] then found = true end
                end
            end
            if not found then
                unknownAuraMap[unit][auraID] = nil
            end
        end
    end

    -- Nettoyer les flags de claim pour ce cycle
    for _, groupKey in ipairs({"offensive", "defensive"}) do
        local group = anchor[groupKey]
        if group then
            for _, iconFrame in pairs(group.icons) do
                iconFrame._ctClaimedThisPass = nil
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════
    -- 1. CONSTRUIRE activeSpells depuis les filtres Blizzard
    --    Midnight 12.0 : TOUS les aura values sont SECRETS.
    --    On utilise knownBuffs (UNIT_SPELLCAST_SUCCEEDED / CLEU)
    --    pour identifier les sorts par leur nom normal.
    --    Clé = spellName (si identifié) ou "unk_off/def_N" (persistant)
    -- ═══════════════════════════════════════════════════════════
    local activeSpells = {}
    local identifiedCount, secretCount = 0, 0

    -- Collecter les knownBuffs encore non-réclamés pour matching
    local availableBuffs = {}  -- [groupKey] = { [spellName] = data }
    if knownBuffs[unit] then
        for spellName, data in pairs(knownBuffs[unit]) do
            local gk = data.groupKey
            if not availableBuffs[gk] then availableBuffs[gk] = {} end
            availableBuffs[gk][spellName] = data
        end
    end

    for _, groupKey in ipairs({"offensive", "defensive"}) do
        local auraState = state[groupKey]
        if auraState then
            for auraID, auraInfo in pairs(auraState) do
                local normalName = auraInfo.normalName  -- set in BuildAuraEntry
                local matched = false

                -- 1) Nom normal depuis l'aura elle-même (rare dans Midnight 12.0)
                if normalName then
                    local dbInfo = LookupSpellDB(normalName, unit)
                    activeSpells[normalName] = {
                        groupKey   = groupKey,
                        dbInfo     = dbInfo,
                        spellIcon  = auraInfo.normalIcon or auraInfo.spellIcon,
                        duration   = auraInfo.duration,
                        startTime  = auraInfo.startTime,
                        spellName  = normalName,
                        auraInfo   = auraInfo,
                        isUnknown  = (dbInfo == nil),
                        sourceUnit = auraInfo.sourceUnit,
                        isExternal = auraInfo.isExternal,
                    }
                    -- Retirer du pool available
                    if availableBuffs[groupKey] then
                        availableBuffs[groupKey][normalName] = nil
                    end
                    identifiedCount = identifiedCount + 1
                    matched = true
                end

                -- 2) Matcher via knownBuffs (UNIT_SPELLCAST_SUCCEEDED)
                if not matched and availableBuffs[groupKey] then
                    -- Prendre le premier knownBuff disponible pour ce groupKey
                    -- appliqué récemment (< 30s pour couvrir les buffs longs)
                    local now = GetTime()
                    local bestName, bestData
                    for spellName, data in pairs(availableBuffs[groupKey]) do
                        if (now - data.appliedAt) < 30 then
                            bestName = spellName
                            bestData = data
                            break
                        end
                    end

                    if bestName then
                        activeSpells[bestName] = {
                            groupKey   = groupKey,
                            dbInfo     = bestData.dbInfo,
                            spellIcon  = bestData.spellIcon or auraInfo.spellIcon,
                            duration   = auraInfo.duration,
                            startTime  = auraInfo.startTime,
                            spellName  = bestName,
                            auraInfo   = auraInfo,
                            isUnknown  = false,
                            sourceUnit = auraInfo.sourceUnit,
                            isExternal = auraInfo.isExternal,
                        }
                        availableBuffs[groupKey][bestName] = nil
                        identifiedCount = identifiedCount + 1
                        matched = true
                    end
                end

                -- 3) Fallback : aura secrète non identifiée → clé persistante
                if not matched then
                    -- Chercher si cet auraID a déjà une clé persistante
                    if not unknownAuraMap[unit] then unknownAuraMap[unit] = {} end
                    local persistKey = unknownAuraMap[unit][auraID]

                    if not persistKey then
                        -- Chercher une icône "available" réutilisable dans le même groupe
                        local group = anchor[groupKey]
                        if group then
                            for ik, ifr in pairs(group.icons) do
                                if ifr._ctIsUnknown and ifr._ctState == "available" and not ifr._ctClaimedThisPass then
                                    persistKey = ik
                                    ifr._ctClaimedThisPass = true
                                    break
                                end
                            end
                        end

                        -- Sinon, créer une nouvelle clé séquentielle
                        if not persistKey then
                            if not unknownKeyCounter[unit] then unknownKeyCounter[unit] = 0 end
                            unknownKeyCounter[unit] = unknownKeyCounter[unit] + 1
                            local prefix = groupKey == "offensive" and "unk_off_" or "unk_def_"
                            persistKey = prefix .. unknownKeyCounter[unit]
                        end
                        unknownAuraMap[unit][auraID] = persistKey
                    end

                    activeSpells[persistKey] = {
                        groupKey   = groupKey,
                        dbInfo     = nil,
                        spellIcon  = auraInfo.spellIcon,
                        duration   = auraInfo.duration,
                        startTime  = auraInfo.startTime,
                        spellName  = nil,
                        auraInfo   = auraInfo,
                        isUnknown  = true,
                        sourceUnit = auraInfo.sourceUnit,
                        isExternal = auraInfo.isExternal,
                    }
                    secretCount = secretCount + 1
                end
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════
    -- 3. TRAITER LES ICÔNES EXISTANTES
    -- ═══════════════════════════════════════════════════════════
    for _, groupKey in ipairs({"offensive", "defensive"}) do
        local group = anchor[groupKey]
        if group then
            for iconKey, iconFrame in pairs(group.icons) do
                local activeData = activeSpells[iconKey]
                if activeData then
                    -- Le buff est actif → style actif
                    iconFrame._ctState = "active"
                    -- Construire un auraInfo compatible pour ApplyStyleActive
                    local auraInfoCompat = activeData.auraInfo or {
                        spellIcon = activeData.spellIcon,
                        startTime = activeData.startTime,
                        duration  = activeData.duration,
                    }
                    iconFrame._ctLastAuraInfo = auraInfoCompat
                    -- Mettre à jour la texture (peut changer si icône réutilisée)
                    if iconFrame.iconTex and auraInfoCompat.spellIcon ~= nil then
                        iconFrame.iconTex:SetTexture(auraInfoCompat.spellIcon)
                    end
                    iconFrame:Show()
                    local tracked = {
                        auraInfo  = auraInfoCompat,
                        groupKey  = groupKey,
                        state     = "active",
                        spellName = iconFrame._ctSpellName,
                    }
                    ApplyStyleActive(iconFrame, tracked)
                    ApplyGlow(iconFrame, true, groupKey)
                else
                    -- Le buff n'est plus actif
                    local curState = iconFrame._ctState or "?"

                    if curState == "cooldown" or curState == "available" then
                        -- OnUpdate gère la transition CD → available, ne rien toucher
                    else
                        -- active → CD ou suppression
                        local safeName = iconFrame._ctSpellName
                        local dbInfo = safeName and LookupSpellDB(safeName, unit)

                        if dbInfo and dbInfo.cooldown and iconFrame._ctLastAuraInfo then
                            -- Sort connu avec CD → transition CD avec timer
                            if knownBuffs[unit] and safeName then
                                knownBuffs[unit][safeName] = nil
                            end
                            iconFrame._ctState = "cooldown"
                            local cdExpires = GetTime() + dbInfo.cooldown
                            iconFrame._ctCDExpires = cdExpires
                            local tracked = {
                                auraInfo  = iconFrame._ctLastAuraInfo,
                                groupKey  = groupKey,
                                state     = "cooldown",
                                spellName = safeName,
                                dbInfo    = dbInfo,
                                cdExpires = cdExpires,
                            }
                            ApplyStyleCooldown(iconFrame, tracked)
                            DebugLog("CD", "%s [%s] → EN CD %.0fs", playerName, safeName or "?", dbInfo.cooldown)
                            changed = true
                        elseif db and ((groupKey == "offensive" and db.persistent_icons_off) or (groupKey == "defensive" and db.persistent_icons_def)) then
                            -- Mode persistant : garder en "available"
                            iconFrame._ctState = "available"
                            local tracked = {
                                auraInfo  = iconFrame._ctLastAuraInfo,
                                groupKey  = groupKey,
                                state     = "available",
                                spellName = safeName,
                            }
                            ApplyStyleAvailable(iconFrame, tracked)
                            changed = true
                            DebugLog("CD", "%s [%s] → DISPONIBLE (persistant)", playerName, safeName or tostring(iconKey))
                        else
                            -- Mode actif uniquement : supprimer l'icône
                            pcall(function()
                                if iconFrame._ctGlowActive and LCG then
                                    LCG.ProcGlow_Stop(iconFrame)
                                end
                            end)
                            iconFrame._ctGlowActive = nil
                            iconFrame:SetScript("OnUpdate", nil)
                            iconFrame:Hide()
                            iconFrame:SetParent(nil)
                            group.icons[iconKey] = nil
                            changed = true
                            DebugLog("CD", "%s [%s] → SUPPRIMÉ", playerName, safeName or tostring(iconKey))
                        end
                    end
                end
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════
    -- 4. CRÉER LES ICÔNES POUR LES NOUVEAUX SORTS ACTIFS
    -- ═══════════════════════════════════════════════════════════
    for iconKey, data in pairs(activeSpells) do
        local group = anchor[data.groupKey]
        if group and not group.icons[iconKey] then
            -- Construire l'auraInfo compatible
            local auraInfoCompat = data.auraInfo or {
                spellIcon = data.spellIcon,
                startTime = data.startTime,
                duration  = data.duration,
            }

            local tracked = {
                auraInfo   = auraInfoCompat,
                groupKey   = data.groupKey,
                state      = "active",
                spellName  = data.spellName,  -- nom normal ou nil
                sourceUnit = data.sourceUnit,
                isExternal = data.isExternal,
            }

            local iconFrame = CreatePersistentIcon(tracked, unit, playerName)
            iconFrame._ctSpellName = data.spellName  -- nom normal (nil pour inconnu)
            iconFrame._ctIsUnknown = data.isUnknown or false
            iconFrame._ctIsExternal = data.isExternal or false
            iconFrame._ctSourceUnit = data.sourceUnit
            iconFrame._ctState = "active"
            iconFrame._ctLastAuraInfo = auraInfoCompat
            group.icons[iconKey] = iconFrame
            changed = true

            ApplyStyleActive(iconFrame, tracked)
            ApplyGlow(iconFrame, true, data.groupKey)
            DebugLog("STYLE", "%s [%s] ICÔNE CRÉÉE", unit, data.spellName or iconKey)

            -- Message chat : CD utilisé
            if db and db.show_chat_message then
                local typeColor = data.groupKey == "offensive" and "|cffff4444" or "|cff44aaff"
                local typeLabel = data.groupKey == "offensive" and "OFFENSIF" or "DÉFENSIF"
                local spellLabel = data.spellName or "CD"
                -- Pour les CDs externes, indiquer la source
                if data.isExternal then
                    local sourceName = data.sourceUnit and UnitName(data.sourceUnit) or nil
                    if sourceName then
                        print(string.format("|cff00ccff[CT]|r %s[%s]|r %s lancé par |cff00ff00%s|r sur |cff00ff00%s|r",
                            typeColor, typeLabel, spellLabel, sourceName, playerName))
                    else
                        print(string.format("|cff00ccff[CT]|r %s[%s]|r %s sur |cff00ff00%s|r (source inconnue)",
                            typeColor, typeLabel, spellLabel, playerName))
                    end
                else
                    print(string.format("|cff00ccff[CT]|r %s[%s]|r %s utilisé par |cff00ff00%s|r",
                        typeColor, typeLabel, spellLabel, playerName))
                end
            end
        end
    end

    if changed then
        RelayoutUnit(unit)
    end

    -- ═══════════════════════════════════════════════════════════
    -- 5. GLOW (après le layout)
    -- ═══════════════════════════════════════════════════════════
    for _, groupKey in ipairs({"offensive", "defensive"}) do
        local group = anchor[groupKey]
        if group then
            for iconKey, iconFrame in pairs(group.icons) do
                local isActive = activeSpells[iconKey] ~= nil
                ApplyGlow(iconFrame, isActive, groupKey)
            end
        end
    end
end

-- ============================================================
-- CRÉATION DES CONTAINERS D'ANCRAGE
-- ============================================================
local function CreateAnchorForUnit(unit)
    local parentFrame = GetUnitFrame(unit)
    if not parentFrame then
        DebugLog("EVENT", "CreateAnchorForUnit(%s) — AUCUN frame trouvé !", unit)
        return
    end

    local db    = GetDB()
    local apOff = db and db.anchor_point_off or "LEFT"

    local offGroup = MakeGroup(parentFrame, "anchor_point_off", "anchor_offset_x_off", "anchor_offset_y_off")
    local defTarget = (apOff == (db and db.anchor_point_def or "LEFT")) and offGroup.container or parentFrame
    local defGroup  = MakeGroup(defTarget, "anchor_point_def", "anchor_offset_x_def", "anchor_offset_y_def")

    memberAnchors[unit] = { offensive = offGroup, defensive = defGroup }
end

-- ============================================================
-- REGISTER UNIT WATCHER
-- ============================================================
local function RegisterUnitWatcher(unit)
    if unitWatchers[unit] then
        unitWatchers[unit]:UnregisterAllEvents()
        unitWatchers[unit]:SetScript("OnEvent", nil)
    end

    if not UnitExists(unit) then
        unitWatchers[unit] = nil
        return
    end

    local f = CreateFrame("Frame")
    f:RegisterUnitEvent("UNIT_AURA", unit)
    f:SetScript("OnEvent", function(_, event, unitArg, updateInfo)
        if event ~= "UNIT_AURA" then return end
        local interested = InterestedIn(unit, updateInfo)
        if not interested then return end
        RebuildUnitState(unit)
        UpdateUnitDisplay(unit)
    end)
    unitWatchers[unit] = f

    -- Scan initial
    RebuildUnitState(unit)
    UpdateUnitDisplay(unit)
end

local function UnregisterAllUnitWatchers()
    for unit, f in pairs(unitWatchers) do
        f:UnregisterAllEvents()
        f:SetScript("OnEvent", nil)
    end
    unitWatchers = {}
end

-- ============================================================
-- REBUILD COMPLET
-- ============================================================
local function RebuildAllAnchors()
    for unit, anchor in pairs(memberAnchors) do
        for _, groupKey in ipairs({"offensive", "defensive"}) do
            local group = anchor[groupKey]
            if group then
                if group.container then group.container:Hide() end
                for _, f in pairs(group.icons or {}) do
                    -- NE PAS appeler ProcGlow_Stop ici :
                    -- Le pool interne de LibCustomGlow déclenche une erreur
                    -- que pcall ne peut pas attraper (gestionnaire Blizzard).
                    -- Hide + SetParent(nil) masque aussi les enfants glow.
                    f._ctGlowActive = nil
                    f:SetScript("OnUpdate", nil)
                    f:Hide()
                    f:SetParent(nil)
                end
            end
        end
    end
    memberAnchors = {}
    unitAuraStates = {}
    unknownKeyCounter = {}
    unknownAuraMap = {}

    UnregisterAllUnitWatchers()

    if not IsInGroup() then return end

    if IsInRaid() then
        for i = 1, 40 do
            local u = "raid" .. i
            if UnitExists(u) then
                CreateAnchorForUnit(u)
                RegisterUnitWatcher(u)
            end
        end
    else
        CreateAnchorForUnit("player")
        RegisterUnitWatcher("player")
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then
                CreateAnchorForUnit(u)
                RegisterUnitWatcher(u)
            end
        end
    end
end
CT.RebuildAllAnchors = RebuildAllAnchors

-- ============================================================
-- COMPTEURS DE DIAGNOSTIC
-- ============================================================
local castEventCount = 0
local castMatchCount = 0

-- ============================================================
-- UNIT_SPELLCAST_SUCCEEDED : identification des sorts par spellcast
-- Quand un membre du groupe lance un sort, on récupère le spellId
-- (possiblement normal) et on l'associe au buff qui va apparaître.
-- ============================================================
local spellcastFrame = CreateFrame("Frame")
spellcastFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
spellcastFrame:SetScript("OnEvent", function(_, event, unitTarget, castGUID, spellId)
    if not IsInGroup() and unitTarget ~= "player" then return end
    castEventCount = castEventCount + 1

    -- Vérifier que le spellId est normal
    if spellId == nil then return end
    if issecretvalue(spellId) then return end

    -- spellId est NORMAL ! Récupérer le nom
    local okName, spellName = pcall(C_Spell.GetSpellName, spellId)
    if not okName or spellName == nil then return end
    if issecretvalue(spellName) then return end

    -- spellName est NORMAL ! Chercher dans notre DB
    local dbInfo = LookupSpellDB(spellName, unitTarget)
    if not dbInfo then return end  -- pas un sort qu'on traque

    local db = GetDB()
    if not db then return end
    local groupKey = (dbInfo.type == "defensive") and "defensive" or "offensive"
    if (groupKey == "offensive" and not db.show_offensive)
    or (groupKey == "defensive" and not db.show_defensive) then
        return
    end

    castMatchCount = castMatchCount + 1
    local okTex, spellIcon = pcall(C_Spell.GetSpellTexture, spellId)
    if not okTex or (spellIcon and issecretvalue(spellIcon)) then spellIcon = nil end

    DebugLog("CAST", "%s MATCH: %s (id=%d) [%s] cd=%s icon=%s",
        unitTarget, spellName, spellId, groupKey,
        tostring(dbInfo.cooldown), tostring(spellIcon ~= nil))

    -- Stocker dans knownBuffs pour que UpdateUnitDisplay puisse s'en servir
    if not knownBuffs[unitTarget] then knownBuffs[unitTarget] = {} end
    knownBuffs[unitTarget][spellName] = {
        dbInfo    = dbInfo,
        groupKey  = groupKey,
        spellId   = spellId,
        spellIcon = spellIcon,
        spellName = spellName,
        appliedAt = GetTime(),
    }
end)

-- NOTE: COMBAT_LOG_EVENT_UNFILTERED est PROTÉGÉ dans Midnight 12.0.
-- Les addons ne peuvent pas s'y enregistrer (ADDON_ACTION_FORBIDDEN).
-- On utilise uniquement UNIT_SPELLCAST_SUCCEEDED pour identifier les sorts.

-- ============================================================
-- INIT
-- ============================================================
local function OnAddonLoaded()
    if not CooldownTrackerDB then CooldownTrackerDB = {} end
    for k, v in pairs(DEFAULTS) do
        if CooldownTrackerDB[k] == nil then
            CooldownTrackerDB[k] = v
        end
    end
    DebugLog("INIT", "AuraUtil=%s", tostring(AuraUtil ~= nil))
    RebuildAllAnchors()
    print("|cff00ff00[CooldownTracker]|r Chargé. Tapez |cffffcc00/cdt|r pour l'aide.")
end

-- ============================================================
-- EVENTS
-- ============================================================
local function OnBootEvent(self, event, name)
    if event ~= "ADDON_LOADED" or name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    local ok, err = pcall(OnAddonLoaded)
    if not ok then
        print("|cffff0000[CooldownTracker] ERREUR init:|r " .. tostring(err))
    end

    local eventsFrame = CreateFrame("Frame")
    local function OnGameEvent(_, ev)
        if ev == "GROUP_ROSTER_UPDATE" or ev == "RAID_ROSTER_UPDATE" then
            RebuildAllAnchors()
        elseif ev == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1, RebuildAllAnchors)
        end
    end
    eventsFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventsFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventsFrame:SetScript("OnEvent", OnGameEvent)
end

local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:SetScript("OnEvent", OnBootEvent)

-- ============================================================
-- HOOKS ROSTER
-- ============================================================
if CompactRaidFrameManager_UpdateShown then
    hooksecurefunc("CompactRaidFrameManager_UpdateShown", function()
        if CooldownTrackerDB then RebuildAllAnchors() end
    end)
end
if PartyMemberFrame_UpdateMember then
    hooksecurefunc("PartyMemberFrame_UpdateMember", function()
        if CooldownTrackerDB then C_Timer.After(0.2, RebuildAllAnchors) end
    end)
end

-- ============================================================
-- SLASH COMMANDS
-- ============================================================
SLASH_COOLDOWNTRACKER1 = "/cdt"
SLASH_COOLDOWNTRACKER2 = "/cooldowntracker"
SlashCmdList["COOLDOWNTRACKER"] = function(msg)
    local cmd = (msg or ""):lower():trim()
    local db  = GetDB()

    if cmd == "" or cmd == "help" then
        print("|cff00ccff[CooldownTracker] Commandes :|r")
        print("  |cffffcc00/cdt|r            — Ouvrir les options")
        print("  |cffffcc00/cdt off|r        — Toggle CDs offensifs")
        print("  |cffffcc00/cdt def|r        — Toggle CDs défensifs")
        print("  |cffffcc00/cdt chat|r       — Toggle messages chat")
        print("  |cffffcc00/cdt debug|r      — Toggle logs de debug (chat)")
        print("  |cffffcc00/cdt log|r        — Toggle logs fichier (SavedVariable)")
        print("  |cffffcc00/cdt clear|r      — Effacer les CDs affichés")
        print("  |cffffcc00/cdt status|r     — Config actuelle")
        print("  |cffffcc00/cdt identify|r   — Afficher le cache spellcast")
    elseif cmd == "off" then
        if db then db.show_offensive = not db.show_offensive end
        print("|cff00ccff[CT]|r Offensifs : " .. (db and db.show_offensive and "|cff00ff00On|r" or "|cffff4444Off|r"))
        RebuildAllAnchors()
    elseif cmd == "def" then
        if db then db.show_defensive = not db.show_defensive end
        print("|cff00ccff[CT]|r Défensifs : " .. (db and db.show_defensive and "|cff00ff00On|r" or "|cffff4444Off|r"))
        RebuildAllAnchors()
    elseif cmd == "chat" then
        if db then db.show_chat_message = not db.show_chat_message end
        print("|cff00ccff[CT]|r Chat : " .. (db and db.show_chat_message and "|cff00ff00On|r" or "|cffff4444Off|r"))
    elseif cmd == "debug" then
        debugEnabled = not debugEnabled
        print("|cff00ccff[CT]|r Debug : " .. (debugEnabled and "|cff00ff00On|r — logs dans le chat" or "|cffff4444Off|r"))
    elseif cmd == "log" then
        fileLogEnabled = not fileLogEnabled
        if fileLogEnabled then
            CooldownTrackerLog = {}  -- reset
            debugEnabled = true  -- activer aussi le debug pour que DebugLog fonctionne
            print("|cff00ccff[CT]|r Log fichier : |cff00ff00ACTIVÉ|r (debug aussi activé)")
            print("|cff00ccff[CT]|r Joue normalement, puis |cffffcc00/cdt log|r pour arrêter, puis |cffffcc00/reload|r")
        else
            print("|cff00ccff[CT]|r Log fichier : |cffff4444ARRÊTÉ|r — " .. (#(CooldownTrackerLog or {}) ) .. " lignes enregistrées")
            print("|cff00ccff[CT]|r Fais |cffffcc00/reload|r puis envoie le fichier :")
            print("|cffffffaaWTF/Account/<COMPTE>/SavedVariables/CooldownTracker.lua|r")
        end
    elseif cmd == "clear" then
        unitAuraStates = {}
        knownBuffs = {}
        RebuildAllAnchors()
        print("|cff00ccff[CT]|r CDs effacés.")
    elseif cmd == "frames" then
        print("|cff00ccff[CT]|r Recherche des frames...")
        print("|cff00ccff[CT]|r InGroup=" .. tostring(IsInGroup()) .. "  InRaid=" .. tostring(IsInRaid()))
        local found = 0
        for i = 1, 5 do
            local f = _G["CompactPartyFrameMember" .. i]
            local shown = f and f:IsShown()
            local u = f and (f.GetAttribute and f:GetAttribute("unit") or f.unit)
            if f then
                print(string.format("  CompactPartyFrameMember%d: shown=%s unit=%s", i, tostring(shown), tostring(u)))
                if shown then found = found + 1 end
            end
        end
        for i = 1, 10 do
            local f = _G["CompactRaidFrame" .. i]
            local shown = f and f:IsShown()
            local u = f and (f.GetAttribute and f:GetAttribute("unit") or f.unit)
            if f then
                print(string.format("  CompactRaidFrame%d: shown=%s unit=%s", i, tostring(shown), tostring(u)))
                if shown then found = found + 1 end
            end
        end
        for g = 1, 3 do
            for m = 1, 5 do
                local f = _G["CompactRaidGroup" .. g .. "Member" .. m]
                local shown = f and f:IsShown()
                local u = f and (f.GetAttribute and f:GetAttribute("unit") or f.unit)
                if f then
                    print(string.format("  CompactRaidGroup%dMember%d: shown=%s unit=%s", g, m, tostring(shown), tostring(u)))
                    if shown then found = found + 1 end
                end
            end
        end
        print("|cff00ccff[CT]|r Anchors créés: " .. (memberAnchors and #memberAnchors or 0))
        for u, a in pairs(memberAnchors or {}) do
            local offIcons, defIcons = 0, 0
            if a.offensive then for _ in pairs(a.offensive.icons) do offIcons = offIcons + 1 end end
            if a.defensive then for _ in pairs(a.defensive.icons) do defIcons = defIcons + 1 end end
            print(string.format("  anchor[%s] off=%d def=%d", u, offIcons, defIcons))
        end
        if found == 0 then print("|cffff4444[CT]|r Aucun frame trouvé !") end
    elseif cmd == "status" then
        if not db then print("|cffff4444[CT]|r Non initialisé.") return end
        print("|cff00ccff[CT]|r Offensifs:" .. (db.show_offensive and "On" or "Off")
            .. "  Défensifs:" .. (db.show_defensive and "On" or "Off")
            .. "  Chat:" .. (db.show_chat_message and "On" or "Off")
            .. "  Taille:" .. db.icon_size .. "px"
            .. "  Debug:" .. (debugEnabled and "On" or "Off"))
        print("|cff00ccff[CT]|r CAST events:" .. castEventCount
            .. "  CAST matches:" .. castMatchCount)
        local buffCount = 0
        for u, spells in pairs(knownBuffs) do
            for _ in pairs(spells) do buffCount = buffCount + 1 end
        end
        print("|cff00ccff[CT]|r knownBuffs:" .. buffCount)
    elseif cmd == "identify" then
        -- Afficher le cache du combat log
        print("|cff00ccff[CT]|r Cache spellcast (knownBuffs) :")
        local total = 0
        for u, spells in pairs(knownBuffs) do
            for spellName, data in pairs(spells) do
                total = total + 1
                print(string.format("  |cff00ff00%s|r %s: |cffffffff%s|r (id=%d, cd=%s)",
                    u, data.groupKey, spellName, data.spellId,
                    tostring(data.dbInfo and data.dbInfo.cooldown or "?")))
            end
        end
        if total == 0 then
            print("  (vide — aucun buff connu détecté via combat log)")
        end
    else
        print("|cffff4444[CT]|r Commande inconnue. |cffffcc00/cdt help|r pour l'aide.")
    end
end
