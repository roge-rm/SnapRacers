class_name TrackPath
extends RefCounted

## A whole track. It's the pieces clicked together one after another, and the
## line down the middle of the road that they make.
##
## I keep the line as samples about a metre apart, each with which way is
## forward, up and right there (so banking and hills come along with it).
## Racing uses it for everything, like where each kart is around the lap,
## which way the AI should head, and where to put a kart back after a reset.

const SAMPLE := 1.0
const HEADINGS := 24
const HEADING_STEP := TAU / HEADINGS
## How far along the road a bend is measured over (see bend_at()).
const BEND_SPAN := 6.0
## Room beside the road's edge line, where the curbs go on the corners.
const KERB := 1.5
## How wide the road is. Eight karts race at once, and this is room for three
## abreast through a bend with some to spare.
const WIDTH := 13.0
## The grid: how far back from the line first place is, how far apart each
## place is, and how far either side of the middle the two columns are.
const GRID_FRONT := 10.0
const GRID_GAP := 7.0
const GRID_ACROSS := 3.5
## About the steepest the hills make the road, as a slope.
const STEEPEST := 0.07

## Grip and drag for each surface, as multiples of plain road. These are for
## the road itself. The ground beside it uses OFFROAD. Mud sits between dirt
## and grass. Shallows is clear water over sand, 1 to 2 m/s slower than sand.
## Grip holds back the speed on sand more than drag does, so its drag is high.
const SURFACES := {
	"asphalt": [1.0, 1.0],
	"dirt": [0.8, 2.0],
	"gravel": [0.82, 1.3],
	"concrete": [0.9, 1.4],
	"grass": [0.7, 5.0],
	"mud": [0.75, 3.5],
	"sand": [0.6, 4.0],
	"ice": [0.35, 0.8],
	"shallows": [0.6, 14.0],
}
## The ground beside the road: slower and slipperier than the same surface as
## a road piece, so running wide costs you. Sand is worse than grass, snow is
## slippy and slow, and a hall floor is in between.
const OFFROAD := {
	"grass": [0.45, 8.0],
	"sand": [0.32, 10.0],
	"dirt": [0.5, 6.0],
	"mud": [0.47, 7.0],
	"snow": [0.4, 7.0],
	"hall": [0.55, 5.0],
	"concrete": [0.55, 5.0],
	"gravel": [0.48, 5.5],
	"ice": [0.28, 3.0],
}

## The road colours a course can have, by id: the name on its tile and the
## colour of the tarmac. The first is the stock grey.
const ROAD_COLOURS := {
	"grey": ["Grey", Color("#6c6e68")],
	"black": ["Black", Color("#3b3c3e")],
	"red": ["Red", Color("#a14a44")],
	"orange": ["Orange", Color("#b87a3e")],
	"yellow": ["Yellow", Color("#b9a54a")],
	"green": ["Green", Color("#4f7f58")],
	"teal": ["Teal", Color("#3f8a8a")],
	"blue": ["Blue", Color("#4a6fa5")],
	"purple": ["Purple", Color("#7d5a9e")],
	"pink": ["Pink", Color("#b5688a")],
}
const STOCK_ROAD := "grey"

var name := "Track"
## Which scenery the course has (see Scenery.THEMES).
var theme := "orchard"
## The tarmac's colour, a key of ROAD_COLOURS.
var road_colour := STOCK_ROAD
## A line about it.
var about := ""
var laps := 3
var width := WIDTH
## How much the ground rises and falls around the course, top to bottom, in
## metres. The road follows it, over gentle hills, and the pieces' own climbs
## (ramps, bridges, crests) go on top. 0 is flat.
var hills := 0.0
## The course's own ground heights, in place of the hills, or null.
var ground: GroundMap
## Clockwise orientation of course maps, in degrees.
var map_rotation := 0.0
## The weather and time of day it's raced in, unless the player picks (see
## Conditions). RANDOM leaves them to chance.
var weather := Conditions.RANDOM
var time := Conditions.RANDOM
## Whether `time` is the only time of day it's raced at.
var fixed_time := false
## Landmarks put down by hand in the track editor, as
## { "prop": ..., "at": [x, z], "facing": 0 to 3 }. With none, the theme
## picks its own.
var landmarks: Array = []
## Painted ground: lakes, lava, mud (see PaintedAreas).
var paint := PaintedAreas.new()
## Lakes and rivers of water and lava (see Waters).
var waters := Waters.new()
var pieces: Array[TrackPiece] = []
var start := Transform3D.IDENTITY
## Where each piece starts, in the world.
var piece_starts: Array[Transform3D] = []
## Whether the last piece comes back around to meet the first.
var closes := false
var mirrored := false
var reversed := false
var _layout_applied := false

var points := PackedVector3Array()
var forwards := PackedVector3Array()
var ups := PackedVector3Array()
var rights := PackedVector3Array()
var distances := PackedFloat32Array()
## See _make_lookups().
var _metre_index := PackedInt32Array()
var _bends := PackedFloat32Array()
## Whether each sample is on a loop or a corkscrew.
var _over := PackedByteArray()
var solids: Array[bool] = []
var stickies: Array[bool] = []
var piece_of := PackedInt32Array()
## The road's two branches at each sample, as TrackPiece.branches() gives
## them: Vector2(middle right of the line, width). Off a split both are the
## whole road.
var branch_lefts := PackedVector2Array()
var branch_rights := PackedVector2Array()
## How far through its piece each sample is, from 0 to 1.
var piece_ts := PackedFloat32Array()
## Whether any piece is a split.
var has_splits := false
## Whether it has a loop or a corkscrew: -1 until has_turns_over() looks.
var _turns_over := -1
var _corkscrew := -1
## How high the road's ground is under each sample (see road_ground()).
var grounds := PackedFloat32Array()
var length := 0.0
var _noise: FastNoiseLite
## See racing_line(). Made when first asked for, dropped by build().
var _line: RacingLine


static func load_file(path: String) -> TrackPath:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("I couldn't read the track at %s" % path)
		return TrackPath.new()
	return from_dict(data)


static func from_dict(data: Dictionary) -> TrackPath:
	var track := TrackPath.new()
	track.name = str(data.get("name", "Track"))
	track.theme = str(data.get("theme", "orchard"))
	var road_pick := str(data.get("road_colour", STOCK_ROAD))
	track.road_colour = road_pick if ROAD_COLOURS.has(road_pick) else STOCK_ROAD
	track.about = str(data.get("about", ""))
	track.laps = int(data.get("laps", 3))
	track.width = float(data.get("width", WIDTH))
	track.hills = float(data.get("hills", 0.0))
	track.map_rotation = fposmod(float(data.get("map_rotation", 0.0)), 360.0)
	track.weather = str(data.get("weather", Conditions.RANDOM))
	track.time = str(data.get("time", Conditions.RANDOM))
	track.fixed_time = bool(data.get("fixed_time", false))
	track.landmarks = data.get("landmarks", []).duplicate(true)
	track.start = start_from(data.get("start", []))
	track.paint = PaintedAreas.from_dict(data.get("paint"), growth(data))
	track.ground = GroundMap.from_dict(data.get("ground"), growth(data))
	track.waters = Waters.read_course(data, track.paint, track.ground)
	# A course made before the tiles were kart sized has the same pieces twice
	# as big, so where it starts and its landmarks move out to match.
	var grow := growth(data)
	if grow != 1.0:
		track.width = WIDTH
		track.start.origin *= Vector3(grow, 1.0, grow)
		track.landmarks = grown_landmarks(track.landmarks, grow)
	for spec in data.get("pieces", []):
		track.pieces.append(TrackPiece.from_spec(spec))
	track.build()
	return track


## Where the start line is, from a course file's [x, y, z, quarter turns].
## The courses that come with the game start at the middle of the map.
static func start_from(spec: Array) -> Transform3D:
	if spec.size() < 4:
		return Transform3D.IDENTITY
	return Transform3D(Basis(Vector3.UP, float(spec[3]) * PI * 0.5), Vector3(float(spec[0]), float(spec[1]), float(spec[2])))


## The connector heading, or -1 for a basis outside the 15 degree set.
static func heading_of(basis: Basis) -> int:
	if not basis.is_finite():
		return -1
	var yaw := atan2(basis.z.x, basis.z.z)
	if not is_finite(yaw):
		return -1
	var heading := posmod(roundi(yaw / HEADING_STEP), HEADINGS)
	var canonical := heading_basis(heading)
	if basis.x.distance_to(canonical.x) > 0.00001 or basis.y.distance_to(canonical.y) > 0.00001 or basis.z.distance_to(canonical.z) > 0.00001:
		return -1
	return heading


static func heading_basis(heading: int) -> Basis:
	return Basis(Vector3.UP, (posmod(heading + HEADINGS / 2, HEADINGS) - HEADINGS / 2) * HEADING_STEP)


## Joins the real endpoint and rebuilds the next rigid connector basis.
static func advance_pose(pose: Transform3D, piece: TrackPiece) -> Transform3D:
	var heading := heading_of(pose.basis)
	if heading < 0:
		push_error("Track connectors must face a multiple of 15 degrees")
		return pose
	return Transform3D(heading_basis(heading + piece.heading_delta()), pose * piece.exit().origin)


func to_dict() -> Dictionary:
	var specs := []
	for piece in pieces:
		specs.append(piece.to_spec())
	var out := { "name": name, "theme": theme, "about": about, "laps": laps, "width": width, "grid": TrackPiece.TILE, "pieces": specs }
	if ground != null:
		out.ground = ground.to_dict()
	elif hills > 0.0:
		out.hills = hills
	if not waters.is_empty():
		out.water = waters.to_dict()
	if road_colour != STOCK_ROAD:
		out.road_colour = road_colour
	if map_rotation != 0.0:
		out.map_rotation = map_rotation
	if weather != Conditions.RANDOM:
		out.weather = weather
	if time != Conditions.RANDOM:
		out.time = time
	if fixed_time:
		out.fixed_time = true
	return out


## Applies the optional race layout once, then rebuilds the sampled path.
func apply_layout(mirrored_: bool, reversed_: bool) -> void:
	if _layout_applied or (not mirrored_ and not reversed_):
		return
	_layout_applied = true
	mirrored = mirrored_
	reversed = reversed_
	if mirrored:
		_mirror_layout()
		waters.flip_all(_laid_out)
	if reversed:
		pieces.reverse()
		for piece in pieces:
			piece.invert()
		start.basis = start.basis * heading_basis(HEADINGS / 2)
	build()


func _mirror_layout() -> void:
	for piece in pieces:
		piece.mirror()
	for mark in landmarks:
		var at: Array = mark.get("at", [0.0, 0.0])
		if at.size() < 2:
			continue
		var world := Vector3(float(at[0]), start.origin.y, float(at[1]))
		var local := start.basis.inverse() * (world - start.origin)
		local.x = -local.x
		world = start.origin + start.basis * local
		mark.at = [world.x, world.z]
		var facing := int(mark.get("facing", 0))
		var direction := Basis(Vector3.UP, facing * PI * 0.5) * Vector3.FORWARD
		var local_direction := start.basis.inverse() * direction
		local_direction.x = -local_direction.x
		direction = start.basis * local_direction
		mark.facing = posmod(roundi(-atan2(direction.x, direction.z) / (PI * 0.5)), 4)


## Whether the ground rises and falls, from the hills or a map.
## The painted ground with the squares of old lakes that kept them (see
## Waters.old_squares()).
func all_paint() -> PaintedAreas:
	var old := waters.old_squares()
	if old.is_empty():
		return paint
	var all := paint.duplicate_areas()
	for square: Vector2i in old.squares:
		if not all.squares.has(square):
			all.squares[square] = old.squares[square]
	return all


func has_relief() -> bool:
	return ground != null or hills > 0.0


## How high the ground is here, in metres above (or below) the start: the
## map where there is one, or the hills. The hills are smooth and long, so
## the road never climbs or drops more steeply than about STEEPEST, however
## high they are. They're the same every time for a course of this name.
func ground_height(x: float, z: float) -> float:
	if ground != null:
		var at := _laid_out(x, z)
		return ground.height_at(at.x, at.y)
	if hills <= 0.0:
		return 0.0
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.seed = hash(name)
		_noise.fractal_octaves = 2
		# How far apart the hilltops are, so the slopes stay gentle.
		var half := hills * 0.9
		_noise.frequency = minf(STEEPEST / (half * 4.4), 1.0 / 150.0)
	var sample := _laid_out(x, z)
	return (_noise.get_noise_2d(sample.x, sample.y) - _noise.get_noise_2d(start.origin.x, start.origin.z)) * hills * 0.9


## The ground the road follows here: the map's smoothed road copy (see
## GroundMap.road()), or the hills.
func road_ground(x: float, z: float) -> float:
	if ground != null:
		var at := _laid_out(x, z)
		return ground.road().height_at(at.x, at.y)
	return ground_height(x, z)


## Where a point of the race layout is on the course as made: mirrored
## courses read the ground mirrored around the start.
func laid_out(x: float, z: float) -> Vector2:
	return _laid_out(x, z)


func _laid_out(x: float, z: float) -> Vector2:
	if not mirrored:
		return Vector2(x, z)
	var local := start.basis.inverse() * (Vector3(x, start.origin.y, z) - start.origin)
	local.x = -local.x
	var sample := start.origin + start.basis * local
	return Vector2(sample.x, sample.z)


## How much bigger a course file's tiles are now than when it was made.
static func growth(data: Dictionary) -> float:
	return TrackPiece.TILE / float(data.get("grid", TrackPiece.OLD_TILE))


static func grown_landmarks(marks: Array, grow: float) -> Array:
	var out := []
	for mark in marks:
		var moved: Dictionary = mark.duplicate(true)
		var at: Array = moved.get("at", [0.0, 0.0])
		if at.size() >= 2:
			moved.at = [float(at[0]) * grow, float(at[1]) * grow]
		out.append(moved)
	return out


## Clicks the pieces together and samples the line down the middle.
func build() -> void:
	_turns_over = -1
	_corkscrew = -1
	_line = null
	points.clear()
	forwards.clear()
	ups.clear()
	rights.clear()
	distances.clear()
	solids.clear()
	stickies.clear()
	piece_of.clear()
	branch_lefts.clear()
	branch_rights.clear()
	piece_ts.clear()
	has_splits = false
	piece_starts.clear()
	grounds.clear()
	var end := start
	for piece in pieces:
		end = advance_pose(end, piece)
	closes = not pieces.is_empty() and end.origin.distance_to(start.origin) < 0.5 \
		and (-end.basis.z).dot(-start.basis.z) > 0.999
	var pose := start
	for i in pieces.size():
		var piece := pieces[i]
		piece_starts.append(pose)
		var steps := maxi(2, ceili(piece.path_length() / SAMPLE))
		# Open road includes its final connector; closed road joins the first sample.
		var count := steps + (1 if i == pieces.size() - 1 and not closes else 0)
		for k in count:
			var t := float(k) / steps
			var t_ahead := minf(t + 0.001, 1.0)
			var t_behind := maxf(t - 0.001, 0.0)
			var ahead := pose * piece.point(t_ahead) + Vector3.UP * _hill(pose, piece, t_ahead)
			var behind := pose * piece.point(t_behind) + Vector3.UP * _hill(pose, piece, t_behind)
			# Banked road climbs as it leans (see the rise below), so forward
			# climbs with it, or the road's up would lean back off the surface.
			var base_ahead := (pose.basis * piece.up(t_ahead)).normalized()
			var base_behind := (pose.basis * piece.up(t_behind)).normalized()
			ahead += base_ahead * _rise(piece.bank_at(t_ahead))
			behind += base_behind * _rise(piece.bank_at(t_behind))
			var forward := (ahead - behind).normalized()
			if piece.type in TrackPiece.ADJUSTABLE_TYPES:
				# Short pieces keep their tangent when far from the world origin.
				var local_delta := pose.basis * (piece.point(t_ahead) - piece.point(t_behind))
				var ground_delta := _hill(pose, piece, t_ahead) - _hill(pose, piece, t_behind)
				forward = (local_delta + Vector3.UP * ground_delta).normalized()
			# Flat connectors use their rigid heading at both ends of a piece.
			if not has_relief() and piece.bank == 0.0 and (k == 0 or k == steps):
				forward = -(pose.basis * piece.exit().basis).z if k == steps else -pose.basis.z
			var hill := _hill(pose, piece, t)
			var base_up := (pose.basis * piece.up(t)).normalized()
			var flat_right := forward.cross(base_up).normalized()
			var flat_up := flat_right.cross(forward)
			var lean := piece.bank_at(t)
			var up := flat_up * cos(lean) + flat_right * sin(lean)
			# Banked road leans up from its low edge instead of around its
			# middle, so the inside edge stays at road height instead of
			# sinking into the ground.
			var rise := _rise(lean)
			points.append(pose * piece.point(t) + Vector3.UP * hill + flat_up * rise)
			grounds.append(hill)
			forwards.append(forward)
			ups.append(up)
			rights.append(forward.cross(up))
			solids.append(piece.solid(t))
			stickies.append(piece.sticky)
			piece_of.append(i)
			var two := piece.branches(t, width)
			branch_lefts.append(two[0])
			branch_rights.append(two[1])
			piece_ts.append(t)
			has_splits = has_splits or piece.is_split()
		pose = advance_pose(pose, piece)

	var total := 0.0
	for k in points.size():
		distances.append(total)
		total += points[k].distance_to(points[(k + 1) % points.size()])
	length = total
	_make_lookups()


## Tables that make looking things up along the track quick, since the AI
## does it dozens of times a step for every driver: the sample at or before
## each whole metre, and how much the road bends at each sample.
func _make_lookups() -> void:
	_metre_index.resize(int(length) + 2)
	var i := 0
	for m in _metre_index.size():
		while i + 1 < distances.size() and distances[i + 1] <= m:
			i += 1
		_metre_index[m] = i
	_bends.resize(points.size())
	_over.resize(points.size())
	for k in points.size():
		_bends[k] = _bend_between(distances[k])
		_over[k] = 1 if TrackPiece.turns_over(pieces[piece_of[k]].type) else 0


## How far banked road leaning this much lifts its middle, since it leans up
## from its low edge.
func _rise(lean: float) -> float:
	return (width * 0.5 + KERB) * absf(sin(lean))


## How high the hills lift the road `t` of the way through a piece. Loops and
## jumps only lean with the hill from one end to the other, so their shape
## stays as it was made.
func _hill(pose: Transform3D, piece: TrackPiece, t: float) -> float:
	if not has_relief():
		return 0.0
	if TrackPiece.turns_over(piece.type) or piece.type in ["jump", "jump_split"]:
		var from := pose.origin
		var to := (pose * piece.exit()).origin
		return lerpf(road_ground(from.x, from.z), road_ground(to.x, to.z), t)
	var p := pose * piece.point(t)
	return road_ground(p.x, p.z)


func _index_before(offset: float) -> int:
	var d := fposmod(offset, length)
	var i := _metre_index[int(d)] if int(d) < _metre_index.size() else 0
	while i + 1 < distances.size() and distances[i + 1] <= d:
		i += 1
	return i


## How far `offset` is from sample i to sample j, from 0 to 1.
func _blend(offset: float, i: int, j: int) -> float:
	var span := (distances[j] if j != 0 else length) - distances[i]
	return clampf((fposmod(offset, length) - distances[i]) / maxf(span, 0.0001), 0.0, 1.0)


## Whether it has a loop or a corkscrew anywhere, worked out once.
func has_turns_over() -> bool:
	if _turns_over < 0:
		_turns_over = 0
		for piece in pieces:
			if TrackPiece.turns_over(piece.type):
				_turns_over = 1
	return _turns_over == 1


## Whether it has a corkscrew anywhere, worked out once.
func has_corkscrew() -> bool:
	if _corkscrew < 0:
		_corkscrew = 0
		for piece in pieces:
			if piece.type == "corkscrew":
				_corkscrew = 1
	return _corkscrew == 1


## What kind of piece of track is at this distance around it, like
## "straight" or "jump".
func piece_type_at(offset: float) -> String:
	if piece_of.is_empty():
		return ""
	return pieces[piece_of[_index_before(offset)]].type


func point_at(offset: float) -> Vector3:
	var i := _index_before(offset)
	var j := (i + 1) % points.size()
	return points[i].lerp(points[j], _blend(offset, i, j))


func forward_at(offset: float) -> Vector3:
	var i := _index_before(offset)
	var j := (i + 1) % points.size()
	return forwards[i].lerp(forwards[j], _blend(offset, i, j)).normalized()


func up_at(offset: float) -> Vector3:
	var i := _index_before(offset)
	var j := (i + 1) % points.size()
	return ups[i].lerp(ups[j], _blend(offset, i, j)).normalized()


func right_at(offset: float) -> Vector3:
	var i := _index_before(offset)
	var j := (i + 1) % points.size()
	return rights[i].lerp(rights[j], _blend(offset, i, j)).normalized()


func solid_at(offset: float) -> bool:
	return solids[_index_before(offset)]


## Whether the road here lies on the ground, no more than `raised` above it
## and not sticky or leaning on a bank (see TrackBuilder._raised()).
func grounded_at(offset: float, raised: float) -> bool:
	var k := _index_before(offset)
	return solids[k] and not stickies[k] and ups[k].y >= 0.985 \
		and points[k].y - grounds[k] <= raised


## The road's own frame here, with -Z along the track, Y up off the road and X
## to the right.
func frame_at(offset: float) -> Transform3D:
	var forward := forward_at(offset)
	var up := up_at(offset)
	var right := forward.cross(up).normalized()
	return Transform3D(Basis(right, right.cross(forward), -forward), point_at(offset))


## Include the samples just outside a distance window, even on short pieces.
func _sample_window(hint: float, window: float) -> Vector2i:
	var count := points.size()
	if window * 2.0 >= length:
		return Vector2i(0, count)
	var first := _index_before(hint - window)
	var last := _index_before(hint + window)
	return Vector2i(first, mini(count, posmod(last - first, count) + 2))


## How far along the track a position is. With a hint (where it was a moment
## ago) it only looks nearby, so a kart on a bridge isn't mistaken for one on
## the road underneath, or the other way around.
func offset_of(position: Vector3, hint := -1.0, window := 60.0) -> float:
	var count := points.size()
	var first := 0
	var steps := count
	if hint >= 0.0:
		var bounds := _sample_window(hint, window)
		first = bounds.x
		steps = bounds.y
	var best := first
	var best_distance := INF
	for n in steps:
		var k := (first + n) % count
		var d := points[k].distance_squared_to(position)
		if d < best_distance:
			best_distance = d
			best = k
	return _slide_along(position, best)


## offset_of() with a hint, for something that moves under a metre a step,
## like a kart. It looks `near` either side of the hint, and only if the
## nearest sample there is at either end, or further off the middle of the
## road than its edge, does it look `far` either side instead. So it finds
## the same as offset_of(position, hint, far) on the road and costs much less.
func offset_near(position: Vector3, hint: float, near: float, far: float) -> float:
	if hint < 0.0:
		return offset_of(position)
	var count := points.size()
	var bounds := _sample_window(hint, near)
	var first := bounds.x
	var steps := bounds.y
	var best := 0
	var best_distance := INF
	for n in steps:
		var d := points[(first + n) % count].distance_squared_to(position)
		if d < best_distance:
			best_distance = d
			best = n
	var edge := outer_half((first + best) % count) + KERB
	if best == 0 or best == steps - 1 or best_distance > edge * edge:
		return offset_of(position, hint, far)
	return _slide_along(position, (first + best) % count)


## How far along the track a position is, from the sample nearest to it, by
## sliding along the segment on either side of that sample.
func _slide_along(position: Vector3, best: int) -> float:
	var count := points.size()
	var result := distances[best]
	var best_along := INF
	# The segment before it first, then the one after.
	for side in 2:
		var a := best if side == 1 else (best - 1 + count) % count
		var b := (a + 1) % count
		var seg := points[b] - points[a]
		var along := clampf((position - points[a]).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
		var d := (points[a] + seg * along).distance_squared_to(position)
		if d < best_along:
			best_along = d
			result = distances[a] + seg.length() * along
	return fposmod(result, length)


## How sharply the track bends here, as one over the corner's radius. Hills
## count as well as turns, because both matter for how fast a kart can take
## them.
func curvature_at(offset: float, span := 6.0) -> float:
	var a := forward_at(offset - span * 0.5)
	var b := forward_at(offset + span * 0.5)
	return a.angle_to(b) / span


## How sharply the track turns left or right here, ignoring hills and
## loops, as one over the corner's radius. This is what limits how fast a
## kart can get around.
func bend_at(offset: float, span := BEND_SPAN) -> float:
	if span == BEND_SPAN and not _bends.is_empty():
		var i := _index_before(offset)
		var j := (i + 1) % points.size()
		return lerpf(_bends[i], _bends[j], _blend(offset, i, j))
	return _bend_between(offset, span)


## bend_at() every `step` metres from `offset + step` out to `offset + reach`,
## into the start of `out`, with 0 on loops and corkscrews, since those are no
## bend to slow down for. It returns how many it put in. The AI's braking
## looks down the road with it every step, so it keeps `out` from one step
## to the next instead of making a new one.
func corner_bends(offset: float, step: float, reach: float, out: PackedFloat64Array) -> int:
	var count := points.size()
	var n := 0
	var ahead := step
	while ahead <= reach:
		if n >= out.size():
			out.resize(n + 8)
		var d := fposmod(offset + ahead, length)
		var i := _metre_index[int(d)] if int(d) < _metre_index.size() else 0
		while i + 1 < count and distances[i + 1] <= d:
			i += 1
		if _over[i] == 1:
			out[n] = 0.0
		else:
			var j := (i + 1) % count
			var gap := (distances[j] if j != 0 else length) - distances[i]
			out[n] = lerpf(_bends[i], _bends[j], clampf((d - distances[i]) / maxf(gap, 0.0001), 0.0, 1.0))
		n += 1
		ahead += step
	return n


## The racing line, worked out the first time it's asked for (see
## RacingLine). Ask after apply_layout(), since that builds the road again.
func racing_line() -> RacingLine:
	if _line == null:
		_line = RacingLine.new(self)
	return _line


## How far right of the middle the racing line is here, in metres. Left is
## negative. `branches` picks a branch for each split, 0 left and 1 right,
## in the order they come round the lap (see RacingLine.split_mids); a split
## with no pick takes the quicker one.
func line_offset_at(offset: float, branches := PackedInt32Array()) -> float:
	var line := racing_line()
	var i := _index_before(offset)
	var j := (i + 1) % points.size()
	return lerpf(line.side_offsets[line.side_of(i, branches)][i], line.side_offsets[line.side_of(j, branches)][j], _blend(offset, i, j))


## The racing line here, on the road.
func line_point_at(offset: float, branches := PackedInt32Array()) -> Vector3:
	return point_at(offset) + right_at(offset) * line_offset_at(offset, branches)


## How sharply the racing line turns here, as one over its radius, like
## bend_at() is for the middle of the road.
func line_bend_at(offset: float, branches := PackedInt32Array()) -> float:
	var line := racing_line()
	var i := _index_before(offset)
	var j := (i + 1) % points.size()
	return lerpf(line.side_bends[line.side_of(i, branches)][i], line.side_bends[line.side_of(j, branches)][j], _blend(offset, i, j))


## corner_bends() for the racing line: its bend every `step` metres from
## `offset + step` out to `offset + reach`, 0 on loops and corkscrews.
func line_corner_bends(offset: float, step: float, reach: float, out: PackedFloat64Array, branches := PackedInt32Array()) -> int:
	var line := racing_line()
	var count := points.size()
	var n := 0
	var ahead := step
	while ahead <= reach:
		if n >= out.size():
			out.resize(n + 8)
		var d := fposmod(offset + ahead, length)
		var i := _metre_index[int(d)] if int(d) < _metre_index.size() else 0
		while i + 1 < count and distances[i + 1] <= d:
			i += 1
		if _over[i] == 1:
			out[n] = 0.0
		else:
			var j := (i + 1) % count
			var gap := (distances[j] if j != 0 else length) - distances[i]
			out[n] = lerpf(line.side_bends[line.side_of(i, branches)][i], line.side_bends[line.side_of(j, branches)][j], clampf((d - distances[i]) / maxf(gap, 0.0001), 0.0, 1.0))
		n += 1
		ahead += step
	return n


func _bend_between(offset: float, span := BEND_SPAN) -> float:
	var a := forward_at(offset - span * 0.5)
	var b := forward_at(offset + span * 0.5)
	# It's measured across the road itself, so the way a loop curls over the
	# top doesn't count as a bend but a wall ride does.
	var up := up_at(offset)
	a = (a - up * a.dot(up)).normalized()
	b = (b - up * b.dot(up)).normalized()
	return absf(a.signed_angle_to(b, up)) / span


## The road across at sample k, as [from, to] in metres right of the middle
## line: one stretch on ordinary road, two where a split has parted round its
## island.
func lanes_of(k: int) -> PackedVector2Array:
	return _lanes(branch_lefts[k], branch_rights[k])


## lanes_of() between samples, anywhere around the lap.
func lanes_at(offset: float) -> PackedVector2Array:
	if not has_splits:
		return PackedVector2Array([Vector2(-width * 0.5, width * 0.5)])
	var i := _index_before(offset)
	var j := (i + 1) % points.size()
	var f := _blend(offset, i, j)
	return _lanes(branch_lefts[i].lerp(branch_lefts[j], f), branch_rights[i].lerp(branch_rights[j], f))


static func _lanes(left: Vector2, right: Vector2) -> PackedVector2Array:
	var a := Vector2(left.x - left.y * 0.5, left.x + left.y * 0.5)
	var b := Vector2(right.x - right.y * 0.5, right.x + right.y * 0.5)
	if a.y >= b.x:
		return PackedVector2Array([Vector2(minf(a.x, b.x), maxf(a.y, b.y))])
	return PackedVector2Array([a, b])


## How far out the road's furthest edge is from the middle line at sample k,
## on either side. It's half the road's width except on a split.
func outer_half(k: int) -> float:
	if not has_splits:
		return width * 0.5
	var left := branch_lefts[k]
	var right := branch_rights[k]
	return maxf(-(left.x - left.y * 0.5), right.x + right.y * 0.5)


## How far right of the middle line a split's branch runs here, 0 for the
## left and 1 for the right: the middle of the road off a split.
func branch_centre_at(offset: float, side: int) -> float:
	if not has_splits:
		return 0.0
	var i := _index_before(offset)
	var j := (i + 1) % points.size()
	var ends := branch_lefts if side == 0 else branch_rights
	return lerpf(ends[i].x, ends[j].x, _blend(offset, i, j))


## Which branch `across` metres right of the middle line is nearer here, 0
## the left and 1 the right.
func branch_of(offset: float, across: float) -> int:
	return 1 if absf(across - branch_centre_at(offset, 1)) < absf(across - branch_centre_at(offset, 0)) else 0


## Whether this sample is on a split piece.
func split_sample(k: int) -> bool:
	return has_splits and pieces[piece_of[k]].is_split()


## How high branch `side` (0 left, 1 right) is above the middle line at
## sample k: up on a jump split's kicker or landing, and 0 everywhere else.
func branch_lift(k: int, side: int) -> float:
	return pieces[piece_of[k]].branch_lift(piece_ts[k], side) if has_splits else 0.0


## Whether branch `side` has road at sample k, which only a jump split's
## jump doesn't over its gap.
func branch_solid(k: int, side: int) -> bool:
	return pieces[piece_of[k]].branch_solid(piece_ts[k], side) if has_splits else solids[k]


## The surface of branch `side` at sample k.
func branch_surface(k: int, side: int) -> String:
	return pieces[piece_of[k]].branch_surface(side)


## Whether branch `side` lies flat on the ground at sample k, with no
## kicker, landing or gap.
func branch_flat(k: int, side: int) -> bool:
	return branch_lift(k, side) < 0.01 and branch_solid(k, side)


## Whether `across` metres right of the middle line is on the road here, at
## least `margin` in from its edges.
func on_road_across(offset: float, across: float, margin := 0.0) -> bool:
	for lane in lanes_at(offset):
		if across >= lane.x + margin and across <= lane.y - margin:
			return true
	return false


## The nearest spot to `across` that's on the road here, at least `margin` in
## from its edges, in metres right of the middle line. It never lands on a
## split's island.
func nearest_road_across(offset: float, across: float, margin := 0.0) -> float:
	var best := across
	var best_gap := INF
	for lane in lanes_at(offset):
		var lo := minf(lane.x + margin, (lane.x + lane.y) * 0.5)
		var hi := maxf(lane.y - margin, (lane.x + lane.y) * 0.5)
		var at := clampf(across, lo, hi)
		if absf(at - across) < best_gap:
			best_gap = absf(at - across)
			best = at
	return best


## Where across the road to try putting a kart back, in metres right of the
## middle line, best first. On a split it's the branch nearer `across`, then
## the other one.
func reset_spots(offset: float, across: float) -> Array[float]:
	var out: Array[float] = [0.0, -3.0, 3.0, -4.5, 4.5]
	var lanes := lanes_at(offset)
	if not has_splits or (lanes.size() < 2 and not split_sample(_index_before(offset))):
		return out
	var i := _index_before(offset)
	var j := (i + 1) % points.size()
	var centres := [branch_lefts[i].x, branch_rights[i].x]
	# Never back onto a jump's kicker, landing or gap: the other branch.
	var flat := [branch_flat(i, 0) and branch_flat(j, 0), branch_flat(i, 1) and branch_flat(j, 1)]
	if not flat[0] and flat[1]:
		centres = [centres[1]]
	elif not flat[1] and flat[0]:
		centres = [centres[0]]
	elif absf(across - centres[1]) < absf(across - centres[0]):
		centres.reverse()
	out.clear()
	for centre: float in centres:
		for side: float in [0.0, -2.5, 2.5]:
			out.append(nearest_road_across(offset, centre + side, 1.6))
	return out


## Where along the lap each level crossing's railway goes over the road, in
## metres, in the order they come around the lap.
func crossing_offsets() -> Array[float]:
	var out: Array[float] = []
	var from := 0
	for i in pieces.size():
		if not pieces[i].crossing:
			continue
		while from < piece_of.size() and piece_of[from] < i:
			from += 1
		if from < piece_of.size():
			out.append(distances[from] + pieces[i].path_length() * 0.5)
	return out


## The road here, lifted a little, facing along the track. Resets put karts
## here.
func place_at(offset: float, lift := 0.6) -> Transform3D:
	var frame := frame_at(offset)
	frame.origin += frame.basis.y * lift
	return frame


## Grid spots behind the start line, in two staggered columns with first
## place at the front.
func grid_slot(index: int) -> Transform3D:
	var offset := length - GRID_FRONT - index * GRID_GAP
	var frame := place_at(offset, 0.05)
	frame.origin += frame.basis.x * (-1.0 if index % 2 == 0 else 1.0) * GRID_ACROSS
	return frame


func grip_and_drag(surface: String) -> Array:
	return SURFACES.get(surface, SURFACES["asphalt"])


## Grip and drag off the road, for the ground beside it.
func offroad_grip_and_drag(surface: String) -> Array:
	return OFFROAD.get(surface, OFFROAD["grass"])


## How far apart the nearest edges of the road at samples i and j are, flat,
## going by each split branch's own middle and width.
func _branch_gap(i: int, j: int) -> float:
	var best := INF
	for here: Vector2 in [branch_lefts[i], branch_rights[i]]:
		var p := points[i] + rights[i] * here.x
		for there: Vector2 in [branch_lefts[j], branch_rights[j]]:
			var q := points[j] + rights[j] * there.x
			best = minf(best, Vector2(p.x - q.x, p.z - q.z).length() - (here.y + there.y) * 0.5)
	return best


## Places where two bits of road that aren't next to each other along the
## track come too close without one being well above the other. Ground-level
## crossings can be allowed for courses built in the editor. Each is [offset, offset].
func clashes(clearance := 5.0, allow_ground_crossings := false) -> Array:
	var out := []
	var step := 4
	# Road, curbs and a half metre wall on each side. Any closer and the walls
	# would overlap. A loop's way in and way out sit 1 m apart wall to wall,
	# which is fine.
	var reach := width + 2.0 * KERB + 1.0
	var skip := reach * 2.0
	var count := points.size()
	# Banked road needs headroom across its rolled road, kerbs and walls.
	# Loops and corkscrews keep their own clearance rules.
	var spread := PackedFloat64Array()
	spread.resize(count)
	var ground_crossing := PackedByteArray()
	ground_crossing.resize(count)
	for i in count:
		var piece := pieces[piece_of[i]]
		if allow_ground_crossings:
			ground_crossing[i] = int(piece.type in ["straight", "half_straight", "quarter_straight", "adjustable_straight", "adjustable_offset", "connector", "curve", "arc", "slant"] \
				and piece.rise == 0.0 and piece.bank == 0.0 and not piece.forced_walls() \
				and not stickies[i] and ups[i].y >= 0.985 and absf(points[i].y - grounds[i]) < 0.1)
		if piece.type in ["curve", "arc"] and piece.bank != 0.0:
			spread[i] = absf(rights[i].y) * (width * 0.5 + KERB + 0.5)
	for i in range(0, count, step):
		for j in range(i + step, count, step):
			var along := distances[j] - distances[i]
			if along < skip or length - along < skip:
				continue
			if ground_crossing[i] and ground_crossing[j]:
				continue
			var a := points[i]
			var b := points[j]
			var flat := Vector2(a.x - b.x, a.z - b.z).length()
			# A split's branches are measured from where each branch runs.
			if has_splits and (split_sample(i) or split_sample(j)):
				flat = _branch_gap(i, j) + width
			if flat < reach and absf(a.y - b.y) < clearance + spread[i] + spread[j]:
				out.append([distances[i], distances[j]])
	return out
