# CooldownTracker

Addon World of Warcraft pour **Midnight 12.0** (Interface 120001) qui affiche les cooldowns offensifs et defensifs des membres de votre groupe directement sur les party frames Blizzard.

---

## Fonctionnalites

- **Detection automatique** via les filtres Blizzard natifs (`BIG_DEFENSIVE`, `EXTERNAL_DEFENSIVE`, `IMPORTANT`)
- **Icones persistantes** — les CDs detectes restent visibles meme apres expiration du buff
- **Glow anime** (LibCustomGlow) quand un buff est actif
- **Roue de cooldown** et **timer natif** sur les icones
- **Separation Offensif / Defensif** avec ancrage independant sur les party frames
- **Compatible secret values** — fonctionne malgre le systeme de securite Midnight 12.0

---

## Installation

1. Telechargez le dossier `CooldownTracker`
2. Placez-le dans :
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
3. Relancez WoW ou tapez `/reload`

---

## Comment ca fonctionne

CooldownTracker utilise les **filtres natifs de Blizzard** pour detecter les buffs offensifs et defensifs importants sur les membres du groupe. Quand un coequipier active un CD :

1. L'icone apparait avec une **bordure coloree** et un **glow anime**
2. La **roue de cooldown** s'anime pendant la duree du buff
3. Quand le buff expire, l'icone passe en mode **disponible** (attenuee, sans glow)
4. Quand le buff est reactive, l'icone se rallume

Pour **vos propres sorts**, l'addon identifie le nom via `UNIT_SPELLCAST_SUCCEEDED` et peut afficher un timer de CD precis. Pour les **sorts des coequipiers**, les valeurs sont masquees par Midnight 12.0 — l'icone est correcte mais le nom et le timer ne sont pas disponibles.

---

## Configuration

Ouvrez les options via **Echap > Options > Add-ons > CooldownTracker** ou tapez `/cdt`

### Structure des options

```
CooldownTracker
├── CD Offensif      (activer, glow, position)
├── CD Defensif      (activer, glow, position)
├── Sorts            (liste par classe/spe, checkboxes)
└── Informations     (aide et limitations)
```

### Options principales

| Option | Description |
|---|---|
| **Informations CD** | Timer, roue de cooldown, tooltip |
| **Garder les icones** | Les icones restent apres expiration (mode persistant) |
| **Messages chat** | Annonce les CDs detectes dans le chat |
| **Ignorer mes CDs** | Ne pas tracker le joueur local |

### CD Offensif / Defensif

Chaque type a sa propre page : activer/desactiver, glow, ancrage (gauche/droite/haut/bas), offsets X/Y.

---

## Commandes slash

```
/cdt            Aide
/cdt off        Toggle CDs offensifs
/cdt def        Toggle CDs defensifs
/cdt chat       Toggle messages chat
/cdt debug      Toggle logs debug (chat)
/cdt log        Toggle logs fichier (SavedVariable)
/cdt clear      Effacer les CDs affiches
/cdt status     Config actuelle
/cdt identify   Afficher le cache spellcast
/cdt frames     Debug des frames
```

---

## Limitations (Midnight 12.0)

Le systeme de **secret values** de Midnight 12.0 impose des restrictions :

| Limitation | Detail |
|---|---|
| **Identification** | Les sorts des autres joueurs affichent l'icone correcte mais ne peuvent pas etre nommes |
| **Timer CD** | Le cooldown precis n'est disponible que pour vos propres sorts |
| **Comparaison** | Impossible de comparer deux icones pour determiner si c'est le meme sort |
| **CLEU** | `COMBAT_LOG_EVENT_UNFILTERED` est protege — les addons ne peuvent pas s'y enregistrer |

---

## Dependances incluses

- [LibStub](https://www.curseforge.com/wow/addons/libstub)
- [LibCustomGlow-1.0](https://www.curseforge.com/wow/addons/libcustomglow)

---

## Compatibilite

| Version WoW | Support |
|---|---|
| Midnight 12.0 (Interface 120001) | Supporte |

---

## Licence

Ce projet est distribue librement. Vous etes libre de l'utiliser, modifier et redistribuer.
