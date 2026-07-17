class_name GameConfig
extends RefCounted

## Configuración central del juego. Cambiar una carta o el tamaño del tablero se hace aquí.

const DEFENDER_SCENES: Dictionary = {
	"farolero": preload("res://Scenes/Defenders/Farolero.tscn"),
	"pistolero": preload("res://Scenes/Defenders/Pistolero.tscn"),
	"granjero": preload("res://Scenes/Defenders/Granjero.tscn"),
	"escopetero": preload("res://Scenes/Defenders/Escopetero.tscn"),
	"fusilero": preload("res://Scenes/Defenders/Fusilero.tscn"),
	"rastreador": preload("res://Scenes/Defenders/Rastreador.tscn")
}

const DEFENDER_ORDER: Array[String] = ["farolero", "pistolero", "granjero", "escopetero", "fusilero", "rastreador"]

const DEFENDER_DATA: Dictionary = {
	"farolero": {"name": "Farolero", "cost": 30, "cooldown": 4.0, "icon": "res://Sprites/Imported/Frames/farolero/idle/00.png"},
	"pistolero": {"name": "Pistolero", "cost": 45, "cooldown": 3.5, "icon": "res://Sprites/Imported/Frames/pistolero/idle/00.png"},
	"granjero": {"name": "Granjero", "cost": 55, "cooldown": 5.0, "icon": "res://Sprites/Imported/Frames/granjero/idle/00.png"},
	"escopetero": {"name": "Escopetero", "cost": 65, "cooldown": 6.0, "icon": "res://Sprites/Imported/Frames/escopetero/idle/00.png"},
	"fusilero": {"name": "Fusilero", "cost": 70, "cooldown": 5.5, "icon": "res://Sprites/Imported/Frames/fusilero/idle/00.png"},
	"rastreador": {"name": "Rastreador", "cost": 85, "cooldown": 7.0, "icon": "res://Sprites/Imported/Frames/rastreador/idle/00.png"}
}

const LANE_Y: PackedFloat32Array = [312.0, 358.0, 405.0, 455.0, 510.0]
const GRID_X_START: float = 275.0
const GRID_COLUMN_SPACING: float = 108.0
const GRID_CELL_CLICK_WIDTH: float = 108.0
const GRID_CELL_CLICK_HEIGHT: float = 58.0
const GRID_COLUMNS: int = 6

const CHARACTER_SCALE: float = 0.68
const DEFENDER_GROUND_OFFSET_Y: float = -12.0
const STARTING_COURAGE: int = 120
const COURAGE_REGEN_AMOUNT: int = 4
const COURAGE_REGEN_INTERVAL: float = 2.0
const SURVIVAL_DURATION: float = 120.0
