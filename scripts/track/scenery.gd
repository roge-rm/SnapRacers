class_name Scenery
extends Node3D

## Dresses a track with everything around it, built out of bricks.
##
## Along the road there are tire stacks on the outside of the corners, a
## grandstand and a pit building on the start straight, billboards on the
## straights, flags at the start and marshal posts at the corners. Around it
## each course has a theme (a peach farm, a coal mine, a desert city, a
## castle) with its own landmarks, trees and buildings, and its own colours
## for the ground, curbs, walls and sky.
##
## It works out how far every patch of ground is from the road, so nothing is
## ever put on the road or too close to it, and the big landmarks go where
## you'll see them. Everything is placed from a seed made from the course's
## name, so a course looks the same every time you race it.

const CELL := 4.0 # metres, for the map of how far the ground is from the road
const REACH := 80.0 # how far out from the road scenery goes
const MAX_FILLERS := 280

## Each theme: ground colour, curb and wall colours, the sky, its landmarks
## (placed first, biggest first) and its fillers with how often each turns
## up.
const THEMES := {
	"orchard": {
		"ground": "#4b9f4a", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#c4281c",
		"landmarks": ["barn", "silo", "pond", "barn"],
		"fillers": {"peach": 6, "broadleaf": 2, "hay": 2, "fence": 2, "bush": 1, "house": 1},
	},
	"trulli": {
		"ground": "#8fa251", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#c4281c",
		"landmarks": ["church", "trullo", "trullo", "trullo"],
		"fillers": {"olive": 6, "trullo": 2, "cypress": 1, "rocks": 1, "villa": 1},
	},
	"lake": {
		"ground": "#4b9f4a", "curbs": ["#0d69ab", "#f2f2f2"], "wall": "#0d69ab",
		"landmarks": ["lake", "lake", "villa", "villa"],
		"fillers": {"lemon": 3, "cypress": 4, "villa": 1, "bush": 1},
	},
	"mine": {
		"ground": "#5e8a4c", "curbs": ["#f2cd37", "#1b2a34"], "wall": "#7b2e2f",
		"landmarks": ["headframe", "slag_heap", "chimney", "headframe"],
		"fillers": {"birch": 3, "house": 2, "broadleaf": 2, "rocks": 2, "chimney": 1},
	},
	"delta": {
		"ground": "#5a9150", "curbs": ["#237841", "#f2f2f2"], "wall": "#0d69ab",
		"landmarks": ["lake", "lighthouse", "stilt_hut", "stilt_hut"],
		"fillers": {"reeds": 5, "pond": 2, "stilt_hut": 1, "bush": 2, "birch": 1},
	},
	"pit": {
		"ground": "#a08058", "curbs": ["#f2cd37", "#1b2a34"], "wall": "#da8540",
		"landmarks": ["excavator", "wind_turbine", "wind_turbine", "slag_heap"],
		"fillers": {"rocks": 4, "containers": 1, "wind_turbine": 1, "bush": 2},
	},
	"industry": {
		"ground": "#8f978f", "curbs": ["#f2cd37", "#1b2a34"], "wall": "#0d69ab",
		"landmarks": ["factory", "factory", "crane", "tanks"],
		"fillers": {"containers": 4, "chimney": 1, "tanks": 1, "bush": 1},
	},
	"amber": {
		"ground": "#4b9f4a", "curbs": ["#da8540", "#f2f2f2"], "wall": "#da8540",
		"landmarks": ["bridge", "church", "house", "house"],
		"fillers": {"birch": 4, "pine": 2, "house": 2, "bush": 1},
	},
	"timber": {
		"ground": "#3f8040", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#c4281c",
		"landmarks": ["mountain", "mountain", "lake", "cabin"],
		"fillers": {"pine": 6, "maple": 3, "cabin": 1, "rocks": 1},
	},
	"frost": {
		"ground": "#e6edf2", "curbs": ["#0d69ab", "#f2f2f2"], "wall": "#0d69ab",
		"sky": ["#7ea7d8", "#e6eef6"],
		"landmarks": ["mountain", "cottage", "cottage", "church"],
		"fillers": {"snowy_pine": 7, "cottage": 1, "snowman": 1, "rocks": 1},
	},
	"desert": {
		"ground": "#d9c38c", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#d7c599",
		"sky": ["#4d8fd6", "#f2e2c4"],
		"landmarks": ["skyscraper", "skyscraper", "skyscraper", "skyscraper", "skyscraper", "dune"],
		"fillers": {"dune": 3, "palm": 4, "tent": 1, "rocks": 1},
	},
	"railway": {
		"ground": "#4b9f4a", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#237841",
		"landmarks": ["station", "church", "castle_wall", "house"],
		"fillers": {"broadleaf": 4, "pine": 3, "house": 1, "bush": 1},
	},
	"windmill": {
		"ground": "#c9aa6c", "curbs": ["#d8261c", "#f2cd37"], "wall": "#c4281c",
		"sky": ["#3f86d6", "#dce8f2"],
		"landmarks": ["big_windmill", "big_windmill", "big_windmill", "house"],
		"fillers": {"windmill": 2, "olive": 3, "rocks": 2, "house": 1, "bush": 1},
	},
	"space": {
		"ground": "#8fae6a", "curbs": ["#0d69ab", "#f2f2f2"], "wall": "#0d69ab",
		"landmarks": ["rocket", "radar", "radar", "factory"],
		"fillers": {"palm": 5, "radar": 1, "bush": 2},
	},
	"volcano": {
		"ground": "#5c534c", "curbs": ["#f2cd37", "#1b2a34"], "wall": "#7b2e2f",
		"sky": ["#6d7c96", "#e8b98a"],
		"landmarks": ["volcano", "ruins", "ruins", "lava_pool", "lava_pool"],
		"fillers": {"rocks": 4, "lava_pool": 1, "cypress": 2, "ruins": 1},
	},
	"castle": {
		"ground": "#4b9f4a", "curbs": ["#d8261c", "#f2cd37"], "wall": "#635f61",
		"landmarks": ["castle", "lake", "tower", "tower"],
		"fillers": {"tent": 3, "broadleaf": 3, "castle_wall": 1, "house": 1},
	},
}

var track: TrackPath
var theme: Dictionary
## Places kept clear of scenery, as [middle, radius] (like the dirt inside a
## cut bend).
var keep_clear: Array = []

var _rng := RandomNumberGenerator.new()
var _kit := SceneryKit.new()
var _placed: Array = [] # [position, radius]
var _origin := Vector2.ZERO
var _cols := 0
var _rows := 0
var _dist := PackedFloat32Array()
var _near := PackedVector2Array() # the nearest road point to each cell
var _road_clear := 10.0
var _hash := {} # 16 m cell -> track sample indices


static func theme_named(id: String) -> Dictionary:
	return THEMES.get(id, THEMES["orchard"])


func _init(path: TrackPath, theme_id: String) -> void:
	track = path
	theme = theme_named(theme_id)
	_rng.seed = hash(track.name)


func _ready() -> void:
	_road_clear = track.width * 0.5 + TrackPath.KERB + TrackBuilder.WALL_THICKNESS + 1.5
	_map_distances()
	_hash_track()
	_trackside()
	_under_jumps()
	var landmarks: Array = theme.get("landmarks", [])
	landmarks = landmarks.duplicate()
	landmarks.sort_custom(func(a, b): return Props.ROOM.get(a, 3.0) > Props.ROOM.get(b, 3.0))
	for lm in landmarks:
		_place_landmark(lm)
	_fill()
	# Only things near the road need to be solid. And nothing that ended up on
	# the road itself may be, or karts would pile into it (the walls keep
	# them off everything else).
	var road_edge := track.width * 0.5 + TrackPath.KERB
	_kit.solids = _kit.solids.filter(func(s): return _distance_at(s[0].origin) < 40.0 and not _near_other_road(s[0].origin, road_edge, 0, 0.0))
	_kit.build(self)


# How far the ground is from the road.

func _map_distances() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in track.points:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	_origin = lo - Vector2.ONE * REACH
	_cols = int((hi.x - lo.x + REACH * 2.0) / CELL) + 1
	_rows = int((hi.y - lo.y + REACH * 2.0) / CELL) + 1
	_dist.resize(_cols * _rows)
	_dist.fill(INF)
	_near.resize(_cols * _rows)
	for p in track.points:
		var flat := Vector2(p.x, p.z)
		var c := _cell_of(flat)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var cx := c.x + dx
				var cy := c.y + dy
				if cx < 0 or cy < 0 or cx >= _cols or cy >= _rows:
					continue
				var i := cy * _cols + cx
				var d := _centre(cx, cy).distance_to(flat)
				if d < _dist[i]:
					_dist[i] = d
					_near[i] = flat
	# Spread the nearest road point out across the map in two sweeps, one
	# forwards and one backwards (the usual trick for a distance map).
	for pass_back in [false, true]:
		var ys := range(_rows) if not pass_back else range(_rows - 1, -1, -1)
		var xs := range(_cols) if not pass_back else range(_cols - 1, -1, -1)
		var step := -1 if not pass_back else 1
		for y in ys:
			for x in xs:
				var i: int = y * _cols + x
				var here := _centre(x, y)
				for n in [Vector2i(x + step, y), Vector2i(x, y + step), Vector2i(x + step, y + step), Vector2i(x - step, y + step)]:
					if n.x < 0 or n.y < 0 or n.x >= _cols or n.y >= _rows:
						continue
					var j: int = n.y * _cols + n.x
					if _dist[j] == INF:
						continue
					var d: float = here.distance_to(_near[j])
					if d < _dist[i]:
						_dist[i] = d
						_near[i] = _near[j]


func _cell_of(flat: Vector2) -> Vector2i:
	return Vector2i(int((flat.x - _origin.x) / CELL), int((flat.y - _origin.y) / CELL))


func _centre(x: int, y: int) -> Vector2:
	return _origin + Vector2(x + 0.5, y + 0.5) * CELL


func _distance_at(at: Vector3) -> float:
	var c := _cell_of(Vector2(at.x, at.z))
	if c.x < 0 or c.y < 0 or c.x >= _cols or c.y >= _rows:
		return INF
	return _dist[c.y * _cols + c.x]


func _hash_track() -> void:
	for k in track.points.size():
		var p := track.points[k]
		var key := Vector2i(floori(p.x / 16.0), floori(p.z / 16.0))
		if not _hash.has(key):
			_hash[key] = []
		_hash[key].append(k)


## Whether anything within `radius` of `at` is road that isn't within `skip`
## metres along the track of the sample `own` (so a tire stack can sit beside
## its own corner but not on the next bit of road over).
func _near_other_road(at: Vector3, radius: float, own: int, skip: float) -> bool:
	var key := Vector2i(floori(at.x / 16.0), floori(at.z / 16.0))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for k in _hash.get(key + Vector2i(dx, dy), []):
				var along := absf(track.distances[k] - track.distances[own])
				along = minf(along, track.length - along)
				if along < skip:
					continue
				var p := track.points[k]
				if Vector2(p.x - at.x, p.z - at.z).length() < radius:
					return true
	return false


func _free(at: Vector3, radius: float) -> bool:
	if _distance_at(at) < _road_clear + radius:
		return false
	for spot in _placed:
		if Vector2(spot[0].x - at.x, spot[0].z - at.z).length() < spot[1] + radius:
			return false
	for spot in keep_clear:
		if Vector2(spot[0].x - at.x, spot[0].z - at.z).length() < spot[1] + radius:
			return false
	return true


## Which quarter turn faces from `at` toward the road.
func _facing_road(at: Vector3) -> int:
	var c := _cell_of(Vector2(at.x, at.z))
	var i := clampi(c.y, 0, _rows - 1) * _cols + clampi(c.x, 0, _cols - 1)
	var to := _near[i] - Vector2(at.x, at.z)
	return _facing_for(Vector3(to.x, 0.0, to.y))


## The quarter turn whose front (+Z at facing 0) points most along `dir`.
static func _facing_for(dir: Vector3) -> int:
	if absf(dir.x) > absf(dir.z):
		return 1 if dir.x > 0.0 else 3
	return 0 if dir.z > 0.0 else 2


func _add(prop: String, at: Vector3, facing := -1) -> void:
	var f := facing if facing >= 0 else _facing_road(at)
	Props.add(_kit, prop, at, _rng, f)
	_placed.append([at, Props.ROOM.get(prop, 3.0)])


# Along the road.

func _trackside() -> void:
	var edge := track.width * 0.5 + TrackPath.KERB + TrackBuilder.WALL_THICKNESS
	_start_area(edge)
	var tire_top := Color(theme.curbs[0])
	var last_stack := -100.0
	var straight_run := 0.0
	var board_side := 1.0
	var boards := [Color(theme.curbs[0]), Props.BLUE, Props.YELLOW, Props.GREEN, Props.WHITE]
	var corners := 0
	for k in track.points.size():
		var p := track.points[k]
		var d := track.distances[k]
		var ahead := track.forwards[(k + 4) % track.points.size()]
		var behind := track.forwards[(k - 4 + track.points.size()) % track.points.size()]
		# How much the road turns over 8 m, positive turning left. Over 0.2 is
		# a proper corner (tighter than about 40 m), not a gentle slant.
		var turn := behind.cross(ahead).y
		var flat_ground := p.y < 0.6 and track.ups[k].y > 0.95 and track.solids[k] and not track.stickies[k]
		if absf(turn) > 0.2 and flat_ground:
			straight_run = 0.0
			# Tire stacks around the outside of the corner.
			if d - last_stack > 2.2:
				# The outside of a left turn is on the right, and the other way
				# around.
				var outside := signf(turn)
				var spot := p + track.rights[k] * outside * (edge + 0.7)
				spot.y = 0.0
				if not _near_other_road(spot, edge + 0.4, k, 25.0):
					Props.tire_stack(_kit, spot, tire_top if int(d / 2.2) % 2 == 0 else Props.WHITE)
					last_stack = d
				if int(d) % 97 == 0:
					corners += 1
					var post := p + track.rights[k] * outside * (edge + 4.0)
					post.y = 0.0
					if _free(post, 1.5) and not _near_other_road(post, edge + 3.0, k, 25.0):
						Props.marshal_post(_kit, post, _facing_for(p - post))
						_placed.append([post, 1.5])
		elif flat_ground:
			straight_run += 1.0
			if straight_run > 30.0 and int(straight_run) % 40 == 0:
				var spot := p + track.rights[k] * board_side * (edge + 3.5)
				spot.y = 0.0
				if _free(spot, 3.2) and not _near_other_road(spot, edge + 3.0, k, 25.0):
					Props.billboard(_kit, spot, _facing_for(p - spot), boards[_rng.randi() % boards.size()])
					_placed.append([spot, 3.2])
				board_side = -board_side


## Something nasty in the gap of every jump: lava by the volcano, and water
## everywhere else.
func _under_jumps() -> void:
	var lava := track.theme == "volcano"
	for k in range(0, track.points.size(), 1):
		if track.solids[k]:
			continue
		var p := track.points[k]
		var flat_forward := Vector3(track.forwards[k].x, 0.0, track.forwards[k].z).normalized()
		var basis := Basis.looking_at(flat_forward, Vector3.UP)
		var size := Vector3(track.width + 6.0, 0.08, 1.2)
		var at := Vector3(p.x, 0.04, p.z)
		_kit.turned_box(at, size + Vector3(1.0, 0.0, 0.0), basis, Props.BLACK if lava else Props.TAN, SceneryKit.SMOOTH)
		_kit.turned_box(at + Vector3.UP * 0.02, size, basis, Props.LAVA if lava else Props.WATER, SceneryKit.GLOW if lava else SceneryKit.WATER)
		_placed.append([at, 3.0])


## The grandstand and the pit building face each other across the start
## straight, with flags along it. The grandstand goes on the side with more
## room. On some courses other road comes back right beside the start
## straight, so each one is only built where it's clear of all of it, and
## left out if there's no room either side.
func _start_area(edge: float) -> void:
	var frame := track.frame_at(8.0)
	var fwd := -frame.basis.z
	var right := frame.basis.x
	var start_k := track._index_before(8.0)
	var sides: Array[float] = [1.0, -1.0]
	if _distance_at(frame.origin - right * (edge + 12.0)) > _distance_at(frame.origin + right * (edge + 12.0)):
		sides = [-1.0, 1.0]
	var built := 0
	for side in sides:
		if built == 2:
			break
		var front: Vector3 = frame.origin + right * side * (edge + 3.0) - fwd * 4.0
		front.y = 0.0
		if not _clear_of_other_road(front, fwd, -right * side, 32.0, 8.0, start_k):
			continue
		if built == 0:
			Props.grandstand(_kit, front, 30.0, _facing_for(-right * side), _rng)
		else:
			Props.pit_building(_kit, front, 30.0, _facing_for(-right * side))
		_placed.append([front + right * side * 3.5, 17.0])
		built += 1
	for k in 4:
		for side in [-1.0, 1.0]:
			var at: Vector3 = frame.origin + fwd * (18.0 + k * 6.0) + right * side * (edge + 1.5)
			at.y = 0.0
			# The start straight can bend soon after the line, so check all the
			# road, not just other bits of it.
			if not _near_other_road(at, edge + 1.0, start_k, 0.0):
				Props.flag(_kit, at, [Props.RED, Props.YELLOW, Props.BLUE, Props.GREEN][k])


## Whether a building `length` long and `depth` deep, with its front middle at
## `front` running along `along` and going back along `back`, stays clear of
## every bit of road, including the start straight it faces (which isn't
## always straight all the way along).
func _clear_of_other_road(front: Vector3, along: Vector3, back: Vector3, length: float, depth: float, own: int) -> bool:
	var edge := track.width * 0.5 + TrackPath.KERB + TrackBuilder.WALL_THICKNESS + 0.5
	var x := -length * 0.5
	while x <= length * 0.5:
		for d in [0.0, depth * 0.5, depth]:
			if _near_other_road(front + along * x + back * d, edge, own, 0.0):
				return false
		x += 4.0
	return true


# The theme.

func _place_landmark(prop: String) -> void:
	var room: float = Props.ROOM.get(prop, 3.0)
	var best := Vector3.INF
	var best_score := -INF
	for y in _rows:
		for x in _cols:
			var d := _dist[y * _cols + x]
			if d < _road_clear + room or d > _road_clear + room + 45.0:
				continue
			var c := _centre(x, y)
			var at := Vector3(c.x, 0.0, c.y)
			if not _free(at, room):
				continue
			# Close enough to the road to be seen, with a little randomness so
			# they don't all line up the same way.
			var score := -absf(d - (_road_clear + room + 8.0)) + _rng.randf() * 10.0
			if score > best_score:
				best_score = score
				best = at
	if best != Vector3.INF:
		_add(prop, best)


func _fill() -> void:
	var fillers: Dictionary = theme.get("fillers", {})
	var total := 0
	for w in fillers.values():
		total += w
	if total == 0:
		return
	var cells := []
	for i in _dist.size():
		if _dist[i] > _road_clear + 1.5 and _dist[i] < _road_clear + REACH * 0.8:
			cells.append(i)
	# Shuffle with our own seed, so it's the same every time.
	for i in range(cells.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var t = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	var count := 0
	for i in cells:
		if count >= MAX_FILLERS:
			break
		# Denser near the road, where you can see it.
		var d := _dist[i] - _road_clear
		if _rng.randf() > 0.75 - d / (REACH * 1.5):
			continue
		var pick := _rng.randi() % total
		var prop := ""
		for name in fillers:
			pick -= fillers[name]
			if pick < 0:
				prop = name
				break
		var c := _centre(i % _cols, i / _cols)
		var at := Vector3(c.x + _rng.randf_range(-1.0, 1.0), 0.0, c.y + _rng.randf_range(-1.0, 1.0))
		if _free(at, Props.ROOM.get(prop, 3.0)):
			_add(prop, at)
			count += 1
