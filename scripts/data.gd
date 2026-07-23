class_name Data
# ════════════════════════════════════════════════════════════════════════════
# Single source of truth for all game balance numbers.
# Change values here; no game-logic code needs touching.
# ════════════════════════════════════════════════════════════════════════════

# ── Factions ─────────────────────────────────────────────────────────────────
const FACTIONS : Dictionary = {
	"north": {
		"name":          "The North",
		"main_building": "great_hall",
		"worker":        "smallfolk",
		"starter_unit":  "levy_spearman",
	},
	"wildlings": {
		"name":          "Wildlings",
		"main_building": "great_tent",
		"worker":        "forager",
		"starter_unit":  "raider",
	},
	"targaryen": {
		"name":          "Targaryens",
		"main_building": "manse",
		"worker":        "steward",
		"starter_unit":  "queensguard",
	},
}

# ── Units ─────────────────────────────────────────────────────────────────────
# Keys per entry:
#   name, faction, is_worker, hp, speed,
#   damage, attack_range, attack_interval,
#   gold_cost, train_time, supply_cost,
#   gather_amount (gold/trip; workers only),
#   gather_time   (seconds/trip; workers only),
#   visual_scale  (capsule size multiplier — 1.0 = standard soldier)
#   color
const UNITS : Dictionary = {

	# ── The North ─────────────────────────────────────────────────────────────
	"smallfolk": {
		"name": "Smallfolk",     "faction": "north",    "is_worker": true,
		"hp": 50,  "speed": 8.0,
		"damage": 4,  "attack_range": 1.5, "attack_interval": 1.5,
		"gold_cost": 50,  "train_time": 8.0,  "supply_cost": 1,
		"gather_amount": 15, "gather_time": 2.5,
		"visual_scale": 0.85,
		"color": Color(0.80, 0.65, 0.40),
	},
	"levy_spearman": {
		"name": "Levy Spearman", "faction": "north",    "is_worker": false,
		"hp": 80,  "speed": 5.5,
		"damage": 12, "attack_range": 1.8, "attack_interval": 1.4,
		"gold_cost": 60,  "train_time": 12.0, "supply_cost": 1,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 1.0,
		"color": Color(0.40, 0.55, 0.80),
	},
	"crossbowman": {
		"name": "Crossbowman",   "faction": "north",    "is_worker": false,
		"hp": 60,  "speed": 5.0,
		"damage": 18, "attack_range": 8.0, "attack_interval": 2.0,
		"gold_cost": 80,  "train_time": 15.0, "supply_cost": 1,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 0.95,
		"color": Color(0.30, 0.45, 0.70),
	},
	"northern_cavalry": {
		"name": "Northern Cavalry", "faction": "north", "is_worker": false,
		"hp": 100, "speed": 10.0,
		"damage": 15, "attack_range": 1.8, "attack_interval": 1.2,
		"gold_cost": 100, "train_time": 20.0, "supply_cost": 2,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 1.15,
		"color": Color(0.25, 0.40, 0.65),
	},
	"ironwood_pikeman": {
		"name": "Ironwood Pikeman", "faction": "north", "is_worker": false,
		"hp": 130, "speed": 4.0,
		"damage": 10, "attack_range": 2.2, "attack_interval": 1.8,
		"gold_cost": 90,  "train_time": 18.0, "supply_cost": 1,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 1.1,
		"color": Color(0.35, 0.50, 0.75),
	},
	"trebuchet": {
		"name": "Trebuchet",     "faction": "north",    "is_worker": false,
		"hp": 80,  "speed": 3.0,
		"damage": 50, "attack_range": 12.0, "attack_interval": 5.0,
		"gold_cost": 150, "train_time": 35.0, "supply_cost": 3,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 1.3,
		"color": Color(0.50, 0.55, 0.65),
	},
	"banner_knight": {
		"name": "Banner Knight", "faction": "north",    "is_worker": false,
		"hp": 150, "speed": 6.0,
		"damage": 22, "attack_range": 1.8, "attack_interval": 1.3,
		"gold_cost": 130, "train_time": 28.0, "supply_cost": 2,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 1.2,
		"color": Color(0.20, 0.35, 0.60),
	},

	# ── Wildlings ─────────────────────────────────────────────────────────────
	"forager": {
		"name": "Forager",       "faction": "wildlings", "is_worker": true,
		"hp": 40,  "speed": 9.0,
		"damage": 4,  "attack_range": 1.5, "attack_interval": 1.5,
		"gold_cost": 30,  "train_time": 6.0,  "supply_cost": 1,
		"gather_amount": 15, "gather_time": 2.5,
		"visual_scale": 0.82,
		"color": Color(0.72, 0.52, 0.30),
	},
	"raider": {
		"name": "Raider",        "faction": "wildlings", "is_worker": false,
		"hp": 60,  "speed": 7.0,
		"damage": 10, "attack_range": 1.5, "attack_interval": 1.2,
		"gold_cost": 40,  "train_time": 8.0,  "supply_cost": 1,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 0.9,
		"color": Color(0.65, 0.30, 0.15),
	},
	"skinchanger_scout": {
		"name": "Skinchanger Scout", "faction": "wildlings", "is_worker": false,
		"hp": 40,  "speed": 12.0,
		"damage": 6,  "attack_range": 1.5, "attack_interval": 1.0,
		"gold_cost": 35,  "train_time": 6.0,  "supply_cost": 1,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 0.8,
		"color": Color(0.55, 0.38, 0.22),
	},
	"thenn_skirmisher": {
		"name": "Thenn Skirmisher", "faction": "wildlings", "is_worker": false,
		"hp": 50,  "speed": 6.0,
		"damage": 14, "attack_range": 6.0, "attack_interval": 1.8,
		"gold_cost": 50,  "train_time": 10.0, "supply_cost": 1,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 0.92,
		"color": Color(0.60, 0.35, 0.18),
	},
	"giant": {
		"name": "Giant",         "faction": "wildlings", "is_worker": false,
		"hp": 350, "speed": 4.0,
		"damage": 40, "attack_range": 2.2, "attack_interval": 2.5,
		"gold_cost": 200, "train_time": 40.0, "supply_cost": 4,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 1.9,
		"color": Color(0.45, 0.28, 0.18),
	},
	"war_mammoth": {
		"name": "War Mammoth",   "faction": "wildlings", "is_worker": false,
		"hp": 500, "speed": 3.0,
		"damage": 30, "attack_range": 2.5, "attack_interval": 2.8,
		"gold_cost": 250, "train_time": 50.0, "supply_cost": 5,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 2.4,
		"color": Color(0.40, 0.30, 0.22),
	},
	"horde_rider": {
		"name": "Horde Rider",   "faction": "wildlings", "is_worker": false,
		"hp": 80,  "speed": 11.0,
		"damage": 12, "attack_range": 1.8, "attack_interval": 1.3,
		"gold_cost": 80,  "train_time": 16.0, "supply_cost": 2,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 1.15,
		"color": Color(0.60, 0.38, 0.20),
	},

	# ── Targaryens ────────────────────────────────────────────────────────────
	"steward": {
		"name": "Steward",       "faction": "targaryen", "is_worker": true,
		"hp": 55,  "speed": 7.0,
		"damage": 4,  "attack_range": 1.5, "attack_interval": 1.5,
		"gold_cost": 70,  "train_time": 10.0, "supply_cost": 1,
		"gather_amount": 20, "gather_time": 2.5,   # higher per-trip yield
		"visual_scale": 0.88,
		"color": Color(0.85, 0.60, 0.60),
	},
	"queensguard": {
		"name": "Queensguard",   "faction": "targaryen", "is_worker": false,
		"hp": 200, "speed": 5.0,
		"damage": 30, "attack_range": 1.8, "attack_interval": 1.4,
		"gold_cost": 150, "train_time": 30.0, "supply_cost": 2,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 1.25,
		"color": Color(0.75, 0.20, 0.20),
	},
	"fire_lancer": {
		"name": "Fire Lancer",   "faction": "targaryen", "is_worker": false,
		"hp": 80,  "speed": 6.0,
		"damage": 35, "attack_range": 7.0, "attack_interval": 2.2,
		"gold_cost": 120, "train_time": 25.0, "supply_cost": 2,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 1.0,
		"color": Color(0.90, 0.30, 0.10),
	},
	"outrider": {
		"name": "Outrider",      "faction": "targaryen", "is_worker": false,
		"hp": 120, "speed": 11.0,
		"damage": 20, "attack_range": 1.8, "attack_interval": 1.3,
		"gold_cost": 140, "train_time": 28.0, "supply_cost": 2,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 1.15,
		"color": Color(0.85, 0.25, 0.15),
	},
	"siege_scorpion": {
		"name": "Siege Scorpion", "faction": "targaryen", "is_worker": false,
		"hp": 100, "speed": 4.0,
		"damage": 60, "attack_range": 10.0, "attack_interval": 4.0,
		"gold_cost": 180, "train_time": 38.0, "supply_cost": 3,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 1.3,
		"color": Color(0.70, 0.18, 0.18),
	},
	"dragon": {
		"name": "Dragon",        "faction": "targaryen", "is_worker": false,
		"hp": 800, "speed": 8.0,
		"damage": 80, "attack_range": 5.0, "attack_interval": 3.0,
		"gold_cost": 400, "train_time": 60.0, "supply_cost": 8,
		"gather_amount": 0,  "gather_time": 0.0,
		"visual_scale": 2.8,
		"color": Color(0.60, 0.10, 0.10),
	},
}

# ── Buildings ─────────────────────────────────────────────────────────────────
# Keys per entry:
#   name, faction, hp, gold_cost, build_time,
#   supply_provided, size (world units, square footprint),
#   color, trains[] (unit IDs this building can queue)
const BUILDINGS : Dictionary = {

	# ── The North ─────────────────────────────────────────────────────────────
	"great_hall": {
		"name": "Great Hall",  "faction": "north",
		"hp": 800,  "gold_cost": 0,   "build_time": 0.0,
		"supply_provided": 10, "size": 5.0,
		"color": Color(0.50, 0.46, 0.42),
		"trains": ["smallfolk"],
	},
	"barracks_north": {
		"name": "Barracks",    "faction": "north",
		"hp": 500,  "gold_cost": 150, "build_time": 30.0,
		"supply_provided": 0,  "size": 4.0,
		"color": Color(0.42, 0.38, 0.35),
		"trains": ["levy_spearman", "crossbowman", "ironwood_pikeman", "banner_knight"],
	},
	"smithy": {
		"name": "Smithy",      "faction": "north",
		"hp": 400,  "gold_cost": 100, "build_time": 25.0,
		"supply_provided": 0,  "size": 3.0,
		"color": Color(0.35, 0.30, 0.28),
		"trains": [],   # upgrades — Phase 9
	},
	"siege_yard": {
		"name": "Siege Yard",  "faction": "north",
		"hp": 400,  "gold_cost": 200, "build_time": 40.0,
		"supply_provided": 0,  "size": 5.0,
		"color": Color(0.40, 0.36, 0.32),
		"trains": ["trebuchet", "northern_cavalry"],
	},

	# ── Wildlings ─────────────────────────────────────────────────────────────
	"great_tent": {
		"name": "Great Tent",  "faction": "wildlings",
		"hp": 500,  "gold_cost": 0,   "build_time": 0.0,
		"supply_provided": 10, "size": 4.0,
		"color": Color(0.55, 0.42, 0.28),
		"trains": ["forager"],
	},
	"war_camp": {
		"name": "War Camp",    "faction": "wildlings",
		"hp": 300,  "gold_cost": 80,  "build_time": 15.0,
		"supply_provided": 0,  "size": 4.0,
		"color": Color(0.50, 0.35, 0.20),
		"trains": ["raider", "skinchanger_scout", "thenn_skirmisher",
		           "horde_rider", "giant", "war_mammoth"],
	},

	# ── Targaryens ────────────────────────────────────────────────────────────
	"manse": {
		"name": "Manse",       "faction": "targaryen",
		"hp": 700,  "gold_cost": 0,   "build_time": 0.0,
		"supply_provided": 10, "size": 5.0,
		"color": Color(0.60, 0.45, 0.40),
		"trains": ["steward"],
	},
	"armory": {
		"name": "Armory",      "faction": "targaryen",
		"hp": 500,  "gold_cost": 180, "build_time": 35.0,
		"supply_provided": 0,  "size": 4.0,
		"color": Color(0.50, 0.30, 0.28),
		"trains": ["queensguard", "fire_lancer", "outrider", "siege_scorpion"],
	},
	"dragonpit": {
		"name": "Dragonpit",   "faction": "targaryen",
		"hp": 600,  "gold_cost": 350, "build_time": 60.0,
		"supply_provided": 0,  "size": 6.0,
		"color": Color(0.45, 0.22, 0.20),
		"trains": ["dragon"],
	},
}
