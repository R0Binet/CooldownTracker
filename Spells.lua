local _, CT = ...

CT.Spells = {

    -- ═══════════════════════════════════════════════════════════
    WARRIOR = {
        common = {
            [97463]  = { name = "Cri de ralliement",         type = "defensive", cooldown = 180 },
            [23920]  = { name = "Renvoi de sort",             type = "defensive", cooldown = 25  },
            [107574] = { name = "Avatar",                     type = "offensive", cooldown = 90  },
        },
        [73] = { -- Protection
            [871]    = { name = "Mur de bouclier",            type = "defensive", cooldown = 240 },
            [18499]  = { name = "Rage de berserker",          type = "defensive", cooldown = 240 },
        },
        [71] = { -- Arms
            [1719]   = { name = "Témérité",                   type = "offensive", cooldown = 90  },
            [18499]  = { name = "Rage de berserker",          type = "defensive", cooldown = 30  },
        },
        [72] = { -- Fury
            [1719]   = { name = "Témérité",                   type = "offensive", cooldown = 90  },
            [18499]  = { name = "Rage de berserker",          type = "defensive", cooldown = 30  },
            [184364] = { name = "Régénération enragée",       type = "defensive", cooldown = 120 },
        },
    },

    -- ═══════════════════════════════════════════════════════════
    PALADIN = {
        common = {
            [642]    = { name = "Bouclier divin",                        type = "defensive", cooldown = 300 },
            [1022]   = { name = "Bénédiction de protection",             type = "defensive", cooldown = 300 },
            [204018] = { name = "Bénédiction de protection des sorts",   type = "defensive", cooldown = 300 },
            [31884]  = { name = "Courroux vengeur",                      type = "offensive", cooldown = 60  },
        },
        [66] = { -- Protection
            [31850]  = { name = "Ardent défenseur",           type = "defensive", cooldown = 60  },
            [86659]  = { name = "Gardien des anciens rois",   type = "defensive", cooldown = 180 },
        },
        [65] = { -- Holy
            [403876] = { name = "Protection divine",          type = "defensive", cooldown = 60  },
            [31821]  = { name = "Maîtrise des auras",         type = "defensive", cooldown = 180 },
        },
        [70] = { -- Retribution
            [403876] = { name = "Protection divine",          type = "defensive", cooldown = 60  },
        },
    },

    -- ═══════════════════════════════════════════════════════════
    HUNTER = {
        common = {
            [186265] = { name = "Aspect de la tortue",        type = "defensive", cooldown = 180 },
            [109248] = { name = "Détermination du lynx",      type = "defensive", cooldown = 180 },
            [264735] = { name = "Survie du plus fort",        type = "defensive", cooldown = 90, charges = 2 },
            [5384]   = { name = "Feindre la mort",            type = "defensive", cooldown = 30  },
        },
        [253] = { -- Beast Mastery
            [19574]  = { name = "Courroux bestial",           type = "offensive", cooldown = 30  },
        },
        [254] = { -- Marksmanship
            [288613] = { name = "Précision",                  type = "offensive", cooldown = 90  },
        },
        [255] = { -- Survival
            [1250646]= { name = "Plaquage au sol",            type = "offensive", cooldown = 60  },
        },
    },

    -- ═══════════════════════════════════════════════════════════
    ROGUE = {
        common = {
            [31224]  = { name = "Manteau des ombres",         type = "defensive", cooldown = 120 },
            [5277]   = { name = "Évasion",                    type = "defensive", cooldown = 180 },
            [1966]   = { name = "Feinte",                     type = "defensive", cooldown = 15, charges = 2 },
        },
        [259] = { -- Assassination
            [13750]  = { name = "Adrénaline",                 type = "offensive", cooldown = 120 },
        },
        [260] = { -- Outlaw
            [13750]  = { name = "Adrénaline",                 type = "offensive", cooldown = 120 },
            [121471] = { name = "Pied de biche",              type = "offensive", cooldown = 120 },
        },
        [261] = { -- Subtlety
            [185313] = { name = "Danse des lames d'ombre",    type = "offensive", cooldown = 60  },
        },
    },

    -- ═══════════════════════════════════════════════════════════
    MAGE = {
        common = {
            [342246] = { name = "Altérer le temps",           type = "defensive", cooldown = 50  },
            [414658] = { name = "Un froid glacial",           type = "defensive", cooldown = 150 },
            [45438]  = { name = "Bloc de glace",              type = "defensive", cooldown = 180 },
            [110960] = { name = "Invisibilité supérieure",    type = "defensive", cooldown = 60  },
            [55342]  = { name = "Image miroir",               type = "defensive", cooldown = 120 },
        },
        [62] = { -- Arcane
            [365362] = { name = "Éruption d'arcanes",         type = "offensive", cooldown = 90  },
            [235450] = { name = "Barrière prismatique",       type = "defensive", cooldown = 30  },
        },
        [63] = { -- Fire
            [190319] = { name = "Combustion",                 type = "offensive", cooldown = 60  },
            [235313] = { name = "Barrière flamboyante",       type = "defensive", cooldown = 30  },
        },
        [64] = { -- Frost
            [11426]  = { name = "Barrière de glace",          type = "defensive", cooldown = 30, charges = 2 },
        },
    },

    -- ═══════════════════════════════════════════════════════════
    WARLOCK = {
        common = {
            [104773] = { name = "Barrière de feu démoniaque", type = "defensive", cooldown = 180 },
            [108416] = { name = "Pacte sombre",               type = "defensive", cooldown = 120 },
        },
        [265] = { -- Affliction
            [113860] = { name = "Moisson des âmes",           type = "offensive", cooldown = 120 },
        },
        [266] = { -- Demonology
            [152108] = { name = "Chaos déchaîné",             type = "offensive", cooldown = 90  },
        },
        [267] = { -- Destruction
            [1122]   = { name = "Invoquer l'infernal",        type = "offensive", cooldown = 180 },
        },
    },

    -- ═══════════════════════════════════════════════════════════
    PRIEST = {
        common = {
            [586]    = { name = "Sauvegarde des anges",       type = "defensive", cooldown = 90  },
        },
        [256] = { -- Discipline
            [10060]  = { name = "Infusion de puissance",      type = "offensive", cooldown = 120 },
            [33206]  = { name = "Bouclier de douleur",        type = "defensive", cooldown = 120 },
            [19236]  = { name = "Barrière lumineuse",         type = "defensive", cooldown = 180 },
        },
        [257] = { -- Holy
            [10060]  = { name = "Infusion de puissance",      type = "offensive", cooldown = 120 },
        },
        [258] = { -- Shadow
            [228260] = { name = "Voidform",                   type = "offensive", cooldown = 90  },
            [47585]  = { name = "Dispersion",                 type = "defensive", cooldown = 120 },
        },
    },

    -- ═══════════════════════════════════════════════════════════
    SHAMAN = {
        common = {
            [108271] = { name = "Totem anti-magie",           type = "defensive", cooldown = 120 },
        },
        [264] = { -- Restoration
            [114050] = { name = "Ascendance",                 type = "offensive", cooldown = 180 },
            [207399] = { name = "Esprit ancestral",           type = "defensive", cooldown = 180 },
            [20608]  = { name = "Résurrection ancestrale",    type = "defensive", cooldown = 600 },
        },
        [262] = { -- Elemental
            [198067] = { name = "Esprit du feu élémentaire",  type = "offensive", cooldown = 150 },
            [114050] = { name = "Ascendance",                 type = "offensive", cooldown = 180 },
        },
        [263] = { -- Enhancement
            [2825]   = { name = "Soif de sang",               type = "offensive", cooldown = 120 },
            [114050] = { name = "Ascendance",                 type = "offensive", cooldown = 180 },
        },
    },

    -- ═══════════════════════════════════════════════════════════
    DRUID = {
        common = {},
        [104] = { -- Guardian
            [102558] = { name = "Incarnation : Gardien d'Ursoc",      type = "offensive", cooldown = 180 },
            [22812]  = { name = "Écorce",                             type = "defensive", cooldown = 34  },
            [61336]  = { name = "Instincts de survie",                type = "defensive", cooldown = 120, charges = 2 },
            [22842]  = { name = "Régénération frénétique",            type = "defensive", cooldown = 23  },
        },
        [105] = { -- Restoration
            [391528] = { name = "Convoquer les esprits",              type = "offensive", cooldown = 60  },
            [22812]  = { name = "Écorce",                             type = "defensive", cooldown = 60  },
        },
        [102] = { -- Balance
            [102560] = { name = "Incarnation : Appelé d'Élune",       type = "offensive", cooldown = 120, charges = 2 },
            [22812]  = { name = "Écorce",                             type = "defensive", cooldown = 60  },
        },
        [103] = { -- Feral
            [102543] = { name = "Incarnation : avatar d'Ashamane",    type = "offensive", cooldown = 120 },
            [22812]  = { name = "Écorce",                             type = "defensive", cooldown = 60  },
            [61336]  = { name = "Instincts de survie",                type = "defensive", cooldown = 180 },
        },
    },

    -- ═══════════════════════════════════════════════════════════
    MONK = {
        common = {},
        [268] = { -- Brewmaster
            [115203] = { name = "Brassée fortifiante",        type = "defensive", cooldown = 120 },
        },
        [270] = { -- Mistweaver
            [116849] = { name = "Cocon de vie",               type = "defensive", cooldown = 120 },
            [122278] = { name = "Damoiselle de jade",         type = "defensive", cooldown = 90  },
            [101643] = { name = "Diffusion de brume",         type = "defensive", cooldown = 180 },
        },
        [269] = { -- Windwalker
            [137639] = { name = "Tempête, Terre et Feu",      type = "offensive", cooldown = 90  },
            [152173] = { name = "Sérénité",                   type = "offensive", cooldown = 90  },
        },
    },

    -- ═══════════════════════════════════════════════════════════
    DEATHKNIGHT = {
        common = {
            [48707]  = { name = "Bouclier anti-magie",        type = "defensive", cooldown = 45  },
            [55233]  = { name = "Volonté du nécrophage",      type = "defensive", cooldown = 180 },
        },
        [250] = { -- Blood
            [196770] = { name = "Forteresse d'os",            type = "defensive", cooldown = 180 },
        },
        [251] = { -- Frost
            [51271]  = { name = "Pilastres de givre",         type = "offensive", cooldown = 120 },
            [48792]  = { name = "Infaillibilité glaciale",    type = "defensive", cooldown = 180 },
        },
        [252] = { -- Unholy
            [42650]  = { name = "Armée des morts",            type = "offensive", cooldown = 480 },
            [275699] = { name = "Apocalypse",                 type = "offensive", cooldown = 90  },
        },
    },

    -- ═══════════════════════════════════════════════════════════
    DEMONHUNTER = {
        common = {
            [196555] = { name = "Voile d'ombre",              type = "defensive", cooldown = 60  },
            [209426] = { name = "Absorption d'âme",           type = "defensive", cooldown = 30  },
        },
        [581] = { -- Vengeance
            [187827] = { name = "Métamorphose (Vengeance)",   type = "defensive", cooldown = 180 },
        },
        [577] = { -- Havoc
            [162264] = { name = "Métamorphose",               type = "offensive", cooldown = 180 },
            [258920] = { name = "Éruption du vide",           type = "offensive", cooldown = 120 },
            [206491] = { name = "Némésis",                    type = "offensive", cooldown = 120 },
        },
    },

    -- ═══════════════════════════════════════════════════════════
    EVOKER = {
        common = {
            [363916] = { name = "Aile nacrée",                type = "defensive", cooldown = 180 },
        },
        [1468] = { -- Preservation
            [374348] = { name = "Renforcement temporel",      type = "defensive", cooldown = 180 },
        },
        [1467] = { -- Devastation
            [375087] = { name = "Présence draconique",        type = "offensive", cooldown = 120 },
            [370960] = { name = "Transe du souffle",          type = "defensive", cooldown = 120 },
        },
        [1473] = { -- Augmentation
            [403631] = { name = "Instinct poudre de rêve",    type = "offensive", cooldown = 120 },
        },
    },
}

-- ═══════════════════════════════════════════════════════════════
-- META-DONNÉES
-- ═══════════════════════════════════════════════════════════════

CT.ClassColors = {
    WARRIOR     = {0.78, 0.61, 0.43},
    PALADIN     = {0.96, 0.55, 0.73},
    HUNTER      = {0.67, 0.83, 0.45},
    ROGUE       = {1.00, 0.96, 0.41},
    PRIEST      = {1.00, 1.00, 1.00},
    SHAMAN      = {0.00, 0.44, 0.87},
    MAGE        = {0.41, 0.80, 0.94},
    WARLOCK     = {0.58, 0.51, 0.79},
    DRUID       = {1.00, 0.49, 0.04},
    MONK        = {0.00, 1.00, 0.59},
    DEATHKNIGHT = {0.77, 0.12, 0.23},
    DEMONHUNTER = {0.64, 0.19, 0.79},
    EVOKER      = {0.20, 0.58, 0.50},
}

CT.ClassOrder = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "MAGE", "WARLOCK",
    "PRIEST", "SHAMAN", "DRUID", "MONK", "DEATHKNIGHT", "DEMONHUNTER", "EVOKER",
}

CT.ClassLabels = {
    WARRIOR     = "Guerrier",
    PALADIN     = "Paladin",
    HUNTER      = "Chasseur",
    ROGUE       = "Voleur",
    MAGE        = "Mage",
    WARLOCK     = "Démoniste",
    PRIEST      = "Prêtre",
    SHAMAN      = "Chaman",
    DRUID       = "Druide",
    MONK        = "Moine",
    DEATHKNIGHT = "Chevalier de la mort",
    DEMONHUNTER = "Chasseur de démons",
    EVOKER      = "Évocateur",
}

CT.SpecLabels = {
    [71]   = "Armes",        [72]   = "Fureur",        [73]   = "Protection",
    [65]   = "Sacré",        [66]   = "Protection",     [70]   = "Rétribution",
    [253]  = "Bête",         [254]  = "Tir",            [255]  = "Survie",
    [259]  = "Assassinat",   [260]  = "Hors-la-loi",    [261]  = "Subtilité",
    [256]  = "Discipline",   [257]  = "Sacré",          [258]  = "Ombre",
    [262]  = "Élémentaire",  [263]  = "Amélioration",   [264]  = "Restauration",
    [62]   = "Arcanes",      [63]   = "Feu",            [64]   = "Givre",
    [265]  = "Affliction",   [266]  = "Démonologie",    [267]  = "Destruction",
    [102]  = "Équilibre",    [103]  = "Féral",          [104]  = "Gardien",    [105] = "Restauration",
    [268]  = "Maître brass.",[269]  = "Tissevent",      [270]  = "Brume",
    [250]  = "Sang",         [251]  = "Givre",          [252]  = "Impie",
    [577]  = "Dévastation",  [581]  = "Vengeance",
    [1467] = "Dévastation",  [1468] = "Préservation",   [1473] = "Augmentation",
}

CT.SpecRoles = {
    [71]   = "DAMAGER", [72]   = "DAMAGER", [73]   = "TANK",
    [65]   = "HEALER",  [66]   = "TANK",    [70]   = "DAMAGER",
    [253]  = "DAMAGER", [254]  = "DAMAGER", [255]  = "DAMAGER",
    [259]  = "DAMAGER", [260]  = "DAMAGER", [261]  = "DAMAGER",
    [256]  = "HEALER",  [257]  = "HEALER",  [258]  = "DAMAGER",
    [262]  = "DAMAGER", [263]  = "DAMAGER", [264]  = "HEALER",
    [62]   = "DAMAGER", [63]   = "DAMAGER", [64]   = "DAMAGER",
    [265]  = "DAMAGER", [266]  = "DAMAGER", [267]  = "DAMAGER",
    [102]  = "DAMAGER", [103]  = "DAMAGER", [104]  = "TANK",    [105] = "HEALER",
    [268]  = "TANK",    [269]  = "DAMAGER", [270]  = "HEALER",
    [250]  = "TANK",    [251]  = "DAMAGER", [252]  = "DAMAGER",
    [577]  = "DAMAGER", [581]  = "TANK",
    [1467] = "DAMAGER", [1468] = "HEALER",  [1473] = "DAMAGER",
}

-- Coordonnées UV validées en jeu
CT.RoleTexCoords = {
    TANK    = {0.00,  0.26,  0.255, 0.505},
    HEALER  = {0.27,  0.52,  0.01,  0.25},
    DAMAGER = {0.27,  0.52,  0.27,  0.51},
}
