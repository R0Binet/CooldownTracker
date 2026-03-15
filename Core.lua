-- Core.lua
-- Logique principale : tracking des CDs, ancrage aux frames de groupe
-- Loader local créé au niveau fichier

local addonName, CT = ...

-- ============================================================
-- DEFAULTS
-- ============================================================
local DEFAULTS = {
    -- Options
    -- cd_info_flags : Blizzard encode id=1→bit1, id=2→bit2, id=3→bit4
    -- timer=1, roue=2, tooltip=4 → tout activé = 7
    cd_info_flags         = 7,
    glow_on_active_off    = true,
    glow_on_active_def    = true,
    show_chat_message     = false,
    filter_self           = false,
    -- Mode d'affichage
    always_show_icons     = true,
    -- Disposition
    num_rows              = 2,
    icons_per_row         = 4,
    -- Icônes
    icon_size             = 32,
    icon_spacing          = 2,
    -- CDs Offensifs
    show_offensive        = true,
    anchor_point_off      = "LEFT",
    anchor_offset_x_off   = -2,
    anchor_offset_y_off   = 0,
    -- CDs Défensifs
    show_defensive        = true,
    anchor_point_def      = "LEFT",
    anchor_offset_x_def   = 0,
    anchor_offset_y_def   = 0,
    tracked_spells        = {},
}

-- ============================================================
-- STATE
-- ============================================================
-- activeCDs[playerName][spellId] = { expires, cdExpires, buffDuration, spellInfo, spellId, playerName, unit }
local activeCDs     = {}
-- memberAnchors[unit] = {
--   offensive = { container, staticIcons = {[spellId]=frame} },
--   defensive = { container, staticIcons = {[spellId]=frame} },
-- }
local memberAnchors = {}
local unitEventFrames = {}

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

local function IsTracked(spellId)
    local db = GetDB()
    if not db then return true end
    local key = tostring(spellId)
    if db.tracked_spells == nil then return true end
    if db.tracked_spells[key] == nil then return true end
    return db.tracked_spells[key]
end

-- ============================================================
-- DÉTECTION DE SPÉCIALISATION
-- Cache : unitSpecs[unit] = specId
-- Règle permissive : si la spé est inconnue on affiche le sort
-- ============================================================
local unitSpecs = {}

local function GetUnitSpec(unit)
    if unitSpecs[unit] then return unitSpecs[unit] end
    local specId
    if unit == "player" then
        local idx = GetSpecialization and GetSpecialization()
        if idx and idx > 0 then
            specId = select(1, GetSpecializationInfo(idx))
        end
    else
        specId = GetInspectSpecialization and GetInspectSpecialization(unit)
        if specId == 0 then specId = nil end
    end
    if specId and specId > 0 then
        unitSpecs[unit] = specId
    end
    return unitSpecs[unit]
end

-- Retourne true si le sort correspond à la spé de l'unité
-- Permissif : affiche si spé inconnue
local function IsSpellForSpec(spellInfo, unit)
    if not spellInfo.spec then return true end
    local unitSpec = GetUnitSpec(unit)
    if not unitSpec then return true end
    local s = spellInfo.spec
    if type(s) == "number" then
        return s == unitSpec
    end
    for _, v in ipairs(s) do
        if v == unitSpec then return true end
    end
    return false
end

local function RequestUnitSpec(unit)
    if unit == "player" then return end
    if unitSpecs[unit] then return end
    if UnitExists(unit) and CanInspect(unit) then
        NotifyInspect(unit)
    end
end

-- ============================================================
-- UNIT FRAME LOOKUP
-- ============================================================
local function GetUnitFrame(unit)
    for i = 1, 5 do
        local f = _G["CompactPartyFrameMember" .. i]
        if f and f:IsShown() then
            local u = f.unit
            if f.GetAttribute then u = f:GetAttribute("unit") or u end
            if u == unit then return f end
        end
    end
    for i = 1, 40 do
        local f = _G["CompactRaidFrame" .. i]
        if f and f:IsShown() then
            local u = f.unit
            if f.GetAttribute then u = f:GetAttribute("unit") or u end
            if u == unit then return f end
        end
    end
    for g = 1, 8 do
        for m = 1, 5 do
            local f = _G["CompactRaidGroup" .. g .. "Member" .. m]
            if f and f:IsShown() then
                local u = f.unit
                if f.GetAttribute then u = f:GetAttribute("unit") or u end
                if u == unit then return f end
            end
        end
    end
    return nil
end

local function GUIDToUnit(guid)
    if UnitGUID("player") == guid then return "player" end
    local groupType  = IsInRaid() and "raid" or "party"
    local maxMembers = IsInRaid() and 40 or 4
    for i = 1, maxMembers do
        local u = groupType .. i
        if UnitExists(u) and UnitGUID(u) == guid then return u end
    end
    return nil
end

-- ============================================================
-- STYLE HELPERS — appliqués sur une icône statique
-- ============================================================

-- Référence à LibCustomGlow (chargé avant Core.lua)
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

local UpdateChargeBadge  -- forward declaration (définie plus bas)

local function ApplyGlow(iconFrame, active)
    local db = GetDB()
    if not LCG then return end
    local si = iconFrame.spellInfo
    local glowKey = si and si.type == "offensive" and "glow_on_active_off" or "glow_on_active_def"
    if active and db and db[glowKey] then
        local color = si and si.type == "offensive"
            and {1, 0.6, 0, 1}
            or  {1, 0.85, 0, 1}
        LCG.ProcGlow_Start(iconFrame, { color = color, duration = 1, startAnim = true })
    else
        LCG.ProcGlow_Stop(iconFrame)
    end
end

-- État "disponible" : icône pleine, bordure colorée normale, pas de roue
local function ApplyStyleAvailable(iconFrame)
    iconFrame:SetAlpha(1.0)
    local si = iconFrame.spellInfo
    if si.type == "offensive" then
        iconFrame:SetBackdropBorderColor(0.9, 0.15, 0.15, 1)
    else
        iconFrame:SetBackdropBorderColor(0.15, 0.45, 0.9, 1)
    end
    if iconFrame.cdOverlay then iconFrame.cdOverlay:SetCooldown(0, 0) end
    if iconFrame.timerText  then iconFrame.timerText:SetText("") end
    iconFrame:SetScript("OnUpdate", nil)
    ApplyGlow(iconFrame, false)
    -- Rafraîchir le badge de charges si sort multi-charges (joueur local uniquement)
    if iconFrame.chargeBadge and si.charges and iconFrame.unit == "player" then
        local chargeInfo = C_Spell.GetSpellCharges(iconFrame.spellId)
        if chargeInfo then
            UpdateChargeBadge(iconFrame, chargeInfo.currentCharges, chargeInfo.maxCharges)
        end
    end
end

-- État "en CD" : icône assombrie, bordure grisée, roue + timer actifs
local function ApplyStyleOnCooldown(iconFrame, cdData)
    iconFrame:SetAlpha(0.55)
    iconFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    ApplyGlow(iconFrame, false)

    if iconFrame.cdOverlay then
        local dur = cdData.spellInfo.cooldown
        iconFrame.cdOverlay:SetCooldown(cdData.cdExpires - dur, dur)
    end

    iconFrame:SetScript("OnUpdate", function(self)
        local rem = cdData.cdExpires - GetTime()
        if rem <= 0 then
            ApplyStyleAvailable(self)
            if self.chargeBadge and self.spellInfo.charges and self.unit == "player" then
                C_Timer.After(0.1, function()
                    local ci = C_Spell.GetSpellCharges(self.spellId)
                    if ci then UpdateChargeBadge(self, ci.currentCharges, ci.maxCharges) end
                end)
            end
        end
    end)
end

-- État "buff actif" : icône pleine, bordure lumineuse, roue buff + glow
local function ApplyStyleBuffActive(iconFrame, cdData)
    iconFrame:SetAlpha(1.0)
    local si = cdData.spellInfo
    if si.type == "offensive" then
        iconFrame:SetBackdropBorderColor(1.0, 0.5, 0.1, 1)
    else
        iconFrame:SetBackdropBorderColor(0.2, 1.0, 0.4, 1)
    end
    ApplyGlow(iconFrame, true)
    -- Masquer le badge de charges pendant le buff
    if iconFrame.chargeBadge then iconFrame.chargeBadge:SetText("") end

    if iconFrame.cdOverlay then
        local dur = (cdData.buffDuration and cdData.buffDuration > 0) and cdData.buffDuration or 3
        iconFrame.cdOverlay:SetCooldown(cdData.expires - dur, dur)
    end

    iconFrame:SetScript("OnUpdate", function(self)
        local remBuff = cdData.expires - GetTime()
        if remBuff <= 0 then
            ApplyStyleOnCooldown(self, cdData)
        end
    end)
end

-- ============================================================
-- CRÉATION D'UNE ICÔNE STATIQUE (toujours présente)
-- ============================================================
local function CreateStaticIcon(spellId, spellInfo, unit, playerName)
    local db   = GetDB()
    local size = db and db.icon_size or 32

    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(size, size)
    f:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 6,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0, 0, 0, 0.85)

    f.spellId    = spellId
    f.spellInfo  = spellInfo
    f.unit       = unit
    f.playerName = playerName

    -- Texture du sort
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT",     f, "TOPLEFT",     1, -1)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local icon = C_Spell.GetSpellTexture(spellId)
    if icon then tex:SetTexture(icon) end
    f.iconTex = tex

    -- Roue de cooldown + timer natif WoW (blanc, centré, format jeu)
    local db   = GetDB()
    local flags = db and db.cd_info_flags or 7
    local showTimer   = bit.band(flags, 1) ~= 0  -- bit 1
    local showOverlay = bit.band(flags, 2) ~= 0  -- bit 2
    local showTooltip = bit.band(flags, 4) ~= 0  -- bit 4

    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints(f)
    cd:SetDrawEdge(showOverlay)
    cd:SetDrawSwipe(showOverlay)
    cd:SetHideCountdownNumbers(not showTimer)
    cd:SetCooldown(0, 0)
    f.cdOverlay = cd
    f.timerText = nil

    -- Badge de charges (affiché si sort multi-charges et charges > 1)
    if spellInfo.charges and spellInfo.charges > 1 then
        local chargeBadge = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        chargeBadge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
        chargeBadge:SetTextColor(1, 1, 1, 1)
        chargeBadge:SetText("")
        f.chargeBadge = chargeBadge
    end

    -- Tooltip — toujours activé sur le frame, mais vérifie le flag au survol
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        local db2 = GetDB()
        local flags2 = db2 and db2.cd_info_flags or 7
        if bit.band(flags2, 4) == 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetSpellByID(spellId)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ccffJoueur :|r " .. playerName)
        local typeColor = spellInfo.type == "offensive" and "|cffff5555" or "|cff5599ff"
        local typeLabel = spellInfo.type == "offensive" and "Offensif" or "Défensif"
        GameTooltip:AddLine("|cff00ccffType :|r " .. typeColor .. typeLabel .. "|r")
        local cdNow = activeCDs[playerName] and activeCDs[playerName][spellId]
        if cdNow then
            local remBuff = cdNow.expires - GetTime()
            local remCD   = cdNow.cdExpires - GetTime()
            if remBuff > 0 then
                GameTooltip:AddLine("|cff00ff44Buff actif :|r " .. FormatTime(remBuff))
            elseif remCD > 0 then
                GameTooltip:AddLine("|cffffd700CD restant :|r " .. FormatTime(remCD))
            end
        else
            GameTooltip:AddLine("|cff00ff00Disponible|r")
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ApplyStyleAvailable(f)
    return f
end

-- ============================================================
-- POSITIONNEMENT DES ICÔNES
-- Si OFF et DEF sont du même côté : layout unifié sur un seul container
-- Sinon : layout indépendant pour chaque groupe
-- ============================================================
local function LayoutAnchorGroup(group)
    local db      = GetDB()
    local size    = db and db.icon_size    or 32
    local spacing = db and db.icon_spacing or 2
    local perRow  = db and db.icons_per_row or 5
    local numRows = db and db.num_rows     or 1

    local list = {}
    for _, iconFrame in pairs(group.staticIcons) do
        list[#list + 1] = iconFrame
    end
    table.sort(list, function(a, b) return a.spellInfo.name < b.spellInfo.name end)

    local count   = #list
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
    local function addGroup(group)
        local sub = {}
        for _, f in pairs(group.staticIcons) do sub[#sub + 1] = f end
        table.sort(sub, function(a, b) return a.spellInfo.name < b.spellInfo.name end)
        for _, f in ipairs(sub) do list[#list + 1] = f end
    end
    addGroup(offGroup)
    addGroup(defGroup)

    local count   = #list
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

-- ============================================================
-- TABLE DE TRADUCTION : anchor_point → ancre sur party frame
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
    return { container = container, staticIcons = {} }
end

-- ============================================================
-- CRÉATION DES CONTAINERS D'ANCRAGE POUR UNE UNITÉ
-- ============================================================
local BuildUnitSpellIndex  -- forward declaration
local function CreateAnchorForUnit(unit)
    local parentFrame = GetUnitFrame(unit)
    if not parentFrame then return end

    local db   = GetDB()
    local apOff = db and db.anchor_point_off or "LEFT"
    local apDef = db and db.anchor_point_def or "LEFT"

    -- Offensifs — toujours ancrés sur la party frame
    local offGroup = MakeGroup(parentFrame, "anchor_point_off", "anchor_offset_x_off", "anchor_offset_y_off")

    -- Défensifs — si même côté que les offensifs, s'ancre sur le container OFF
    -- pour éviter le chevauchement ; sinon s'ancre sur la party frame
    local defTarget = (apOff == apDef) and offGroup.container or parentFrame
    local defGroup  = MakeGroup(defTarget, "anchor_point_def", "anchor_offset_x_def", "anchor_offset_y_def")

    memberAnchors[unit] = { offensive = offGroup, defensive = defGroup }

    -- En mode always_show_icons, créer les icônes statiques réparties OFF/DEF
    if db and db.always_show_icons then
        local spellIndex = BuildUnitSpellIndex(unit)
        local playerName = UnitName(unit) or unit
        for spellId, spellInfo in pairs(spellIndex) do
            local iconFrame = CreateStaticIcon(spellId, spellInfo, unit, playerName)
            if spellInfo.type == "offensive" then
                offGroup.staticIcons[spellId] = iconFrame
            else
                defGroup.staticIcons[spellId] = iconFrame
            end
        end
        -- Layout unifié si même côté, sinon indépendant
        if apOff == apDef then
            LayoutAnchorGroupsMerged(offGroup, defGroup)
        else
            LayoutAnchorGroup(offGroup)
            LayoutAnchorGroup(defGroup)
        end
    end

    RequestUnitSpec(unit)
end

-- ============================================================
-- MISE À JOUR D'UNE ICÔNE APRÈS UN CAST
-- ============================================================
-- Forward declaration nécessaire (OnCastDetected et RefreshDynamicIcons s'appellent mutuellement)
local RefreshDynamicIcons

local function OnCastDetected(unit, spellId, cdData)
    local anchor = memberAnchors[unit]
    if not anchor then return end

    local db = GetDB()

    if db and db.always_show_icons then
        -- Mode permanent : trouver l'icône dans le bon groupe (off ou def)
        local group = cdData.spellInfo.type == "offensive" and anchor.offensive or anchor.defensive
        if group then
            local iconFrame = group.staticIcons[spellId]
            if iconFrame then
                ApplyStyleBuffActive(iconFrame, cdData)
            end
        end
    else
        local playerName = UnitName(unit) or unit
        RefreshDynamicIcons(unit, playerName)
    end
end

-- ============================================================
-- MODE CLASSIQUE : icônes dynamiques (only active CDs)
-- ============================================================
RefreshDynamicIcons = function(unit, playerName)
    local anchor = memberAnchors[unit]
    if not anchor then
        CreateAnchorForUnit(unit)
        anchor = memberAnchors[unit]
    end
    if not anchor then return end

    local db      = GetDB()
    local size    = db and db.icon_size or 32
    local spacing = db and db.icon_spacing or 2
    local max     = db and db.max_icons or 5
    local now     = GetTime()

    -- Nettoyer les icônes dynamiques des deux groupes
    for _, groupKey in ipairs({"offensive", "defensive"}) do
        local group = anchor[groupKey]
        if group and group.dynamicIcons then
            for _, f in ipairs(group.dynamicIcons) do f:Hide(); f:SetParent(nil) end
        end
        if group then group.dynamicIcons = {} end
    end

    local spells = activeCDs[playerName]
    if not spells then return end

    -- Séparer les CDs actifs par type
    local lists = { offensive = {}, defensive = {} }
    for sid, cdData in pairs(spells) do
        if now < cdData.expires then
            local t = cdData.spellInfo.type == "offensive" and "offensive" or "defensive"
            lists[t][#lists[t] + 1] = cdData
        else
            spells[sid] = nil
        end
    end

    for _, groupKey in ipairs({"offensive", "defensive"}) do
        local group = anchor[groupKey]
        if not group then break end
        local list = lists[groupKey]
        table.sort(list, function(a, b) return a.expires < b.expires end)
        group.container:SetSize(math.max(#list, 1) * (size + spacing), size)
        for i, cdData in ipairs(list) do
            if i > max then break end
            local iconFrame = CreateStaticIcon(cdData.spellId, cdData.spellInfo, unit, playerName)
            iconFrame:SetParent(group.container)
            iconFrame:ClearAllPoints()
            iconFrame:SetPoint("RIGHT", group.container, "RIGHT", -(i-1) * (size + spacing), 0)
            iconFrame:Show()
            ApplyStyleBuffActive(iconFrame, cdData)
            group.dynamicIcons[#group.dynamicIcons + 1] = iconFrame
        end
    end
end

-- ============================================================
-- DÉTECTION DES SORTS
-- On écoute UNIT_AURA par unité et on itère les auras actives
-- C_UnitAuras.GetUnitAuras retourne toutes les auras avec leur
-- durée réelle (StartTime + TotalDuration via GetAuraDuration)
-- ============================================================

-- Filtres à interroger pour trouver nos sorts
-- On itère d'abord les filtres spécifiques, puis HELPFUL en fallback
-- pour capturer les sorts qui ne sont pas taggés IMPORTANT/BIG_DEFENSIVE
local AURA_FILTERS = {
    "HELPFUL|IMPORTANT",
    "HELPFUL|BIG_DEFENSIVE",
    "HELPFUL|EXTERNAL_DEFENSIVE",
    "HELPFUL",   -- fallback : capture tout le reste (ex: Instincts de survie)
}

-- Construit un index spellId→spellInfo pour les sorts trackés d'une unité
-- Utilise la nouvelle structure CT.Spells[class][specId/"common"]
-- Inclut les sorts "common" + les sorts de la spé de l'unité
-- Si spé inconnue : inclut tous les sorts de la classe (permissif)
BuildUnitSpellIndex = function(unit)
    local db = GetDB()
    if not db then return {} end
    local unitClass = select(2, UnitClass(unit))
    if not unitClass then return {} end

    local classSpells = CT.Spells[unitClass]
    if not classSpells then return {} end

    local unitSpec = GetUnitSpec(unit)
    local index = {}

    local function AddSpells(bucket)
        if not bucket then return end
        for spellId, spellInfo in pairs(bucket) do
            if IsTracked(spellId)
            and ((spellInfo.type == "offensive" and db.show_offensive)
              or (spellInfo.type == "defensive" and db.show_defensive))
            then
                index[spellId] = spellInfo
            end
        end
    end

    -- Toujours inclure les sorts communs
    AddSpells(classSpells.common)

    if unitSpec then
        -- Spé connue → seulement les sorts de cette spé
        AddSpells(classSpells[unitSpec])
    else
        -- Spé inconnue → inclure tous les sorts de toutes les spés (permissif)
        for key, bucket in pairs(classSpells) do
            if key ~= "common" then
                AddSpells(bucket)
            end
        end
    end

    return index
end

-- Lit toutes les auras actives sur une unité et retourne
-- celles qui correspondent à nos sorts trackés
-- Retourne : table { [spellId] = { startTime, duration, expirationTime } }
local function ScanUnitAuras(unit, spellIndex)
    local found = {}
    for _, filter in ipairs(AURA_FILTERS) do
        local auras = C_UnitAuras.GetUnitAuras(unit, filter)
        if auras then
            for _, auraData in ipairs(auras) do
                local sid = auraData.spellId
                -- Ignorer les secret values (issecretvalue)
                if issecretvalue(sid) then sid = nil end
                if sid and spellIndex[sid] and not found[sid] then
                    local auraInstanceID = auraData.auraInstanceID
                    if issecretvalue(auraInstanceID) then auraInstanceID = nil end

                    local startTime, duration
                    if auraInstanceID then
                        local durationInfo = C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
                        startTime = durationInfo and durationInfo:GetStartTime()
                        duration  = durationInfo and durationInfo:GetTotalDuration()
                    end

                    -- Fallback : champs directs
                    if not startTime or not duration then
                        startTime = auraData.startTime
                        duration  = auraData.duration
                        if issecretvalue(startTime) then startTime = nil end
                        if issecretvalue(duration)  then duration  = nil end
                    end

                    if startTime and duration and duration > 0 then
                        found[sid] = {
                            startTime      = startTime,
                            duration       = duration,
                            expirationTime = startTime + duration,
                        }
                    end
                end
            end
        end
    end
    return found
end

-- Met à jour le badge de charges sur une icône
-- currentCharges : nombre de charges actuellement disponibles
-- maxCharges : nombre total de charges
UpdateChargeBadge = function(iconFrame, currentCharges, maxCharges)
    if not iconFrame.chargeBadge then return end
    if not maxCharges or maxCharges <= 1 then return end
    if not currentCharges then
        iconFrame.chargeBadge:SetText("")
        return
    end

    if currentCharges == 0 then
        -- Toutes les charges consommées — pas de badge, le CD s'affiche
        iconFrame.chargeBadge:SetText("")
    else
        -- 1 ou plusieurs charges dispo — blanc dans tous les cas
        iconFrame.chargeBadge:SetText(currentCharges)
        iconFrame.chargeBadge:SetTextColor(1, 1, 1, 1)
    end
end

-- Traite les auras trouvées sur une unité :
-- - Nouvelles auras → créer/mettre à jour cdData + OnCastDetected
-- - Sorts avec charges → gérer via GetSpellCharges
local function ProcessUnitAuras(unit)
    local db = GetDB()
    if not db then return end
    if db.filter_self and unit == "player" then return end

    local sourceName = UnitName(unit)
    if not sourceName then return end

    local spellIndex  = BuildUnitSpellIndex(unit)
    local activeAuras = ScanUnitAuras(unit, spellIndex)

    if not activeCDs[sourceName] then activeCDs[sourceName] = {} end
    local now = GetTime()

    for spellId, spellInfo in pairs(spellIndex) do
        local aura   = activeAuras[spellId]
        local cdData = activeCDs[sourceName][spellId]

        -- Mise à jour du badge de charges (uniquement pour le joueur local)
        -- Pour les autres membres on ne peut pas lire leurs charges
        if spellInfo.charges and unit == "player" then
            local anchor = memberAnchors[unit]
            if anchor then
                local group = spellInfo.type == "offensive" and anchor.offensive or anchor.defensive
                local iconFrame = group and group.staticIcons and group.staticIcons[spellId]
                if iconFrame then
                    local chargeInfo = C_Spell.GetSpellCharges(spellId)
                    if chargeInfo then
                        local curCharges = chargeInfo.currentCharges
                        local maxCharges = chargeInfo.maxCharges
                        UpdateChargeBadge(iconFrame, curCharges, maxCharges)
                        -- Déclencher le CD uniquement si TOUTES les charges sont consommées
                        if curCharges == 0 and not cdData then
                            local chargeStart    = chargeInfo.cooldownStartTime
                            local chargeDuration = chargeInfo.cooldownDuration
                            if chargeStart and chargeDuration and chargeDuration > 0 then
                                activeCDs[sourceName][spellId] = {
                                    expires      = now - 1,
                                    cdExpires    = chargeStart + chargeDuration,
                                    buffDuration = 0,
                                    spellInfo    = spellInfo,
                                    spellId      = spellId,
                                    playerName   = sourceName,
                                    unit         = unit,
                                }
                                OnCastDetected(unit, spellId, activeCDs[sourceName][spellId])
                            end
                        elseif curCharges and curCharges > 0 and cdData then
                            -- Une charge est revenue → annuler le CD affiché
                            activeCDs[sourceName][spellId] = nil
                            local anchor = memberAnchors[unit]
                            if anchor then
                                local group = spellInfo.type == "offensive" and anchor.offensive or anchor.defensive
                                local ico = group and group.staticIcons and group.staticIcons[spellId]
                                if ico then ApplyStyleAvailable(ico) end
                            end
                        end
                    end
                end
            end
        end

        if aura then
            local expTime = aura.expirationTime
            local buffDur = aura.duration or 0
            local cdEnd   = expTime - buffDur + spellInfo.cooldown

            if cdData and expTime > cdData.expires then
                cdData.expires      = expTime
                cdData.cdExpires    = cdEnd
                cdData.buffDuration = buffDur
                OnCastDetected(unit, spellId, cdData)
            elseif cdData then
                cdData.expires      = expTime
                cdData.cdExpires    = cdEnd
                cdData.buffDuration = buffDur
            else
                activeCDs[sourceName][spellId] = {
                    expires      = expTime,
                    cdExpires    = cdEnd,
                    buffDuration = buffDur,
                    spellInfo    = spellInfo,
                    spellId      = spellId,
                    playerName   = sourceName,
                    unit         = unit,
                }
                cdData = activeCDs[sourceName][spellId]

                if db.show_chat_message then
                    local typeColor = spellInfo.type == "offensive" and "|cffff4444" or "|cff44aaff"
                    local typeLabel = spellInfo.type == "offensive" and "OFFENSIF" or "DÉFENSIF"
                    local spellName = C_Spell.GetSpellName(spellId) or spellInfo.name
                    print(string.format("|cff00ccff[CD]|r %s » %s[%s]|r %s",
                        sourceName, typeColor, typeLabel, spellName))
                    if db.announce_in_party and IsInGroup() then
                        SendChatMessage(string.format("[CD %s] %s: %s (%s)",
                            typeLabel, sourceName, spellName,
                            FormatTime(spellInfo.cooldown)), "PARTY")
                    end
                end

                OnCastDetected(unit, spellId, cdData)
            end
        end
    end
end

local function RegisterUnitSpellEvents(unit)
    if unitEventFrames[unit] then
        unitEventFrames[unit]:UnregisterAllEvents()
        unitEventFrames[unit]:SetScript("OnEvent", nil)
    end

    if not UnitExists(unit) then
        unitEventFrames[unit] = nil
        return
    end

    local f = CreateFrame("Frame")
    f:RegisterUnitEvent("UNIT_AURA", unit)
    f:SetScript("OnEvent", function(_, event, unitArg, updateInfo)
        if event == "UNIT_AURA" then
            ProcessUnitAuras(unit)
        end
    end)
    unitEventFrames[unit] = f

    -- Scan initial pour les auras déjà actives au moment de l'enregistrement
    ProcessUnitAuras(unit)
end

local function UnregisterAllUnitSpellEvents()
    for unit, f in pairs(unitEventFrames) do
        f:UnregisterAllEvents()
        f:SetScript("OnEvent", nil)
    end
    unitEventFrames = {}
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
                for _, f in pairs(group.staticIcons or {}) do f:Hide(); f:SetParent(nil) end
                if group.dynamicIcons then
                    for _, f in ipairs(group.dynamicIcons) do f:Hide(); f:SetParent(nil) end
                end
            end
        end
    end
    memberAnchors = {}
    UnregisterAllUnitSpellEvents()

    -- Ne rien afficher si le joueur n'est pas dans un groupe
    if not IsInGroup() then return end

    -- Recréer pour chaque membre du groupe
    if IsInRaid() then
        for i = 1, 40 do
            local u = "raid" .. i
            if UnitExists(u) then
                CreateAnchorForUnit(u)
                RegisterUnitSpellEvents(u)
            end
        end
    else
        CreateAnchorForUnit("player")
        RegisterUnitSpellEvents("player")
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then
                CreateAnchorForUnit(u)
                RegisterUnitSpellEvents(u)
            end
        end
    end

    -- En mode classique, réappliquer les CDs actifs encore valides
    local db = GetDB()
    if db and not db.always_show_icons then
        local now = GetTime()
        for unit, anchor in pairs(memberAnchors) do
            local playerName = UnitName(unit)
            if playerName then
                local spells = activeCDs[playerName]
                if spells then
                    for spellId, cdData in pairs(spells) do
                        if now < cdData.expires then
                            OnCastDetected(unit, spellId, cdData)
                        end
                    end
                end
            end
        end
    end
end
CT.RebuildAllAnchors = RebuildAllAnchors

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
    RebuildAllAnchors()
    print("|cff00ff00[CooldownTracker]|r Chargé. Tapez |cffffcc00/ct|r pour l'aide.")
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

    eventsFrame = CreateFrame("Frame")
    local function OnGameEvent(_, ev, arg1)
        if ev == "GROUP_ROSTER_UPDATE" or ev == "RAID_ROSTER_UPDATE" then
            unitSpecs = {}
            RebuildAllAnchors()
        elseif ev == "PLAYER_ENTERING_WORLD" then
            unitSpecs = {}
            C_Timer.After(1, RebuildAllAnchors)
        elseif ev == "INSPECT_READY" then
            local groupType  = IsInRaid() and "raid" or "party"
            local maxMembers = IsInRaid() and 40 or 4
            for i = 1, maxMembers do
                local u = groupType .. i
                if UnitExists(u) and UnitGUID(u) == arg1 then
                    local specId = GetInspectSpecialization(u)
                    if specId and specId > 0 then
                        local prev = unitSpecs[u]
                        unitSpecs[u] = specId
                        if prev ~= specId and memberAnchors[u] then
                            local anchor = memberAnchors[u]
                            for _, gk in ipairs({"offensive","defensive"}) do
                                local g = anchor[gk]
                                if g then
                                    if g.container then g.container:Hide() end
                                    for _, f in pairs(g.staticIcons or {}) do f:Hide(); f:SetParent(nil) end
                                end
                            end
                            memberAnchors[u] = nil
                            CreateAnchorForUnit(u)
                        end
                    end
                    break
                end
            end
        elseif ev == "PLAYER_SPECIALIZATION_CHANGED" then
            unitSpecs[arg1] = nil
            if memberAnchors[arg1] then
                local anchor = memberAnchors[arg1]
                for _, gk in ipairs({"offensive","defensive"}) do
                    local g = anchor[gk]
                    if g then
                        if g.container then g.container:Hide() end
                        for _, f in pairs(g.staticIcons or {}) do f:Hide(); f:SetParent(nil) end
                    end
                end
                memberAnchors[arg1] = nil
                CreateAnchorForUnit(arg1)
            end
        end
    end
    eventsFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventsFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventsFrame:RegisterEvent("INSPECT_READY")
    eventsFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
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
SLASH_COOLDOWNTRACKER1 = "/ct"
SLASH_COOLDOWNTRACKER2 = "/cooldowntracker"
SlashCmdList["COOLDOWNTRACKER"] = function(msg)
    local cmd = (msg or ""):lower():trim()
    local db  = GetDB()

    if cmd == "" or cmd == "help" then
        print("|cff00ccff[CooldownTracker] Commandes :|r")
        print("  |cffffcc00/ct|r           — Ouvrir les options (Échap > Options > Addons)")
        print("  |cffffcc00/ct off|r       — Toggle CDs offensifs")
        print("  |cffffcc00/ct def|r       — Toggle CDs défensifs")
        print("  |cffffcc00/ct chat|r      — Toggle messages chat")
        print("  |cffffcc00/ct clear|r     — Effacer les CDs affichés")
        print("  |cffffcc00/ct status|r    — Config actuelle")
    elseif cmd == "off" then
        if db then db.show_offensive = not db.show_offensive end
        print("|cff00ccff[CT]|r Offensifs : " .. (db and db.show_offensive and "|cff00ff00On|r" or "|cffff4444Off|r"))
    elseif cmd == "def" then
        if db then db.show_defensive = not db.show_defensive end
        print("|cff00ccff[CT]|r Défensifs : " .. (db and db.show_defensive and "|cff00ff00On|r" or "|cffff4444Off|r"))
    elseif cmd == "chat" then
        if db then db.show_chat_message = not db.show_chat_message end
        print("|cff00ccff[CT]|r Chat : " .. (db and db.show_chat_message and "|cff00ff00On|r" or "|cffff4444Off|r"))
    elseif cmd == "clear" then
        activeCDs = {}
        RebuildAllAnchors()
        print("|cff00ccff[CT]|r CDs effacés.")
    elseif cmd == "status" then
        if not db then print("|cffff4444[CT]|r Non initialisé.") return end
        print("|cff00ccff[CT]|r Offensifs:" .. (db.show_offensive and "On" or "Off")
            .. "  Défensifs:" .. (db.show_defensive and "On" or "Off")
            .. "  Chat:" .. (db.show_chat_message and "On" or "Off")
            .. "  Taille:" .. db.icon_size .. "px"
            .. "  Mode:" .. (db.always_show_icons and "Permanent" or "Actif seulement"))
    else
        if Settings and Settings.OpenToCategory and CT.SettingsCategory then
            Settings.OpenToCategory(CT.SettingsCategory:GetID())
        else
            print("|cffff4444[CT]|r Commande inconnue. /ct help pour l'aide.")
        end
    end
end
