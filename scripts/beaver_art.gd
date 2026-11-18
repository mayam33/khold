class_name BeaverArt
extends RefCounted

## Animation frames cropped from the character sheet supplied for Beaver Explorer.

const PORTRAIT: Texture2D = preload("res://assets/characters/beaver/portrait.png")
const IDLE := [
	preload("res://assets/characters/beaver/idle_0.png"),
	preload("res://assets/characters/beaver/idle_1.png"),
	preload("res://assets/characters/beaver/idle_2.png"),
	preload("res://assets/characters/beaver/idle_3.png"),
]
const WALK := [
	preload("res://assets/characters/beaver/walk_0.png"),
	preload("res://assets/characters/beaver/walk_1.png"),
	preload("res://assets/characters/beaver/walk_2.png"),
	preload("res://assets/characters/beaver/walk_3.png"),
]
const RUN := [
	preload("res://assets/characters/beaver/run_0.png"),
	preload("res://assets/characters/beaver/run_1.png"),
	preload("res://assets/characters/beaver/run_2.png"),
	preload("res://assets/characters/beaver/run_3.png"),
	preload("res://assets/characters/beaver/run_4.png"),
	preload("res://assets/characters/beaver/run_5.png"),
]
const DIG := [
	preload("res://assets/characters/beaver/dig_0.png"),
	preload("res://assets/characters/beaver/dig_1.png"),
	preload("res://assets/characters/beaver/dig_2.png"),
	preload("res://assets/characters/beaver/dig_3.png"),
]
const FALL := [
	preload("res://assets/characters/beaver/fall_0.png"),
	preload("res://assets/characters/beaver/fall_1.png"),
	preload("res://assets/characters/beaver/fall_2.png"),
	preload("res://assets/characters/beaver/fall_3.png"),
]
const HURT := [
	preload("res://assets/characters/beaver/hurt_0.png"),
	preload("res://assets/characters/beaver/hurt_1.png"),
	preload("res://assets/characters/beaver/hurt_2.png"),
]
const DIE := [
	preload("res://assets/characters/beaver/die_0.png"),
	preload("res://assets/characters/beaver/die_1.png"),
	preload("res://assets/characters/beaver/die_2.png"),
]
const CELEBRATE := [
	preload("res://assets/characters/beaver/celebrate_0.png"),
	preload("res://assets/characters/beaver/celebrate_1.png"),
	preload("res://assets/characters/beaver/celebrate_2.png"),
]

static func frames_for(animation: String) -> Array:
	match animation:
		"walk": return WALK
		"run": return RUN
		"dig": return DIG
		"fall": return FALL
		"hurt": return HURT
		"die": return DIE
		"celebrate": return CELEBRATE
		_: return IDLE

static func texture_for(animation: String, frame_index: int) -> Texture2D:
	var frames := frames_for(animation)
	return frames[posmod(frame_index, frames.size())] as Texture2D
