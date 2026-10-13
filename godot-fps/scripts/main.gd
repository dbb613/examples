extends Node3D
## Game flow: title screen, level loading, pause, level complete, death and
## victory. Levels are built from the ASCII maps in levels.gd.

const Levels = preload("res://scripts/levels.gd")
const LevelBuilder = preload("res://scripts/level_builder.gd")
const Player = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/hud.gd")

var hud: Hud
var level_root: Node3D
var player: CharacterBody3D
var level_index := 0
var level_time := 0.0
var playing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	hud = Hud.new()
	add_child(hud)
	Game.message.connect(hud.show_message)
	Game.kill_registered.connect(func(): hud.set_kills(Game.kills, Game.total_enemies))
	Game.exit_reached.connect(_on_exit_reached)
	show_title()


func show_title() -> void:
	_clear_level()
	_set_mouse_captured(false)
	hud.show_menu("BREACH",
		"WASD move  ·  Mouse aim  ·  Click fire  ·  R reload\n"
		+ "1 / 2 / 3 or wheel switch weapons  ·  Shift sprint  ·  Space jump  ·  Esc pause",
		[["New Game", func(): start_level(0)], ["Quit", func(): get_tree().quit()]])


func start_level(index: int) -> void:
	get_tree().paused = false
	_clear_level()
	level_index = index
	level_time = 0.0
	Game.reset_stats()

	var data: Dictionary = Levels.LEVELS[index]
	level_root = Node3D.new()
	level_root.name = "Level"
	level_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level_root)
	var info := LevelBuilder.build(data, level_root)
	Game.total_enemies = info.enemies

	player = Player.new()
	player.name = "Player"
	level_root.add_child(player)
	player.global_position = info.start_position
	player.rotation.y = info.start_yaw
	Game.player = player
	player.health_changed.connect(hud.set_health)
	player.ammo_changed.connect(hud.set_ammo)
	player.key_changed.connect(hud.set_key)
	player.damaged.connect(hud.flash_damage)
	player.hit_confirmed.connect(hud.show_hitmarker)
	player.died.connect(_on_player_died)
	hud.set_health(player.health, player.max_health)
	player._emit_ammo()
	hud.set_key(false)
	hud.set_kills(0, Game.total_enemies)
	hud.set_level("Level %d: %s" % [index + 1, data.name])

	hud.show_menu("Level %d: %s" % [index + 1, data.name], data.briefing,
		[["Start", _resume]])
	get_tree().paused = true
	playing = true


func _clear_level() -> void:
	playing = false
	Game.player = null
	if level_root:
		level_root.queue_free()
		level_root = null
	player = null


func _process(delta: float) -> void:
	if playing and not get_tree().paused:
		level_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			if hud.is_menu_visible() and not player.dead:
				_resume()
		elif not player.dead:
			_pause()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Clicking back into the window re-captures the mouse (e.g. after Cmd+Tab).
		_set_mouse_captured(true)


func _pause() -> void:
	get_tree().paused = true
	_set_mouse_captured(false)
	hud.show_menu("Paused", "", [
		["Resume", _resume],
		["Restart Level", func(): start_level(level_index)],
		["Quit to Title", show_title],
	])


func _resume() -> void:
	hud.hide_menu()
	get_tree().paused = false
	_set_mouse_captured(true)


func _on_exit_reached() -> void:
	get_tree().paused = true
	_set_mouse_captured(false)
	var stats := "Time  %s\nKills  %d / %d" % [_format_time(level_time), Game.kills, Game.total_enemies]
	if level_index + 1 < Levels.LEVELS.size():
		hud.show_menu("Level Complete", stats, [
			["Next Level", func(): start_level(level_index + 1)],
			["Replay Level", func(): start_level(level_index)],
		])
	else:
		hud.show_menu("Facility Cleared", stats + "\n\nYou made it out. Thanks for playing!", [
			["Play Again", func(): start_level(0)],
			["Title Screen", show_title],
		])


func _on_player_died() -> void:
	get_tree().create_timer(1.5).timeout.connect(func():
		if not playing:
			return
		get_tree().paused = true
		_set_mouse_captured(false)
		hud.show_menu("You Died", "Kills  %d / %d" % [Game.kills, Game.total_enemies], [
			["Retry Level", func(): start_level(level_index)],
			["Quit to Title", show_title],
		]))


func _set_mouse_captured(captured: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _format_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


## Input actions are registered in code so the project needs no editor setup.
## They show up under Project Settings > Input Map only at runtime; to rebind,
## edit the keys below.
func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"reload": [KEY_R],
		"weapon_1": [KEY_1],
		"weapon_2": [KEY_2],
		"weapon_3": [KEY_3],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mb)
