# CHUG: Shadow of Fame — Godot Engine 4 Rebuild

A cinematic fighting RPG rebuilt from the ground up in **Godot Engine 4**.

---

## 📚 Complete Technical Documentation (18,800+ Lines)

The complete game systems, narrative script, combat frame data, and engine blueprints are fully documented in the `docs/` folder:

1. **[`01_STORY_AND_CAMPAIGN_SCRIPT.md`](docs/01_STORY_AND_CAMPAIGN_SCRIPT.md)** (6,446 lines)
   - Full 50-part verbatim dialogue script, stage directions, speaker profiles, combat triggers, glitch cues, and world progression across 3 Worlds, 5 Acts, and 10 Chapters.

2. **[`02_COMBAT_ENGINE_AND_MOVESETS.md`](docs/02_COMBAT_ENGINE_AND_MOVESETS.md)** (3,101 lines)
   - Frame-accurate moveset tables for all 15 weapon styles (Fists, Daggers, Sais, Batons, Nunchaku, Kamas, Katana, Staff, Scythe, Hammer, Claws, Spear, Composite Sword, Blood Reaper, AK-47).
   - Physics equations, hitboxes, damage formulas, combo scaling, 3-tier Rage system, and 25+ enemy AI decision trees.

3. **[`03_RPG_SYSTEMS_ECONOMY_AND_PROGRESSION.md`](docs/03_RPG_SYSTEMS_ECONOMY_AND_PROGRESSION.md)** (3,105 lines)
   - Complete 50-level XP progression table, stat point allocation formulas (HP, ATK, DEF, SPD, CRIT), currency economy, gear star upgrades, and master armory item catalog.

4. **[`04_ROSTER_SQUAD_AND_CAMP_SYSTEMS.md`](docs/04_ROSTER_SQUAD_AND_CAMP_SYSTEMS.md)** (3,102 lines)
   - Character dossiers (Chug, Yassine, Tora, Raevan, Sorya, Harjeev, Solo, Knight, M.R, Addy, Drakos, Nexters), tactical squad synergy buffs, Ash Camp hub, and training chamber skill paths.

5. **[`05_GODOT_ARCHITECTURE_AND_IMPLEMENTATION_PLAN.md`](docs/05_GODOT_ARCHITECTURE_AND_IMPLEMENTATION_PLAN.md)** (3,109 lines)
   - Complete Godot 4 engineering blueprint: Autoload singletons (`GameData.gd`, `SaveStore.gd`, `GameSession.gd`, `AudioManager.gd`), scene tree hierarchies, shaders, virtual controls, and development roadmap.

---

## 🚀 Getting Started

1. Open **Godot Engine 4.3+** or **4.4+**.
2. Click **Import** and select `project.godot`.
3. Run the project (`F5`) to start from `res://scenes/Main.tscn`.
