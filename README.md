# CooldownTracker

**CooldownTracker** est un addon World of Warcraft (Midnight 12.0) qui affiche les cooldowns offensifs et défensifs des membres de votre groupe directement sur les party frames.

---

## Aperçu

> 📸 *[Screenshot : vue en jeu avec les icônes de CDs affichées sur les party frames, montrant à la fois les offensifs à gauche et les défensifs à droite]*

---

## Fonctionnalités

- **Détection automatique** des cooldowns via les buffs actifs (`UNIT_AURA`)
- **Icônes permanentes** ou affichage uniquement pendant le buff actif
- **Séparation Offensif / Défensif** avec ancrage indépendant sur les party frames
- **Glow animé** (ProcGlow) sur les icônes quand un buff est actif
- **Roue de cooldown** et **timer natif** WoW sur chaque icône
- **Gestion des charges** — badge numéroté sur les sorts à plusieurs charges
- **Filtrage par spécialisation** — affiche uniquement les sorts de la spé détectée
- **Support de toutes les classes** — 13 classes, sorts communs et par spécialisation

---

## Installation

1. Téléchargez le fichier `.zip`
2. Extrayez le dossier `CooldownTracker` dans :
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
3. Relancez WoW ou tapez `/reload`

---

## Configuration

Ouvrez les options via **Échap → Options → Add-ons → CooldownTracker**

### Structure des options

```
CooldownTracker
├── CD Offensif
├── CD Défensif
├── Sorts
└── Informations
```

---

### Page principale

> 📸 *[Screenshot : page principale des options avec les sections Options, Mode d'affichage, Disposition, Icône]*

| Section | Options disponibles |
|---|---|
| **Options** | Informations CD (timer, roue, tooltip), Messages chat, Ignorer ses propres CDs |
| **Mode d'affichage** | Toujours afficher toutes les icônes |
| **Disposition** | Nombre de lignes, Icônes par ligne |
| **Icône** | Taille (px), Espacement (px) |

---

### CD Offensif & CD Défensif

> 📸 *[Screenshot : page "CD Offensif" avec les sections Options et Position]*

Chaque type de CD possède sa propre page de configuration :

| Section | Options disponibles |
|---|---|
| **Options** | Activer, Glow quand buff actif |
| **Position** | Ancrage (Gauche/Droite/Haut/Bas), Offset X, Offset Y |

---

### Sorts trackés

> 📸 *[Screenshot : page "Sorts" montrant la liste des sorts organisée par classe avec les headers colorés et les sections par spécialisation]*

La liste des sorts est organisée par **classe** puis par **spécialisation** :
- Header de classe coloré avec compteur et bouton **Tout** (cocher/décocher)
- Header de spé avec icône de rôle (🛡 Tank / ✚ Heal / ⚔ DPS)
- Chaque sort affiche : icône, badge OFF/DEF, nom, cooldown, checkbox

---

## Informations & Limitations

### Comment fonctionne la détection ?

CooldownTracker surveille les buffs actifs via l'API `UNIT_AURA`. Un sort n'est détecté que s'il génère un **buff visible** sur l'unité.

### Limitations importantes

| Limitation | Détail |
|---|---|
| **Talents** | Impossible de savoir quels talents un coéquipier a choisis. Les sorts affichés peuvent ne pas être dans son build. |
| **Charges** | La gestion des charges ne fonctionne que pour **votre propre personnage**. |
| **Spécialisation** | Récupérée via inspection. Si hors de portée, tous les sorts de la classe sont affichés. |

---

## Commandes slash

```
/ct        Affiche l'aide
/reload    Recharge l'interface (après modification des options)
```

---

## Dépendances incluses

- [LibStub](https://www.curseforge.com/wow/addons/libstub)
- [LibCustomGlow-1.0](https://www.curseforge.com/wow/addons/libcustomglow)

---

## Compatibilité

| Version WoW | Support |
|---|---|
| Midnight 12.0 (Interface 120001) | ✅ Supporté |

---

## Licence

Ce projet est distribué librement. Vous êtes libre de l'utiliser, modifier et redistribuer.