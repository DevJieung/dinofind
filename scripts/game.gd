extends Node2D

## 공룡을 찾아라!  —  집 안 여러 방에 숨은 공룡을 찾는 게임.

const W := 1280.0
const H := 720.0

const SAVE_PATH := "user://dino_save.cfg"

var rooms: Array = []          ## 손으로 꾸민 방 6개 (1~6탄)
var stage := 1                 ## 7탄부터는 room_gen.gd 가 새 방을 만들어 준다
var room: Dictionary = {}
var dinos: Array[Dino] = []
var props: Array[Prop] = []
var found := 0
var total_found := 0           ## 이번 판에서 찾은 수
var best_stage := 1            ## 지금까지 간 최고 탄
var lifetime_found := 0        ## 여태까지 찾은 공룡 수 (계속 쌓임)
var state := "title"
var idle := 0.0
var busy := false

var world: Node2D
var fx: Confetti
var sfx: Sfx
var ui: CanvasLayer

var hud: Control
var hud_name: Label
var hud_sub: Label
var row: DinoRow
var sound_btn: Button
var home_btn: Button

var title_ui: Control
var title_record: Label
var continue_btn: Button
var banner: Panel
var banner_label: Label
var fade: ColorRect

var card: Panel
var card_img: TextureRect
var card_label: Label
var card_tween: Tween

var _pool: Array = []  ## 공룡 종류를 골고루 뽑기 위한 주머니
var _slow := 1.0       ## 연출 길이 배수 (자동 테스트에서만 짧게 줄인다)

const INK := Color("463a45")


# ================================================================= 준비

func _ready() -> void:
	randomize()
	rooms = Rooms.all()
	_load_record()

	world = Node2D.new()
	add_child(world)
	fx = Confetti.new()
	add_child(fx)
	sfx = Sfx.new()
	add_child(sfx)

	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	_build_hud()
	_build_title()
	_build_banner()
	_build_card()

	var fl := CanvasLayer.new()
	fl.layer = 20
	add_child(fl)
	fade = ColorRect.new()
	fade.color = Color(1, 1, 1, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(fade)

	show_title()

	if "--dump" in OS.get_cmdline_user_args():
		_dump()
	elif "--selftest" in OS.get_cmdline_user_args():
		_selftest()


# ================================================================= UI 만들기

func _label(text: String, fsize: int, col: Color, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color.WHITE)
		l.add_theme_constant_override("outline_size", outline)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wide_label(text: String, fsize: int, y: float, col: Color, outline := 0) -> Label:
	var l := _label(text, fsize, col, outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_right = 1.0
	l.offset_top = y
	l.offset_bottom = y + fsize * 1.7
	return l


func _button(text: String, fsize: int, base: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.set_corner_radius_all(int(fsize * 0.7))
	sb.content_margin_left = fsize * 0.9
	sb.content_margin_right = fsize * 0.9
	sb.content_margin_top = fsize * 0.35
	sb.content_margin_bottom = fsize * 0.45
	sb.border_width_bottom = 7
	sb.border_color = base.darkened(0.28)
	b.add_theme_stylebox_override("normal", sb)
	var sh: StyleBoxFlat = sb.duplicate()
	sh.bg_color = base.lightened(0.10)
	b.add_theme_stylebox_override("hover", sh)
	var sp: StyleBoxFlat = sb.duplicate()
	sp.bg_color = base.darkened(0.08)
	sp.border_width_bottom = 2
	sp.content_margin_top = fsize * 0.42
	sp.content_margin_bottom = fsize * 0.38
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _center_row(y: float, height: float) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 28)
	hb.anchor_right = 1.0
	hb.offset_top = y
	hb.offset_bottom = y + height
	return hb


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)

	var bar := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.80)
	sb.set_corner_radius_all(30)
	sb.shadow_size = 8
	sb.shadow_color = Color(0, 0, 0, 0.10)
	bar.add_theme_stylebox_override("panel", sb)
	bar.position = Vector2(22, 16)
	bar.size = Vector2(W - 44, 88)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bar)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	hb.position = Vector2(56, 34)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hb)
	hud_name = _label("거실", 40, INK)
	hb.add_child(hud_name)
	hud_sub = _label("1 / 6", 24, Color("8a7c8c"))
	hb.add_child(hud_sub)

	row = DinoRow.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(700, 20)
	hud.add_child(row)

	sound_btn = _button("소리 켜짐", 20, Color("cfe8ff"))
	sound_btn.position = Vector2(W - 330, 32)
	sound_btn.pressed.connect(_toggle_sound)
	hud.add_child(sound_btn)

	home_btn = _button("처음으로", 20, Color("ffe0e6"))
	home_btn.position = Vector2(W - 180, 32)
	home_btn.pressed.connect(_go_title)
	hud.add_child(home_btn)


func _build_title() -> void:
	title_ui = Control.new()
	title_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(title_ui)

	title_ui.add_child(_wide_label("공룡을 찾아라!", 92, 48, Color("ff7a59"), 14))
	title_ui.add_child(_wide_label("집 안에 숨은 공룡을 콕! 눌러 찾아보세요", 30, 200, Color("5c4a5c"), 8))
	title_record = _wide_label("", 28, 262, Color("7a6a7c"), 8)
	title_ui.add_child(title_record)

	var hb := _center_row(598, 116)
	var b := _button("시작!", 54, Color("ffd166"))
	b.pressed.connect(_start_game.bind(1))
	hb.add_child(b)
	continue_btn = _button("이어서", 40, Color("9be36f"))
	continue_btn.pressed.connect(_continue_game)
	hb.add_child(continue_btn)
	title_ui.add_child(hb)


## 기록 저장 (몇 탄까지 갔는지, 여태 몇 마리 찾았는지)
func _load_record() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_stage = maxi(1, int(cfg.get_value("record", "best_stage", 1)))
		lifetime_found = maxi(0, int(cfg.get_value("record", "found", 0)))


func _save_record() -> void:
	best_stage = maxi(best_stage, stage)
	var cfg := ConfigFile.new()
	cfg.set_value("record", "best_stage", best_stage)
	cfg.set_value("record", "found", lifetime_found)
	cfg.save(SAVE_PATH)


func _build_banner() -> void:
	banner = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.92)
	sb.set_corner_radius_all(40)
	sb.border_width_bottom = 8
	sb.border_color = Color("ffd166")
	sb.shadow_size = 12
	sb.shadow_color = Color(0, 0, 0, 0.12)
	banner.add_theme_stylebox_override("panel", sb)
	banner.size = Vector2(560, 150)
	banner.position = Vector2(W * 0.5 - 280, 200)
	banner.pivot_offset = Vector2(280, 75)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	ui.add_child(banner)

	banner_label = _label("잘했어요!", 60, Color("ff7a59"))
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(banner_label)


## 공룡을 찾으면 3초쯤 떠오르는 카드 — 큰 그림 + 이름 전부
func _build_card() -> void:
	card = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.95)
	sb.set_corner_radius_all(44)
	sb.border_width_bottom = 10
	sb.border_color = Color("ffd166")
	sb.shadow_size = 16
	sb.shadow_color = Color(0, 0, 0, 0.16)
	card.add_theme_stylebox_override("panel", sb)
	card.size = Vector2(460, 330)
	card.position = Vector2(W * 0.5 - 230, 110)
	card.pivot_offset = Vector2(230, 165)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	ui.add_child(card)

	card_img = TextureRect.new()
	card_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_img.position = Vector2(20, 18)
	card_img.size = Vector2(420, 208)
	card_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_img)

	card_label = _label("", 40, INK)
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.position = Vector2(0, 238)
	card_label.size = Vector2(460, 72)
	card.add_child(card_label)


func _show_card(d: Dino) -> void:
	var tex := d.texture()
	card_img.texture = tex
	card_img.visible = tex != null
	card_label.text = d.full_name()
	card_label.position.y = 238 if tex != null else 130
	card.visible = true
	card.modulate.a = 1.0
	card.scale = Vector2(0.5, 0.5)
	if card_tween != null and card_tween.is_valid():
		card_tween.kill()
	card_tween = create_tween()
	card_tween.tween_property(card, "scale", Vector2(1.06, 1.06), 0.22 * _slow).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card_tween.tween_property(card, "scale", Vector2.ONE, 0.12 * _slow)
	card_tween.tween_interval(2.05 * _slow)
	card_tween.tween_property(card, "modulate:a", 0.0, 0.40 * _slow)
	card_tween.tween_callback(_hide_card)


func _hide_card() -> void:
	if card_tween != null and card_tween.is_valid():
		card_tween.kill()
	card.visible = false


# ================================================================= 화면 전환

func show_title() -> void:
	state = "title"
	busy = false
	stage = 1
	found = 0
	total_found = 0
	title_ui.visible = true
	hud.visible = false
	banner.visible = false
	_hide_card()
	fx.clear_all()
	_pool.clear()
	if best_stage > 1:
		title_record.text = "최고 기록 %d탄 · 지금까지 공룡 %d마리" % [best_stage, lifetime_found]
		continue_btn.text = "%d탄부터" % best_stage
		continue_btn.visible = true
	else:
		title_record.text = ""
		continue_btn.visible = false
	_build_showcase(0, [3, 0, 2])


func _go_title() -> void:
	if busy:
		return
	sfx.play("tap")
	show_title()


func _continue_game() -> void:
	_start_game(best_stage)


func _start_game(from_stage := 1) -> void:
	if busy:
		return
	sfx.play("start")
	title_ui.visible = false
	hud.visible = true
	_hide_card()
	_pool.clear()
	stage = maxi(1, from_stage)
	total_found = 0
	_build_room()


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	sound_btn.text = "소리 켜짐" if sfx.enabled else "소리 꺼짐"
	if sfx.enabled:
		sfx.play("tap")
	else:
		sfx.stop_all()


# ================================================================= 방 만들기

func _clear_world() -> void:
	for c in world.get_children():
		c.queue_free()
	dinos.clear()
	props.clear()


func _add_bg(room: Dictionary) -> void:
	var bg := RoomBg.new()
	bg.data = room
	bg.z_index = -20
	world.add_child(bg)


func _add_props(list: Array, z: int) -> Array[Prop]:
	var out: Array[Prop] = []
	for d in list:
		var p := Prop.new()
		p.setup(String(d["kind"]), float(d["w"]), float(d["h"]), d["col"], d["col2"])
		p.position = Vector2(float(d["x"]), float(d["y"]))
		p.z_index = z
		world.add_child(p)
		out.append(p)
	return out


## 공룡끼리 겹치지 않도록 충분히 떨어진 자리들을 고른다.
func _pick_spots(room: Dictionary, count: int) -> Array:
	var front: Array = room["front"]
	var pool: Array = (room["spots"] as Array).duplicate()
	pool.shuffle()
	var picked: Array = []
	var xs: Array = []
	for gap in [230.0, 170.0, 0.0]:  # 자리가 모자라면 조건을 완화
		for s in pool:
			if picked.size() >= count:
				break
			if picked.has(s):
				continue
			var x: float = (Rooms.spot_transform(front, s)["pos"] as Vector2).x
			var ok := true
			for other in xs:
				if absf(float(other) - x) < gap:
					ok = false
					break
			if ok:
				picked.append(s)
				xs.append(x)
		if picked.size() >= count:
			break
	return picked


## 1~6탄은 손으로 꾸민 방, 7탄부터는 그때그때 새로 만든 방
func _room_for(s: int) -> Dictionary:
	if s <= rooms.size():
		return rooms[s - 1]
	var r := RandomNumberGenerator.new()
	r.seed = randi()
	return RoomGen.stage_room(s, r)


func _build_room() -> void:
	room = _room_for(stage)
	_clear_world()
	fx.clear_all()
	found = 0
	idle = 0.0
	busy = false
	state = "play"

	_add_bg(room)
	_add_props(room["back"], -10)

	var spots := _pick_spots(room, int(room["count"]))
	var count := spots.size()

	var species: Array = []
	for i in count:
		var sp := _next_species(species)
		var st: Dictionary = Rooms.spot_transform(room["front"], spots[i])
		var d := Dino.new()
		d.setup(sp, st["pos"], st["face"])
		world.add_child(d)
		dinos.append(d)
		species.append(sp)

	props = _add_props(room["front"], 20)

	hud_name.text = String(room["name"])
	hud_sub.text = "%d탄 · 공룡 %d마리" % [stage, total_found]
	row.set_room(species)
	row.position = Vector2(930.0 - row.size.x, 20)


## 한 방 안에서는 같은 종이 겹치지 않게, 한 판 동안은 골고루 나오게 뽑는다.
func _next_species(avoid: Array) -> int:
	for attempt in 2:
		if _pool.is_empty():
			_pool = range(DinoSpecies.count())
			_pool.shuffle()
		for i in _pool.size():
			if not avoid.has(_pool[i]):
				return int(_pool.pop_at(i))
		_pool.clear()
	return randi() % DinoSpecies.count()


## 타이틀/엔딩 배경용: 공룡들이 밖에 나와서 춤추는 방
func _build_showcase(idx: int, kinds: Array) -> void:
	var room: Dictionary = rooms[idx]
	_clear_world()
	_add_bg(room)
	_add_props(room["back"], -10)
	_add_props(room["front"], 20)
	var n := kinds.size()
	for i in n:
		var d := Dino.new()
		var x: float = 170.0 + (W - 340.0) * (float(i) / maxf(1.0, float(n) - 1.0))
		d.setup(int(kinds[i]), Vector2(x, 556.0), 1.0 if i % 2 == 0 else -1.0)
		d.found = true
		d.joy = 1.0
		d.z_index = 40
		world.add_child(d)
		dinos.append(d)


# ================================================================= 입력

func _unhandled_input(event: InputEvent) -> void:
	# F11 전체화면 / ESC 창모드 (어른용)
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if key == KEY_ESCAPE:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			return
	if busy:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# 아기가 아무 데나 눌러도 시작/다시하기가 되도록
	if state == "title":
		_start_game(1)
	elif state == "play":
		_tap(get_global_mouse_position())


func _tap(p: Vector2) -> void:
	for i in range(dinos.size() - 1, -1, -1):
		var d: Dino = dinos[i]
		if not d.found and d.hit_rect().has_point(p):
			_on_found(d)
			return
	for i in range(props.size() - 1, -1, -1):
		var pr: Prop = props[i]
		if pr.rect().has_point(p):
			pr.jiggle()
			sfx.play("miss", randf_range(0.95, 1.1))
			fx.burst(p, 5, Color("ffffff"))
			return
	sfx.play("miss", randf_range(0.9, 1.05))
	fx.burst(p, 4, Color("ffffff"))


func _on_found(d: Dino) -> void:
	d.celebrate()
	found += 1
	total_found += 1
	lifetime_found += 1
	idle = 0.0
	hud_sub.text = "%d탄 · 공룡 %d마리" % [stage, total_found]
	row.found = found
	row.queue_redraw()
	sfx.play("find", 1.0 + 0.06 * float(found - 1))
	fx.burst(d.base_pos + Vector2(0, -100), 22, DinoSpecies.data(d.species)["col"])
	_show_card(d)
	if found >= dinos.size():
		_room_clear()


# ================================================================= 진행

func _room_clear() -> void:
	busy = true
	state = "clear"
	await get_tree().create_timer(2.9 * _slow).timeout  # 마지막 공룡 카드를 다 보고 나서
	var milestone := stage % 10 == 0
	if milestone:
		sfx.play("hooray")
		fx.rain(150)
		_show_banner("%d탄 돌파!" % stage)
	else:
		sfx.play("clear")
		fx.rain(70)
		_show_banner("잘했어요!")
	await get_tree().create_timer((3.4 if milestone else 2.3) * _slow).timeout
	_hide_banner()
	stage += 1
	_save_record()
	await _fade(_build_room)


func _show_banner(text: String) -> void:
	banner_label.text = text
	banner.visible = true
	banner.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2(1.1, 1.1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.12)


func _hide_banner() -> void:
	banner.visible = false


func _fade(cb: Callable) -> void:
	busy = true
	var tw := create_tween()
	tw.tween_property(fade, "color", Color(1, 1, 1, 1), 0.30 * _slow)
	await tw.finished
	cb.call()
	var tw2 := create_tween()
	tw2.tween_property(fade, "color", Color(1, 1, 1, 0), 0.35 * _slow)
	await tw2.finished


# ================================================================= 매 프레임

func _process(delta: float) -> void:
	if state != "play" or busy:
		return
	idle += delta
	if idle > 12.0:
		idle = 5.0
		var any := false
		for d in dinos:
			if not d.found:
				d.hint()
				any = true
		if any:
			sfx.play("tap", 0.7)


# ============================================ 개발용: 화면 구성을 JSON으로 뽑기
# godot --headless -- --dump   (그래픽 없는 곳에서 배치 확인할 때만 사용)

## 자동으로 여러 탄을 이어서 돌려본다 (오류 확인용)
func _selftest() -> void:
	const LAST := 30
	var names: Array = []
	_slow = 0.10  # 연출을 짧게 — headless 는 프레임 제한이 없어 대기가 프레임을 많이 먹는다
	var t0 := Time.get_ticks_msec()
	_start_game(1)
	# 빗나간 탭 / 가구 탭 / 소리 끄기·켜기도 한 번씩
	await get_tree().process_frame
	_tap(Vector2(640, 200))
	if props.size() > 0:
		_tap(props[0].position + Vector2(0, -20))
	_toggle_sound()
	_toggle_sound()
	var guard := 0
	var last_seen := 0
	while stage <= LAST and Time.get_ticks_msec() - t0 < 180000:
		guard += 1
		await get_tree().process_frame
		if state == "play" and not busy:
			if stage != last_seen:
				last_seen = stage
				names.append("%d:%s(%d)" % [stage, String(room["name"]), dinos.size()])
			var target: Dino = null
			for d in dinos:
				if not d.found:
					target = d
					break
			if target == null:
				continue
			_tap(target.base_pos + Vector2(0, -70))
	print("자동 테스트: %d탄까지 진행, 공룡 %d마리, %.1f초\n  %s" % [last_seen, total_found, (Time.get_ticks_msec() - t0) / 1000.0, ", ".join(PackedStringArray(names))])
	if last_seen < LAST:
		printerr("자동 테스트 실패! %d탄에서 멈춤" % last_seen)
	sfx.stop_all()
	get_tree().quit()


## 손으로 꾸민 1~6탄: 숨을 자리마다 "얼마나 가려지는지" 확인 (28~74%가 적당)
func _check_spots() -> void:
	for r in rooms:
		var front: Array = r["front"]
		var spots: Array = r["spots"]
		for i in spots.size():
			var st: Dictionary = Rooms.spot_transform(front, spots[i])
			var cov := Rooms.coverage(st["pos"], front)
			var mark := "  " if cov >= 28 and cov <= 74 else "!!"
			print("%s %s spot%d(p%d,s%d) 가림 %d%%" % [mark, String(r["name"]), i, int(spots[i]["p"]), int(spots[i]["side"]), cov])


## 자동으로 만들어지는 7탄~ : 전부 제대로 된 방이 나오는지 무더기로 검사
func _check_stages(last := 200) -> void:
	var bad_spots := 0
	var bad_cov := 0
	var min_spots := 99
	var counts := {}
	var rng := RandomNumberGenerator.new()
	for s in range(7, last + 1):
		for repeat in 3:  # 같은 탄도 매번 새로 만들어지므로 여러 번 본다
			rng.seed = hash(str(s) + "_" + str(repeat))
			var r := RoomGen.stage_room(s, rng)
			var need := int(r["count"])
			var picked := _pick_spots(r, need)
			min_spots = mini(min_spots, (r["spots"] as Array).size())
			counts[need] = int(counts.get(need, 0)) + 1
			if picked.size() < need:
				bad_spots += 1
				if bad_spots <= 3:
					print("!! %d탄: 숨을 자리 부족 (%d/%d)" % [s, picked.size(), need])
			for sp in picked:
				var st: Dictionary = Rooms.spot_transform(r["front"], sp)
				var cov := Rooms.coverage(st["pos"], r["front"])
				if cov < 28 or cov > 74:
					bad_cov += 1
					if bad_cov <= 3:
						print("!! %d탄: 가림 %d%%" % [s, cov])
	var mark := "  " if bad_spots == 0 and bad_cov == 0 else "!!"
	print("%s 자동 생성 7~%d탄 (각 3회): 자리부족 %d건, 가림이상 %d건, 최소 자리수 %d, 공룡수 분포 %s"
		% [mark, last, bad_spots, bad_cov, min_spots, str(counts)])


## 글자가 상자 밖으로 삐져나가지 않는지 폭을 재서 확인한다.
func _check_text() -> void:
	var f: Font = card_label.get_theme_font("font")
	var fs: int = card_label.get_theme_font_size("font_size")
	var widest := 0.0
	var widest_name := ""
	for i in DinoSpecies.count():
		var nm := DinoSpecies.full_name(i)
		var w: float = f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w > widest:
			widest = w
			widest_name = nm
	var room_for := card_label.size.x - 24.0
	var mark := "!!" if widest > room_for else "  "
	print("%s 카드 이름 최대폭 %.0fpx (%s) / 자리 %.0fpx" % [mark, widest, widest_name, room_for])

	var missing := PackedStringArray()
	for i in DinoSpecies.count():
		if DinoSpecies.texture(i) == null:
			missing.append(String(DinoSpecies.data(i)["id"]))
	# 첫 화면 버튼이 화면 밖으로 나가지 않는지
	best_stage = 123
	show_title()
	var bw: float = continue_btn.get_combined_minimum_size().x + 28.0
	for b in title_ui.get_children():
		if b is HBoxContainer:
			for c in (b as HBoxContainer).get_children():
				bw += (c as Control).get_combined_minimum_size().x
	print("%s 첫 화면 버튼 줄 폭 %.0fpx / 화면 %dpx" % ["!!" if bw > W - 80 else "  ", bw, int(W)])
	best_stage = 1

	if missing.size() > 0:
		print("!! 그림 없는 공룡 %d종 (손그림으로 대체 중): %s" % [missing.size(), ", ".join(missing)])
	else:
		print("   공룡 그림 %d종 모두 있음" % DinoSpecies.count())


func _dump() -> void:
	var dir := ProjectSettings.globalize_path("res://preview")
	DirAccess.make_dir_recursive_absolute(dir)
	_check_spots()
	_check_stages()
	_check_text()
	await get_tree().process_frame
	state = "play"
	# 손으로 꾸민 1~6탄
	for i in rooms.size():
		stage = i + 1
		_build_room()
		await get_tree().process_frame
		_dump_world(dir + "/%d_%s.json" % [i + 1, String(rooms[i]["name"])], true)
	# 자동으로 만들어지는 방 몇 개 (매번 달라지므로 맛보기)
	for s in [7, 12, 24, 47, 88, 137]:
		stage = s
		_build_room()
		await get_tree().process_frame
		_dump_world(dir + "/s%03d_%s.json" % [s, String(room["name"])], true)
	show_title()
	await get_tree().process_frame
	_dump_world(dir + "/0_title.json", false)
	_dump_icon(dir + "/icon.json")
	stage = 1
	_build_room()
	await get_tree().process_frame
	_dump_card(dir + "/9_카드.json")
	get_tree().quit()


## 공룡을 찾았을 때 뜨는 카드 미리보기 (글자는 회색 막대로 자리만 표시)
func _dump_card(path: String) -> void:
	var rec = load("res://tools/recorder.gd").new()
	_paint_world(rec)
	rec.set_node(Transform2D.IDENTITY)
	rec.draw_rect(Rect2(22, 16, W - 44, 88), Color(1, 1, 1, 0.8))
	DinoArt.blob(rec, DinoArt.rrect(Rect2(card.position, card.size), 44), Color(1, 1, 1, 0.95), Color("ffd166"), 8.0)
	var d: Dino = dinos[0]
	var tex := d.texture()
	if tex != null:
		var box := Rect2(card.position + card_img.position, card_img.size)
		var ts := Vector2(tex.get_width(), tex.get_height())
		var k: float = minf(box.size.x / ts.x, box.size.y / ts.y)
		var sz := ts * k
		rec.draw_texture_rect(tex, Rect2(box.position + (box.size - sz) * 0.5, sz))
	var f: Font = card_label.get_theme_font("font")
	var fs: int = card_label.get_theme_font_size("font_size")
	var tw: float = f.get_string_size(d.full_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	rec.draw_rect(Rect2(card.position + card_label.position + Vector2((card_label.size.x - tw) * 0.5, 8), Vector2(tw, fs)), Color(0.55, 0.5, 0.58, 0.55))
	rec.save(path)


## 안드로이드 런처 아이콘용 공룡 그림 (432x432 안전영역 안에)
func _dump_icon(path: String) -> void:
	var rec = load("res://tools/recorder.gd").new()
	rec.set_node(Transform2D(0.0, Vector2(1.45, 1.45), 0.0, Vector2(238, 328)))
	DinoArt.draw_dino(rec, 0, DinoArt.palette(0), 1.0, 1.0, false)
	rec.save(path)


func _paint_world(rec) -> void:
	var kids := world.get_children()
	var zs: Array = []
	for k in kids:
		if not zs.has(k.z_index):
			zs.append(k.z_index)
	zs.sort()
	for z in zs:
		for k in kids:
			if k.z_index == z:
				rec.set_node(Transform2D(k.rotation, k.scale, 0.0, k.position))
				k._paint(rec)


func _dump_world(path: String, with_hud: bool) -> void:
	var rec = load("res://tools/recorder.gd").new()
	_paint_world(rec)
	if with_hud:
		rec.set_node(Transform2D.IDENTITY)
		rec.draw_rect(Rect2(22, 16, W - 44, 88), Color(1, 1, 1, 0.8))
		if "--boxes" in OS.get_cmdline_user_args():
			for b in [sound_btn, home_btn]:
				rec.draw_rect((b as Button).get_rect(), Color("cfe8ff"))
			print("  HUD 위치: 카운터 %s  소리 %s  처음으로 %s" % [row.get_rect(), sound_btn.get_rect(), home_btn.get_rect()])
		rec.set_node(Transform2D(0.0, Vector2.ONE, 0.0, row.position))
		row._paint(rec)
		if "--boxes" in OS.get_cmdline_user_args():
			rec.set_node(Transform2D.IDENTITY)
			for d in dinos:
				rec.draw_rect(d.hit_rect(), Color(1, 0, 0, 0.10))
	rec.save(path)
