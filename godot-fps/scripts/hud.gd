extends CanvasLayer
## On-screen HUD (health, ammo, key, messages, crosshair) plus a simple
## menu panel used for the title screen, pause, level complete and death.

var _health_label: Label
var _health_fill: ColorRect
var _ammo_label: Label
var _weapon_label: Label
var _key_label: Label
var _level_label: Label
var _kills_label: Label
var _message_label: Label
var _hitmarker: Label
var _damage_rect: ColorRect
var _hud_root: Control
var _menu: Control
var _menu_title: Label
var _menu_body: Label
var _menu_buttons: VBoxContainer

var _message_t := 0.0
var _hit_t := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_damage_rect = ColorRect.new()
	_damage_rect.color = Color(0.8, 0.0, 0.0, 0.0)
	_damage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_damage_rect)

	_hud_root = Control.new()
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hud_root)

	# Crosshair.
	var cross := Control.new()
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.set_anchors_preset(Control.PRESET_CENTER)
	_hud_root.add_child(cross)
	for r in [Rect2(-12, -1, 8, 2), Rect2(4, -1, 8, 2), Rect2(-1, -12, 2, 8), Rect2(-1, 4, 2, 8)]:
		var bar := ColorRect.new()
		bar.color = Color(1, 1, 1, 0.85)
		bar.position = r.position
		bar.size = r.size
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cross.add_child(bar)
	_hitmarker = _label(cross, 30, Color(1, 0.3, 0.25))
	_hitmarker.text = "x"
	_hitmarker.position = Vector2(-9, -24)
	_hitmarker.visible = false

	# Bottom-left: health.
	var health_box := _anchored(Control.new(), 0, 1, 0, 1, 28, -84, 360, -24)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.5)
	bar_bg.position = Vector2(0, 44)
	bar_bg.size = Vector2(260, 12)
	health_box.add_child(bar_bg)
	_health_fill = ColorRect.new()
	_health_fill.color = Color(0.9, 0.25, 0.2)
	_health_fill.position = Vector2(0, 44)
	_health_fill.size = Vector2(260, 12)
	health_box.add_child(_health_fill)
	_health_label = _label(health_box, 34, Color.WHITE)
	_health_label.position = Vector2(0, -6)

	# Bottom-right: weapon and ammo.
	var ammo_box := _anchored(Control.new(), 1, 1, 1, 1, -320, -96, -28, -24)
	_weapon_label = _label(ammo_box, 18, Color(0.8, 0.82, 0.86))
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_label.size = Vector2(292, 24)
	_ammo_label = _label(ammo_box, 40, Color.WHITE)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.position = Vector2(0, 20)
	_ammo_label.size = Vector2(292, 48)

	# Top bar.
	_level_label = _label(_anchored(Control.new(), 0, 0, 0, 0, 28, 20, 600, 60), 20, Color(0.85, 0.87, 0.9))
	var top_right := _anchored(Control.new(), 1, 0, 1, 0, -360, 20, -28, 90)
	_kills_label = _label(top_right, 20, Color(0.85, 0.87, 0.9))
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kills_label.size = Vector2(332, 28)
	_key_label = _label(top_right, 20, Color(1.0, 0.3, 0.25))
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_key_label.position = Vector2(0, 30)
	_key_label.size = Vector2(332, 28)
	_key_label.text = "RED KEYCARD"
	_key_label.visible = false

	# Centre message.
	var msg_box := _anchored(Control.new(), 0, 0.62, 1, 0.62, 0, 0, 0, 40)
	_message_label = _label(msg_box, 24, Color(1, 0.95, 0.8))
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	_build_menu()


func _anchored(c: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, o_r: float, ob: float) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = o_r
	c.offset_bottom = ob
	_hud_root.add_child(c)
	return c


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_menu() -> void:
	_menu = ColorRect.new()
	(_menu as ColorRect).color = Color(0.03, 0.035, 0.05, 0.86)
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(520, 0)
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)
	_menu_title = _label(vbox, 56, Color(0.95, 0.35, 0.25))
	_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_body = _label(vbox, 20, Color(0.85, 0.87, 0.9))
	_menu_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_buttons = VBoxContainer.new()
	_menu_buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(_menu_buttons)
	_menu.visible = false


## Shows the menu. `buttons` is an array of [label, Callable] pairs.
func show_menu(title: String, body: String, buttons: Array) -> void:
	_menu_title.text = title
	_menu_body.text = body
	for c in _menu_buttons.get_children():
		c.queue_free()
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(0, 46)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(b[1])
		_menu_buttons.add_child(btn)
	_menu.visible = true
	_hud_root.visible = false
	if _menu_buttons.get_child_count() > 0:
		(_menu_buttons.get_child(0) as Button).grab_focus.call_deferred()


func hide_menu() -> void:
	_menu.visible = false
	_hud_root.visible = true


func is_menu_visible() -> bool:
	return _menu.visible


func set_level(text: String) -> void:
	_level_label.text = text


func set_health(hp: int, max_hp: int) -> void:
	_health_label.text = "%d" % hp
	_health_fill.size.x = 260.0 * float(hp) / float(max_hp)
	_health_fill.color = Color(0.9, 0.25, 0.2) if hp > 30 else Color(1.0, 0.1, 0.1)


func set_ammo(weapon_name: String, mag: int, reserve: int) -> void:
	_weapon_label.text = weapon_name.to_upper()
	_ammo_label.text = "%d / %s" % [mag, "inf" if reserve < 0 else str(reserve)]


func set_key(has_key: bool) -> void:
	_key_label.visible = has_key


func set_kills(kills: int, total: int) -> void:
	_kills_label.text = "Kills %d / %d" % [kills, total]


func flash_damage() -> void:
	_damage_rect.color.a = 0.35


func show_hitmarker(headshot: bool, killed: bool) -> void:
	_hit_t = 0.15 if not killed else 0.3
	_hitmarker.add_theme_color_override("font_color",
		Color(1, 0.85, 0.2) if headshot else (Color(1, 0.3, 0.25) if killed else Color.WHITE))
	_hitmarker.visible = true


func show_message(text: String, duration: float) -> void:
	_message_label.text = text
	_message_t = duration


func _process(delta: float) -> void:
	_damage_rect.color.a = move_toward(_damage_rect.color.a, 0.0, delta * 0.9)
	_hit_t -= delta
	_hitmarker.visible = _hit_t > 0.0
	if _message_t > 0.0:
		_message_t -= delta
		_message_label.modulate.a = clampf(_message_t * 2.0, 0.0, 1.0)
