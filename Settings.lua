-- Settings.lua
-- Panneau d'options utilisant l'API native Blizzard Settings (WoW 10.0+)

local addonName, CT = ...

-- ============================================================
-- HELPER : crée les widgets natifs pour une catégorie donnée
-- ============================================================
local function MakeCategoryHelpers(category)
    local function AddCheckbox(key, label, tooltip, onChange)
        local function GetValue() return CooldownTrackerDB[key] end
        local function SetValue(value)
            CooldownTrackerDB[key] = value
            if onChange then onChange() end
        end
        local setting = Settings.RegisterProxySetting(
            category, "CT_" .. key,
            Settings.VarType.Boolean, label,
            CooldownTrackerDB[key], GetValue, SetValue)
        Settings.CreateCheckbox(category, setting, tooltip or "")
    end

    local function AddSlider(key, label, tooltip, minV, maxV, step, onChange)
        local function GetValue() return CooldownTrackerDB[key] end
        local function SetValue(value)
            CooldownTrackerDB[key] = value
            if onChange then onChange() else CT.RebuildAllAnchors() end
        end
        local setting = Settings.RegisterProxySetting(
            category, "CT_" .. key,
            Settings.VarType.Number, label,
            CooldownTrackerDB[key], GetValue, SetValue)
        local options = Settings.CreateSliderOptions(minV, maxV, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, setting, options, tooltip or "")
    end

    local function AddDropdown(key, label, tooltip, values, onChange)
        local function GetValue() return CooldownTrackerDB[key] end
        local function SetValue(value)
            CooldownTrackerDB[key] = value
            if onChange then onChange() end
        end
        local setting = Settings.RegisterProxySetting(
            category, "CT_" .. key,
            Settings.VarType.String, label,
            CooldownTrackerDB[key], GetValue, SetValue)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            for _, entry in ipairs(values) do container:Add(entry.value, entry.text) end
            return container:GetData()
        end
        Settings.CreateDropdown(category, setting, GetOptions, tooltip or "")
    end

    local _, layout = Settings.GetCategory(category:GetID())
    local function AddHeader(label)
        if layout then layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(label)) end
    end

    return AddCheckbox, AddSlider, AddDropdown, AddHeader
end

-- ============================================================
-- ENREGISTREMENT — appelé après ADDON_LOADED
-- ============================================================
local function BuildPanel()
    local db = CooldownTrackerDB
    if not db then return end

    -- ── Catégorie principale ──────────────────────────────────
    local CT_VERSION = C_AddOns.GetAddOnMetadata("CooldownTracker", "Version") or "1.0.0"
    local category, layout = Settings.RegisterVerticalLayoutCategory("CooldownTracker")

    local function AddCheckbox(key, label, tooltip, onChange)
        local function GetValue() return CooldownTrackerDB[key] end
        local function SetValue(value)
            CooldownTrackerDB[key] = value
            if onChange then onChange() end
        end
        local setting = Settings.RegisterProxySetting(
            category, "CT_" .. key,
            Settings.VarType.Boolean, label,
            CooldownTrackerDB[key], GetValue, SetValue)
        Settings.CreateCheckbox(category, setting, tooltip or "")
    end

    local function AddSlider(key, label, tooltip, minV, maxV, step, onChange)
        local function GetValue() return CooldownTrackerDB[key] end
        local function SetValue(value)
            CooldownTrackerDB[key] = value
            if onChange then onChange() else CT.RebuildAllAnchors() end
        end
        local setting = Settings.RegisterProxySetting(
            category, "CT_" .. key,
            Settings.VarType.Number, label,
            CooldownTrackerDB[key], GetValue, SetValue)
        local options = Settings.CreateSliderOptions(minV, maxV, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, setting, options, tooltip or "")
    end

    local function AddDropdown(key, label, tooltip, values, onChange)
        local function GetValue() return CooldownTrackerDB[key] end
        local function SetValue(value)
            CooldownTrackerDB[key] = value
            if onChange then onChange() end
        end
        local setting = Settings.RegisterProxySetting(
            category, "CT_" .. key,
            Settings.VarType.String, label,
            CooldownTrackerDB[key], GetValue, SetValue)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            for _, entry in ipairs(values) do container:Add(entry.value, entry.text) end
            return container:GetData()
        end
        Settings.CreateDropdown(category, setting, GetOptions, tooltip or "")
    end

    local function AddHeader(label)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(label))
    end

    -- ── Version + Options ────────────────────────────────────
    AddHeader("|cff888888Version : v" .. CT_VERSION .. "|r")
    AddHeader("Options")

    -- Multi-select "Informations CD" (bitfield : bit1=timer, bit2=roue)
    do
        local function GetValue() return CooldownTrackerDB.cd_info_flags or 3 end
        local function SetValue(mask)
            CooldownTrackerDB.cd_info_flags = mask
            CT.RebuildAllAnchors()
        end
        local setting = Settings.RegisterProxySetting(
            category, "CT_cd_info_flags",
            Settings.VarType.Number,
            "Informations CD",
            7,
            GetValue, SetValue)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            container:AddCheckbox(1, "Afficher le timer",            "Affiche le temps restant sur chaque icône.")
            container:AddCheckbox(2, "Afficher la roue de cooldown", "Anime une roue pendant la durée du buff/CD.")
            container:AddCheckbox(3, "Afficher le tooltip",          "Affiche les informations au survol de l'icône.")
            return container:GetData()
        end
        Settings.CreateDropdown(category, setting, GetOptions, "Sélectionner les informations affichées sur les icônes.")
    end

    AddCheckbox("show_chat_message", "Messages dans le chat",   "Annonce les CDs dans le chat local.")
    AddCheckbox("filter_self",       "Ignorer mes propres CDs", "Ne pas tracker les sorts du joueur local.")

    -- ── Disposition ──────────────────────────────────────────
    AddHeader("Disposition")
    AddSlider("num_rows",      "Nombre de lignes", "Nombre de lignes d'icônes.", 1, 5,  1, CT.RebuildAllAnchors)
    AddSlider("icons_per_row", "Icônes par ligne", "Nombre maximum d'icônes par ligne.", 1, 10, 1)

    -- ── Icône ────────────────────────────────────────────────
    AddHeader("Icône")
    AddSlider("icon_size",    "Taille (px)",     "Taille des icônes en pixels.", 16, 64, 2)
    AddSlider("icon_spacing", "Espacement (px)", "Espace entre les icônes.",      0, 20, 1)

    Settings.RegisterAddOnCategory(category)
    CT.SettingsCategory = category

    -- ── Sous-catégorie : CD Offensif ─────────────────────────
    local offPanel, offLayout = Settings.RegisterVerticalLayoutSubcategory(category, "CD Offensif")
    Settings.RegisterAddOnCategory(offPanel)

    local function AddCheckboxOff(key, label, tooltip, onChange)
        local function GetValue() return CooldownTrackerDB[key] end
        local function SetValue(value) CooldownTrackerDB[key] = value; if onChange then onChange() end end
        local s = Settings.RegisterProxySetting(offPanel, "CT_"..key, Settings.VarType.Boolean, label, CooldownTrackerDB[key], GetValue, SetValue)
        Settings.CreateCheckbox(offPanel, s, tooltip or "")
    end
    local function AddSliderOff(key, label, tooltip, minV, maxV, step)
        local function GetValue() return CooldownTrackerDB[key] end
        local function SetValue(value) CooldownTrackerDB[key] = value; CT.RebuildAllAnchors() end
        local s = Settings.RegisterProxySetting(offPanel, "CT_"..key, Settings.VarType.Number, label, CooldownTrackerDB[key], GetValue, SetValue)
        local o = Settings.CreateSliderOptions(minV, maxV, step)
        o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(offPanel, s, o, tooltip or "")
    end
    local function AddDropdownOff(key, label, tooltip, values, onChange)
        local function GetValue() return CooldownTrackerDB[key] end
        local function SetValue(value) CooldownTrackerDB[key] = value; if onChange then onChange() end end
        local s = Settings.RegisterProxySetting(offPanel, "CT_"..key, Settings.VarType.String, label, CooldownTrackerDB[key], GetValue, SetValue)
        local function GetOptions() local c = Settings.CreateControlTextContainer(); for _,e in ipairs(values) do c:Add(e.value, e.text) end; return c:GetData() end
        Settings.CreateDropdown(offPanel, s, GetOptions, tooltip or "")
    end

    local function AddHeaderOff(label)
        offLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(label))
    end

    AddHeaderOff("Options")
    AddCheckboxOff("show_offensive",        "Activer",                          "Affiche les cooldowns offensifs du groupe.", CT.RebuildAllAnchors)
    AddCheckboxOff("persistent_icons_off",  "Garder les icônes après expiration", "Les icônes offensives restent visibles après la fin du buff.", CT.RebuildAllAnchors)
    AddCheckboxOff("glow_on_active_off",    "Glow quand buff actif",            "Affiche un glow sur les icônes offensives pendant le buff.")

    AddHeaderOff("Position")
    AddDropdownOff("anchor_point_off", "Ancrage", "Côté de la party frame pour les CDs offensifs.", {
        { value = "LEFT",   text = "Gauche" }, { value = "RIGHT",  text = "Droite" },
        { value = "TOP",    text = "Haut"   }, { value = "BOTTOM", text = "Bas"    },
    }, CT.RebuildAllAnchors)
    AddSliderOff("anchor_offset_x_off", "Offset X (px)", "Décalage horizontal des CDs offensifs.", -200, 200, 1)
    AddSliderOff("anchor_offset_y_off", "Offset Y (px)", "Décalage vertical des CDs offensifs.",   -200, 200, 1)

    -- ── Sous-catégorie : CD Défensif ─────────────────────────
    local defPanel, defLayout = Settings.RegisterVerticalLayoutSubcategory(category, "CD Défensif")
    Settings.RegisterAddOnCategory(defPanel)

    local function AddCheckboxDef(key, label, tooltip, onChange)
        local function GetValue() return CooldownTrackerDB[key] end
        local function SetValue(value) CooldownTrackerDB[key] = value; if onChange then onChange() end end
        local s = Settings.RegisterProxySetting(defPanel, "CT_"..key, Settings.VarType.Boolean, label, CooldownTrackerDB[key], GetValue, SetValue)
        Settings.CreateCheckbox(defPanel, s, tooltip or "")
    end
    local function AddSliderDef(key, label, tooltip, minV, maxV, step)
        local function GetValue() return CooldownTrackerDB[key] end
        local function SetValue(value) CooldownTrackerDB[key] = value; CT.RebuildAllAnchors() end
        local s = Settings.RegisterProxySetting(defPanel, "CT_"..key, Settings.VarType.Number, label, CooldownTrackerDB[key], GetValue, SetValue)
        local o = Settings.CreateSliderOptions(minV, maxV, step)
        o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(defPanel, s, o, tooltip or "")
    end
    local function AddDropdownDef(key, label, tooltip, values, onChange)
        local function GetValue() return CooldownTrackerDB[key] end
        local function SetValue(value) CooldownTrackerDB[key] = value; if onChange then onChange() end end
        local s = Settings.RegisterProxySetting(defPanel, "CT_"..key, Settings.VarType.String, label, CooldownTrackerDB[key], GetValue, SetValue)
        local function GetOptions() local c = Settings.CreateControlTextContainer(); for _,e in ipairs(values) do c:Add(e.value, e.text) end; return c:GetData() end
        Settings.CreateDropdown(defPanel, s, GetOptions, tooltip or "")
    end

    local function AddHeaderDef(label)
        defLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(label))
    end

    AddHeaderDef("Options")
    AddCheckboxDef("show_defensive",        "Activer",                          "Affiche les cooldowns défensifs du groupe.", CT.RebuildAllAnchors)
    AddCheckboxDef("persistent_icons_def",  "Garder les icônes après expiration", "Les icônes défensives restent visibles après la fin du buff.", CT.RebuildAllAnchors)
    AddCheckboxDef("glow_on_active_def",    "Glow quand buff actif",            "Affiche un glow sur les icônes défensives pendant le buff.")

    AddHeaderDef("Position")
    AddDropdownDef("anchor_point_def", "Ancrage", "Côté de la party frame pour les CDs défensifs.", {
        { value = "LEFT",   text = "Gauche" }, { value = "RIGHT",  text = "Droite" },
        { value = "TOP",    text = "Haut"   }, { value = "BOTTOM", text = "Bas"    },
    }, CT.RebuildAllAnchors)
    AddSliderDef("anchor_offset_x_def", "Offset X (px)", "Décalage horizontal des CDs défensifs.", -200, 200, 1)
    AddSliderDef("anchor_offset_y_def", "Offset Y (px)", "Décalage vertical des CDs défensifs.",   -200, 200, 1)

    -- ── Sous-catégories canvas ────────────────────────────────
    BuildSpellsPanel(category)
end

-- ============================================================
-- SOUS-PANNEAU CANVAS POUR LA LISTE DES SORTS
-- ============================================================
function BuildSpellsPanel(parentCategory)
    local spellPanel = CreateFrame("Frame")
    spellPanel.name = "Sorts"

    local sf = CreateFrame("ScrollFrame", nil, spellPanel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     spellPanel, "TOPLEFT",     0,  -8)
    sf:SetPoint("BOTTOMRIGHT", spellPanel, "BOTTOMRIGHT", -20, 8)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetSize(1, 1)
    sf:SetScrollChild(sc)

    local built = false

    spellPanel:SetScript("OnShow", function()
        if built then return end
        local width = sf:GetWidth()
        if width <= 0 then return end
        built = true
        sc:SetWidth(width)

        local db   = CooldownTrackerDB
        if not db then return end
        if not db.tracked_spells then db.tracked_spells = {} end

        local lineH    = 28
        local hdrH     = 28
        local specHdrH = 22
        local yOff     = -4

        -- ── Helper : header de classe ──────────────────────────
        local function MakeClassHeader(text, color, yPos)
            -- Marge avant chaque classe (sauf la première)
            local hdr = CreateFrame("Frame", nil, sc, "BackdropTemplate")
            hdr:SetPoint("TOPLEFT",  sc, "TOPLEFT",  0, yPos)
            hdr:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, yPos)
            hdr:SetHeight(hdrH)

            -- Fond coloré semi-transparent avec la couleur de classe
            local r, g, b = color and color[1] or 0.5, color and color[2] or 0.5, color and color[3] or 0.5
            hdr:SetBackdrop({
                bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Buttons/WHITE8X8",
                edgeSize = 1,
            })
            hdr:SetBackdropColor(r * 0.25, g * 0.25, b * 0.25, 0.9)
            hdr:SetBackdropBorderColor(r, g, b, 0.8)

            -- Nom de classe
            local fs = hdr:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
            fs:SetPoint("TOPLEFT",     hdr, "TOPLEFT",     10, 0)
            fs:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", -60, 0)
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("MIDDLE")
            if color then fs:SetTextColor(r, g, b, 1) end
            fs:SetText(text)

            return hdr, fs
        end

        -- ── Helper : header de spé ─────────────────────────────
        local function MakeHeader(text, color, height, fontSize, yPos)
            local hdr = CreateFrame("Frame", nil, sc)
            hdr:SetPoint("TOPLEFT",  sc, "TOPLEFT",  0, yPos)
            hdr:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, yPos)
            hdr:SetHeight(height)

            local tex = hdr:CreateTexture(nil, "BACKGROUND")
            tex:SetAllPoints()
            tex:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
            tex:SetHorizTile(true)

            local fs = hdr:CreateFontString(nil, "OVERLAY", fontSize)
            fs:SetPoint("TOPLEFT",     hdr, "TOPLEFT",     10, 0)
            fs:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", -60, 0)
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("MIDDLE")
            if color then fs:SetTextColor(color[1], color[2], color[3]) end
            fs:SetText(text)

            return hdr, fs
        end

        -- ── Helper : dessiner une ligne de sort ────────────────
        local function MakeSpellRow(spellId, spellInfo, yPos, rowIdx, onToggle)
            local key = tostring(spellId)
            if db.tracked_spells[key] == nil then db.tracked_spells[key] = true end

            local rowBg = sc:CreateTexture(nil, "BACKGROUND")
            rowBg:SetPoint("TOPLEFT",  sc, "TOPLEFT",  0, yPos)
            rowBg:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, yPos)
            rowBg:SetHeight(lineH)
            rowBg:SetColorTexture(1, 1, 1, rowIdx % 2 == 0 and 0.04 or 0.0)

            local row = CreateFrame("Frame", nil, sc)
            row:SetPoint("TOPLEFT",  sc, "TOPLEFT",  0, yPos)
            row:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, yPos)
            row:SetHeight(lineH)

            -- Icône sort — centrée verticalement
            local iconTex = row:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(20, 20)
            iconTex:SetPoint("LEFT", row, "LEFT", 8, 0)
            iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local icon = C_Spell.GetSpellTexture(spellId)
            if icon then iconTex:SetTexture(icon) end

            -- Badge OFF/DEF
            local badge = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            badge:SetSize(36, lineH)
            badge:SetPoint("LEFT", row, "LEFT", 34, 0)
            badge:SetJustifyH("LEFT")
            badge:SetJustifyV("MIDDLE")
            if spellInfo.type == "offensive" then
                badge:SetTextColor(1, 0.4, 0.4) ; badge:SetText("OFF")
            else
                badge:SetTextColor(0.4, 0.7, 1)  ; badge:SetText("DEF")
            end

            -- Nom
            local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameLabel:SetSize(160, lineH)
            nameLabel:SetPoint("LEFT", row, "LEFT", 76, 0)
            nameLabel:SetJustifyH("LEFT")
            nameLabel:SetJustifyV("MIDDLE")
            nameLabel:SetText(spellInfo.name)

            -- CD
            local cdLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cdLabel:SetSize(72, lineH)
            cdLabel:SetPoint("LEFT", row, "LEFT", 242, 0)
            cdLabel:SetJustifyV("MIDDLE")
            cdLabel:SetTextColor(0.6, 0.6, 0.6)
            cdLabel:SetText("CD: " .. CT.FormatTime(spellInfo.cooldown))

            -- Checkbox style Blizzard Settings
            local cb = CreateFrame("CheckButton", "CTSpellCB_" .. key, row, "SettingsCheckBoxTemplate")
            cb:SetSize(26, 26)
            cb:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            cb:SetChecked(db.tracked_spells[key])

            local function UpdateStyle()
                if db.tracked_spells[key] then
                    nameLabel:SetTextColor(WHITE_FONT_COLOR:GetRGB())
                    iconTex:SetAlpha(1.0)
                else
                    nameLabel:SetTextColor(DISABLED_FONT_COLOR:GetRGB())
                    iconTex:SetAlpha(0.4)
                end
            end
            UpdateStyle()
            cb:SetScript("OnClick", function(self)
                db.tracked_spells[key] = self:GetChecked() and true or false
                UpdateStyle()
                if onToggle then onToggle() end
            end)

            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(spellId)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)

            return db.tracked_spells[key] and 1 or 0
        end

        -- ── Itérer par classe ──────────────────────────────────
        for _, className in ipairs(CT.ClassOrder) do
            local classData = CT.Spells[className]
            if classData then

            -- Compter les sorts total pour cette classe
            local totalCount = 0
            local allSpellIds = {}  -- tous les spellIds de la classe pour "tout cocher"
            local function collectSpells(bucket)
                if not bucket then return end
                for sid, _ in pairs(bucket) do
                    totalCount = totalCount + 1
                    allSpellIds[#allSpellIds + 1] = tostring(sid)
                    -- Initialiser tracked_spells si nécessaire
                    if db.tracked_spells[tostring(sid)] == nil then
                        db.tracked_spells[tostring(sid)] = true
                    end
                end
            end
            collectSpells(classData.common)
            for k, v in pairs(classData) do
                if k ~= "common" then collectSpells(v) end
            end
            if totalCount > 0 then

            -- Marge avant le header de classe (sauf le tout premier)
            if yOff < -4 then yOff = yOff - 8 end

            -- Header classe
            local cc = CT.ClassColors[className]
            local classHdr, classHdrText = MakeClassHeader(
                CT.ClassLabels[className] or className, cc, yOff)

            -- Compteur dynamique (recalculé à chaque clic)
            local counter = classHdr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            counter:SetPoint("TOPRIGHT",    classHdr, "TOPRIGHT",    -50, 0)
            counter:SetPoint("BOTTOMRIGHT", classHdr, "BOTTOMRIGHT", -50, 0)
            counter:SetJustifyH("RIGHT")
            counter:SetJustifyV("MIDDLE")
            counter:SetTextColor(0.7, 0.7, 0.7)

            local function RefreshCounter()
                local enabled = 0
                for _, k in ipairs(allSpellIds) do
                    if db.tracked_spells[k] ~= false then enabled = enabled + 1 end
                end
                counter:SetText(enabled .. " / " .. totalCount)
            end
            RefreshCounter()

            -- Bouton "Tout cocher / décocher" — texte cliquable discret
            local allBtn = CreateFrame("Button", nil, classHdr)
            allBtn:SetSize(40, hdrH)
            allBtn:SetPoint("TOPRIGHT", classHdr, "TOPRIGHT", -4, 0)
            local allBtnTxt = allBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            allBtnTxt:SetAllPoints()
            allBtnTxt:SetJustifyH("RIGHT")
            allBtnTxt:SetJustifyV("MIDDLE")
            allBtnTxt:SetTextColor(0.8, 0.8, 0.8)
            allBtnTxt:SetText("Tout")
            allBtn:SetScript("OnEnter", function(self)
                allBtnTxt:SetTextColor(1, 0.82, 0)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Tout cocher / décocher", 1, 1, 1)
                GameTooltip:Show()
            end)
            allBtn:SetScript("OnLeave", function()
                allBtnTxt:SetTextColor(0.8, 0.8, 0.8)
                GameTooltip:Hide()
            end)
            allBtn:SetScript("OnClick", function()
                local allChecked = true
                for _, k in ipairs(allSpellIds) do
                    if db.tracked_spells[k] == false then allChecked = false; break end
                end
                for _, k in ipairs(allSpellIds) do
                    db.tracked_spells[k] = not allChecked
                    if _G["CTSpellCB_" .. k] then
                        _G["CTSpellCB_" .. k]:SetChecked(not allChecked)
                    end
                end
                RefreshCounter()
                CT.RebuildAllAnchors()
            end)

            yOff = yOff - hdrH

            local rowIdx = 0
            local isFirstSection = true

            -- Sorts communs
            if classData.common and next(classData.common) then
                local commonSpells = {}
                for spellId, spellInfo in pairs(classData.common) do
                    commonSpells[#commonSpells + 1] = { id = spellId, info = spellInfo }
                end
                table.sort(commonSpells, function(a, b)
                    if a.info.type ~= b.info.type then return a.info.type == "offensive" end
                    return a.info.name < b.info.name
                end)

                if not isFirstSection then yOff = yOff - 6 end
                isFirstSection = false
                -- Header "Commun"
                local specHdr = CreateFrame("Frame", nil, sc, "BackdropTemplate")
                specHdr:SetPoint("TOPLEFT",  sc, "TOPLEFT",  4, yOff)
                specHdr:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -4, yOff)
                specHdr:SetHeight(specHdrH)
                specHdr:SetBackdrop({ bgFile="Interface/Tooltips/UI-Tooltip-Background", edgeFile="Interface/Buttons/WHITE8X8", edgeSize=1 })
                specHdr:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
                specHdr:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
                local specLbl = specHdr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                specLbl:SetPoint("LEFT", specHdr, "LEFT", 8, 0)
                specLbl:SetJustifyH("LEFT")
                specLbl:SetJustifyV("MIDDLE")
                specLbl:SetHeight(specHdrH)
                specLbl:SetTextColor(0.9, 0.9, 0.9)
                specLbl:SetText("— Commun")
                yOff = yOff - specHdrH - 4

                for _, entry in ipairs(commonSpells) do
                    rowIdx = rowIdx + 1
                    MakeSpellRow(entry.id, entry.info, yOff, rowIdx, RefreshCounter)
                    yOff = yOff - lineH
                end
            end

            -- Sorts par spé — ordre : TANK → HEAL → DPS
            local roleOrder = { TANK = 1, HEALER = 2, DAMAGER = 3 }
            local specIds = {}
            for k, _ in pairs(classData) do
                if k ~= "common" then specIds[#specIds + 1] = k end
            end
            table.sort(specIds, function(a, b)
                local roleA = CT.SpecRoles and CT.SpecRoles[a]
                local roleB = CT.SpecRoles and CT.SpecRoles[b]
                local orderA = roleOrder[roleA] or 9
                local orderB = roleOrder[roleB] or 9
                if orderA ~= orderB then return orderA < orderB end
                return a < b  -- même rôle : tri par ID
            end)

            for _, specId in ipairs(specIds) do
                local bucket = classData[specId]
                if bucket and next(bucket) then
                    if not isFirstSection then yOff = yOff - 6 end
                    isFirstSection = false

                    local specSpells = {}
                    for spellId, spellInfo in pairs(bucket) do
                        specSpells[#specSpells + 1] = { id = spellId, info = spellInfo }
                    end
                    table.sort(specSpells, function(a, b)
                        if a.info.type ~= b.info.type then return a.info.type == "offensive" end
                        return a.info.name < b.info.name
                    end)

                    -- Header spé avec icône de rôle
                    local role      = CT.SpecRoles and CT.SpecRoles[specId]
                    local specLabel = CT.SpecLabels and CT.SpecLabels[specId] or tostring(specId)

                    local specHdr = CreateFrame("Frame", nil, sc, "BackdropTemplate")
                    specHdr:SetPoint("TOPLEFT",  sc, "TOPLEFT",  4, yOff)
                    specHdr:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -4, yOff)
                    specHdr:SetHeight(specHdrH)
                    specHdr:SetBackdrop({ bgFile="Interface/Tooltips/UI-Tooltip-Background", edgeFile="Interface/Buttons/WHITE8X8", edgeSize=1 })

                    -- Couleur de fond selon le rôle
                    if role == "TANK" then
                        specHdr:SetBackdropColor(0.1, 0.1, 0.3, 0.85)
                        specHdr:SetBackdropBorderColor(0.3, 0.3, 0.8, 0.9)
                    elseif role == "HEALER" then
                        specHdr:SetBackdropColor(0.1, 0.25, 0.1, 0.85)
                        specHdr:SetBackdropBorderColor(0.2, 0.7, 0.2, 0.9)
                    else
                        specHdr:SetBackdropColor(0.25, 0.1, 0.1, 0.85)
                        specHdr:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.9)
                    end

                    -- Icône de rôle
                    if role and CT.RoleTexCoords and CT.RoleTexCoords[role] then
                        local roleIco = specHdr:CreateTexture(nil, "ARTWORK")
                        roleIco:SetSize(14, 14)
                        roleIco:SetPoint("LEFT", specHdr, "LEFT", 4, 0)
                        roleIco:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")
                        local uv = CT.RoleTexCoords[role]
                        roleIco:SetTexCoord(uv[1], uv[2], uv[3], uv[4])
                    end

                    local specLbl = specHdr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    specLbl:SetPoint("LEFT",  specHdr, "LEFT",  24, 0)
                    specLbl:SetPoint("RIGHT", specHdr, "RIGHT", -4, 0)
                    specLbl:SetHeight(specHdrH)
                    specLbl:SetJustifyH("LEFT")
                    specLbl:SetJustifyV("MIDDLE")
                    specLbl:SetTextColor(1, 0.95, 0.6)
                    specLbl:SetText(specLabel)
                    yOff = yOff - specHdrH - 4

                    for _, entry in ipairs(specSpells) do
                        rowIdx = rowIdx + 1
                        MakeSpellRow(entry.id, entry.info, yOff, rowIdx, RefreshCounter)
                        yOff = yOff - lineH
                    end
                end
            end

            yOff = yOff - 6
            end -- if totalCount > 0
            end -- if classData
        end

        sc:SetHeight(math.abs(yOff) + 10)
    end)

    if Settings and Settings.RegisterCanvasLayoutSubcategory then
        local subcat = Settings.RegisterCanvasLayoutSubcategory(parentCategory, spellPanel, spellPanel.name)
        Settings.RegisterAddOnCategory(subcat)
        CT.SpellsSubCategory = subcat
    end

    -- ── Sous-panneau Informations ─────────────────────────────
    local infoPanel = CreateFrame("Frame")
    infoPanel.name  = "Informations"

    -- ScrollFrame pour éviter le débordement
    local infoSF = CreateFrame("ScrollFrame", nil, infoPanel, "UIPanelScrollFrameTemplate")
    infoSF:SetPoint("TOPLEFT",     infoPanel, "TOPLEFT",     0,  -8)
    infoSF:SetPoint("BOTTOMRIGHT", infoPanel, "BOTTOMRIGHT", -20, 8)

    local infoSC = CreateFrame("Frame", nil, infoSF)
    infoSC:SetSize(1, 1)
    infoSF:SetScrollChild(infoSC)

    infoPanel:SetScript("OnShow", function(self)
        if self.built then return end
        self.built = true

        local width = infoSF:GetWidth()
        if width <= 0 then return end
        infoSC:SetWidth(width)

        local function AddTitle(parent, text, yPos)
            local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            fs:SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, yPos)
            fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yPos)
            fs:SetJustifyH("LEFT")
            fs:SetTextColor(1, 0.82, 0)
            fs:SetText(text)
            return fs
        end

        local function AddText(parent, text, yPos, r, g, b)
            local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, yPos)
            fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yPos)
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("TOP")
            fs:SetSpacing(4)
            fs:SetTextColor(r or 0.9, g or 0.9, b or 0.9)
            fs:SetText(text)
            return fs
        end

        local yOff = -16

        -- Titre principal
        AddTitle(infoSC, "Comment fonctionne CooldownTracker ?", yOff)
        yOff = yOff - 30

        AddText(infoSC, "CooldownTracker utilise les |cffffd700filtres Blizzard natifs|r (BIG_DEFENSIVE, EXTERNAL_DEFENSIVE, IMPORTANT) pour detecter automatiquement les cooldowns offensifs et defensifs des membres de votre groupe.", yOff)
        yOff = yOff - 55

        -- Section : Détection
        AddTitle(infoSC, "|cff00ccff Fonctionnement|r", yOff)
        yOff = yOff - 28

        AddText(infoSC, "Quand un coequipier active un CD, Blizzard signale le buff via |cffffd700UNIT_AURA|r. L'addon affiche alors une icone avec un glow anime. Quand le buff expire, l'icone passe en mode « disponible » (attenuee, sans glow).", yOff)
        yOff = yOff - 55

        AddText(infoSC, "Pour |cff00ff00vos propres sorts|r, l'addon peut identifier le nom et lancer un timer de cooldown precis apres expiration du buff. Pour les |cffff8800sorts des autres joueurs|r, les valeurs sont masquees par le systeme de securite de Midnight 12.0 — l'icone reste visible mais sans timer.", yOff)
        yOff = yOff - 65

        -- Section : Modes
        AddTitle(infoSC, "|cff00ff00 Modes d'affichage|r", yOff)
        yOff = yOff - 28

        AddText(infoSC, "|cffffd700Garder les icones|r — Les icones restent visibles en permanence apres la premiere detection, meme quand le buff a expire. Le glow et la bordure vive n'apparaissent que pendant le buff actif. Cela permet de voir d'un coup d'oeil quels CDs chaque joueur possede. Ce reglage est independant pour les CDs offensifs et defensifs.", yOff)
        yOff = yOff - 70

        AddText(infoSC, "|cffffd700Actif uniquement|r — Les icones n'apparaissent que pendant le buff actif et disparaissent des qu'il expire. Mode plus epure, utile si vous ne voulez voir que les CDs en cours.", yOff)
        yOff = yOff - 50

        -- Section : CDs Externes
        AddTitle(infoSC, "|cff00ccff CDs Externes|r", yOff)
        yOff = yOff - 28

        AddText(infoSC, "Certains CDs defensifs (Pain Suppression, Blessing of Sacrifice, etc.) sont lances par un joueur sur un autre. L'addon attribue le CD au lanceur quand la source est identifiable. Sinon, le CD apparait sur la cible avec la mention « source inconnue ».", yOff)
        yOff = yOff - 60

        -- Section : Limitations
        AddTitle(infoSC, "|cffff4444 Limitations (Midnight 12.0)|r", yOff)
        yOff = yOff - 28

        AddText(infoSC, "Le systeme de |cffffd700secret values|r de Midnight 12.0 empeche les addons de lire les noms, icones et IDs des sorts des autres joueurs. CooldownTracker contourne cette limitation en utilisant les filtres natifs de Blizzard, mais certaines informations restent inaccessibles :", yOff)
        yOff = yOff - 60

        AddText(infoSC, "- |cffffd700Identification|r : les sorts des autres joueurs apparaissent avec leur icone correcte mais ne peuvent pas etre nommes.\n- |cffffd700Cooldown precis|r : le timer de CD n'est disponible que pour vos propres sorts.\n- |cffffd700Comparaison|r : impossible de comparer deux icones pour savoir si c'est le meme sort.", yOff)
        yOff = yOff - 65

        -- Section : Conseils
        AddTitle(infoSC, "|cffaaaaff Conseils|r", yOff)
        yOff = yOff - 28

        AddText(infoSC, "- Utilisez les offsets X/Y pour positionner les icones selon votre interface.\n- Les CDs offensifs et defensifs peuvent etre ancres a des cotes differents de la party frame.\n- Tapez |cffffcc00/cdt debug|r pour activer les logs dans le chat, ou |cffffcc00/cdt log|r pour enregistrer dans un fichier.", yOff)

        infoSC:SetHeight(math.abs(yOff) + 40)
    end)

    if Settings and Settings.RegisterCanvasLayoutSubcategory then
        local infoSubcat = Settings.RegisterCanvasLayoutSubcategory(parentCategory, infoPanel, infoPanel.name)
        Settings.RegisterAddOnCategory(infoSubcat)
    end
end

-- ============================================================
-- BOOT — après ADDON_LOADED, une fois la DB initialisée
-- ============================================================
local function OnSettingsBootEvent(self, event, name)
    if event ~= "ADDON_LOADED" or name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    -- Attendre que CT.RebuildAllAnchors soit défini (Core.lua chargé avant)
    C_Timer.After(0, function()
        if CooldownTrackerDB then
            BuildPanel()
        end
    end)
end

local settingsBootFrame = CreateFrame("Frame")
settingsBootFrame:RegisterEvent("ADDON_LOADED")
settingsBootFrame:SetScript("OnEvent", OnSettingsBootEvent)
