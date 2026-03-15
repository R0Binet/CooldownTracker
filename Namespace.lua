-- Namespace.lua
-- Crée la table partagée transmise à tous les fichiers via (...)
-- C'est le premier fichier chargé par WoW.

local _, CT = ...
CT.db = nil  -- sera initialisé dans Core.lua (ADDON_LOADED)
