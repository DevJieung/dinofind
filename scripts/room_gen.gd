class_name RoomGen
extends RefCounted

## 7탄부터는 방을 그때그때 만들어 낸다. 그래서 끝이 없다.
##   테마(이름 + 색) -> 가구 배치 -> 숨을 자리 고르기 -> 가려지는 정도 검사
## 나오는 값의 모양은 rooms.gd 의 손으로 만든 방과 똑같다.

const W := 1280.0
const LEFT := 60.0
const RIGHT := 1220.0

## 방 이름. 한 바퀴 돌면 색이 달라진 채로 다시 나온다.
static var THEMES := [
	{"n": "서재", "dark": false}, {"n": "지하실", "dark": true},
	{"n": "창고", "dark": false}, {"n": "아기방", "dark": false},
	{"n": "식당", "dark": false}, {"n": "세탁실", "dark": false},
	{"n": "현관", "dark": false}, {"n": "옷방", "dark": false},
	{"n": "공부방", "dark": false}, {"n": "손님방", "dark": false},
	{"n": "음악방", "dark": false}, {"n": "그림방", "dark": false},
	{"n": "별빛방", "dark": true}, {"n": "숲속방", "dark": false},
	{"n": "바다방", "dark": false}, {"n": "사탕방", "dark": false},
	{"n": "눈꽃방", "dark": false}, {"n": "무지개방", "dark": false},
	{"n": "구름방", "dark": false}, {"n": "딸기방", "dark": false},
	{"n": "레몬방", "dark": false}, {"n": "초코방", "dark": false},
	{"n": "우주방", "dark": true}, {"n": "공룡방", "dark": false},
	{"n": "장난감방", "dark": false}, {"n": "비밀방", "dark": true},
]

## 가구 목록.  hide: side=옆으로 빼꼼, low=뒤에서 머리만, none=숨는 자리 없음
static var CATALOG := [
	{"k": "sofa", "w": [380, 460], "h": [190, 230], "hide": "side"},
	{"k": "bed", "w": [370, 460], "h": [190, 220], "hide": "side"},
	{"k": "counter", "w": [350, 430], "h": [180, 210], "hide": "side"},
	{"k": "bathtub", "w": [370, 440], "h": [170, 200], "hide": "side"},
	{"k": "wardrobe", "w": [210, 260], "h": [320, 360], "hide": "side"},
	{"k": "fridge", "w": [190, 220], "h": [310, 350], "hide": "side"},
	{"k": "tv", "w": [240, 290], "h": [210, 240], "hide": "side"},
	{"k": "boxes", "w": [210, 260], "h": [230, 280], "hide": "side"},
	{"k": "toybox", "w": [240, 290], "h": [150, 180], "hide": "side"},
	{"k": "horse", "w": [230, 270], "h": [180, 210], "hide": "side"},
	{"k": "chair", "w": [190, 230], "h": [200, 240], "hide": "side"},
	{"k": "toilet", "w": [160, 190], "h": [200, 230], "hide": "side"},
	{"k": "sink", "w": [190, 220], "h": [160, 190], "hide": "side"},
	{"k": "nightstand", "w": [140, 175], "h": [155, 185], "hide": "side"},
	{"k": "plant", "w": [140, 175], "h": [250, 290], "hide": "side"},
	{"k": "bin", "w": [105, 130], "h": [140, 170], "hide": "side"},
	{"k": "table", "w": [210, 255], "h": [100, 125], "hide": "low"},
	{"k": "basket", "w": [150, 185], "h": [105, 132], "hide": "low"},
	{"k": "balls", "w": [180, 220], "h": [108, 130], "hide": "low"},
	{"k": "trunk", "w": [255, 300], "h": [115, 140], "hide": "low"},
	{"k": "blocks", "w": [130, 155], "h": [200, 240], "hide": "none"},
	{"k": "lamp", "w": [100, 130], "h": [255, 300], "hide": "none"},
]

static var FURN_COLORS := [
	"c98a55", "d8a86b", "b98d5e", "9ec6f0", "7fb5d9", "8fd6ff", "bcd9e8",
	"ffb3c1", "f2a2b0", "a3d9a5", "8fc98f", "c9a8e8", "e3c48f", "ffd166",
	"d6a86e", "e8a87c", "9fd8cf", "cbb7e8",
]

static var WOOD := ["c98a55", "d2a46c", "e6c08a", "a97b4f", "bb8a52", "d9b177"]


# ---------------------------------------------------------------- 테마(색)

static func theme_name(stage: int) -> String:
	return String(THEMES[(stage - 7) % THEMES.size()]["n"])


static func _theme(stage: int, rng: RandomNumberGenerator) -> Dictionary:
	var t: Dictionary = THEMES[(stage - 7) % THEMES.size()]
	# 황금비로 색상환을 돌아서 연달아 나오는 방이 서로 다른 색이 되게 한다.
	var hue := fposmod(float(stage) * 0.6180339887, 1.0)
	var wall := Color.from_hsv(hue, 0.15, 0.98)
	var wall2 := Color.from_hsv(hue, 0.27, 0.93)
	var trim := Color.from_hsv(hue, 0.05, 1.0)
	var wall_pat: String = ["stripes", "dots", "tiles", "planks"][rng.randi() % 4]

	var floor_col: Color
	var floor2: Color
	var floor_pat := "wood"
	if rng.randf() < 0.55:
		floor_col = Color(WOOD[rng.randi() % WOOD.size()])
		floor2 = floor_col.darkened(0.12)
	else:
		floor_pat = "checker"
		floor_col = Color.from_hsv(hue, 0.07, 0.97)
		floor2 = Color.from_hsv(hue, 0.16, 0.90)

	return {
		"name": String(t["n"]),
		"wall": wall, "wall2": wall2, "wall_pat": wall_pat,
		"floor": floor_col, "floor2": floor2, "floor_pat": floor_pat,
		"trim": trim, "dim": 0.16 if bool(t["dark"]) else 0.0,
	}


## 방 하나에 쓸 가구 색 4가지 (제각각이면 어수선해 보인다)
static func _palette(rng: RandomNumberGenerator) -> Array:
	var c: Array = FURN_COLORS.duplicate()
	c.shuffle()
	return c.slice(0, 4)


static func _prop(kind: String, x: float, y: float, w: float, h: float, rng: RandomNumberGenerator, pal: Array) -> Dictionary:
	return {
		"kind": kind, "x": x, "y": y, "w": w, "h": h,
		"col": Color(pal[rng.randi() % pal.size()]),
		"col2": Color("fff6e8"),
	}


# ---------------------------------------------------------------- 가구 배치

static func _layout(rng: RandomNumberGenerator, n: int, pal: Array) -> Array:
	var pool: Array = CATALOG.duplicate()
	pool.shuffle()
	var picks: Array = []
	var total := 0.0
	for c in pool:
		if picks.size() >= n:
			break
		var wr: Array = c["w"]
		var w: float = rng.randf_range(float(wr[0]), float(wr[1]))
		if total + w > RIGHT - LEFT - float(n + 1) * 46.0:
			continue
		picks.append({"c": c, "w": w})
		total += w
	if picks.size() < 2:
		return []

	# 남는 공간을 앞뒤와 사이사이에 나눠 준다
	var gaps_n := picks.size() + 1
	var space := (RIGHT - LEFT) - total
	var gaps: Array = []
	var acc := 0.0
	for i in gaps_n:
		var g := rng.randf_range(0.7, 1.4)
		gaps.append(g)
		acc += g
	for i in gaps_n:
		gaps[i] = float(gaps[i]) / acc * space

	var out: Array = []
	var x := LEFT
	for i in picks.size():
		x += float(gaps[i])
		var c: Dictionary = picks[i]["c"]
		var w: float = picks[i]["w"]
		var hr: Array = c["h"]
		var h: float = rng.randf_range(float(hr[0]), float(hr[1]))
		var base := rng.randf_range(620.0, 700.0)
		out.append(_prop(String(c["k"]), x + w * 0.5, base, w, h, rng, pal))
		out[out.size() - 1]["hide"] = String(c["hide"])
		x += w
	return out


static func _wall_items(rng: RandomNumberGenerator, pal: Array, front: Array) -> Array:
	var back: Array = []
	# 벽 장식은 서로 겹치지 않고, 키 큰 가구(옷장·냉장고)에 가리지도 않는 자리에서만 고른다
	var slots: Array = []
	for s in [230.0, 480.0, 730.0, 980.0, 1140.0]:
		var ok := true
		for p in front:
			if float(p["h"]) > 250.0:
				var half: float = float(p["w"]) * 0.5 + 70.0
				if absf(float(p["x"]) - s) < half:
					ok = false
					break
		if ok:
			slots.append(s)
	slots.shuffle()
	var si := 0
	if rng.randf() < 0.85 and si < slots.size():
		var w := rng.randf_range(200.0, 250.0)
		back.append(_prop("window", clampf(float(slots[si]), 130.0, W - 130.0), rng.randf_range(300.0, 350.0), w, rng.randf_range(170.0, 200.0), rng, pal))
		back[back.size() - 1]["col"] = Color("fff6e8")
		si += 1
	if rng.randf() < 0.7 and si < slots.size():
		back.append(_prop("picture", float(slots[si]), rng.randf_range(270.0, 320.0), rng.randf_range(130.0, 180.0), rng.randf_range(100.0, 140.0), rng, pal))
		si += 1
	if rng.randf() < 0.45 and si < slots.size():
		back.append(_prop("shelf", clampf(float(slots[si]), 200.0, W - 200.0), rng.randf_range(310.0, 350.0), rng.randf_range(260.0, 330.0), 95.0, rng, pal))
		si += 1
	if rng.randf() < 0.5:
		var r := _prop("rug", rng.randf_range(500.0, 780.0), rng.randf_range(700.0, 716.0), rng.randf_range(480.0, 620.0), rng.randf_range(110.0, 140.0), rng, pal)
		r["col2"] = Color(r["col"]).lightened(0.55)
		back.append(r)
	if rng.randf() < 0.25:
		back.append(_prop("cobweb", 120.0, 200.0, 170.0, 170.0, rng, pal))
		back[back.size() - 1]["col"] = Color(1, 1, 1, 0.75)
	return back


# ---------------------------------------------------------------- 숨을 자리

static func _spots_for(front: Array) -> Array:
	var out: Array = []
	for i in front.size():
		var p: Dictionary = front[i]
		var hide := String(p.get("hide", "side"))
		var sides: Array = []
		if hide == "side":
			sides = [-1, 1]
		elif hide == "low":
			sides = [0]
		for s in sides:
			var sp := {"p": i, "side": s}
			var st := Rooms.spot_transform(front, sp)
			var cov := Rooms.coverage(st["pos"], front)
			if cov >= 28 and cov <= 74:
				out.append(sp)
	return out


# ---------------------------------------------------------------- 만들기

## 이 탄에 공룡을 몇 마리 숨길지
static func dino_count(stage: int) -> int:
	return clampi(2 + int(floor(float(stage) / 5.0)), 2, 5)


static func stage_room(stage: int, rng: RandomNumberGenerator) -> Dictionary:
	var want := dino_count(stage)
	var n_props := clampi(3 + int(floor(float(stage) / 9.0)), 3, 5)
	var best_front: Array = []
	var best_spots: Array = []
	var pal := _palette(rng)

	for attempt in 14:
		var front := _layout(rng, n_props, pal)
		if front.is_empty():
			continue
		var spots := _spots_for(front)
		if spots.size() > best_spots.size():
			best_front = front
			best_spots = spots
		if spots.size() >= want + 1:
			break

	var room := _theme(stage, rng)
	room["count"] = mini(want, maxi(2, best_spots.size()))
	room["front"] = best_front
	room["back"] = _wall_items(rng, pal, best_front)
	room["spots"] = best_spots
	return room
