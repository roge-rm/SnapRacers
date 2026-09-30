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

## Grip and drag for each surface, as multiples of plain road.
const SURFACES := {
	"asphalt": [1.0, 1.0],
	"dirt": [0.8, 2.0],
	"gravel": [0.82, 1.3],
	"concrete": [0.9, 1.4],
	"grass": [0.7, 5.0],
	"sand": [0.6, 4.0],
	"ice": [0.35, 0.8],
}

var name := "Track"
## Which scenery the course has (see Scenery.THEMES).
var theme := "orchard"
## The real kart circuit it's based on, and a line about it.
var inspired_by := ""
var about := ""
var laps := 3
var width := WIDTH
## How much the ground rises and falls around the course, top to bottom, in
## metres. The road follows it, over gentle hills, and the pieces' own climbs
## (ramps, bridges, crests) go on top. 0 is flat.
var hills := 0.0
## Landmarks put down by hand in the track editor, as
## { "prop": ..., "at": [x, z], "facing": 0 to 3 }. With none, the theme
## picks its own.
var landmarks: Array = []
var pieces: Array[TrackPiece] = []
var start := Transform3D.IDENTITY
## Where each piece starts, in the world.
var piece_starts: Array[Transform3D] = []
## Whether the last piece comes back around to meet the first.
var closes := false

var points := PackedVector3Array()
var forwards := PackedVector3Array()
var ups := PackedVector3Array()
var rights := PackedVector3Array()
var distances := PackedFloat32Array()
var solids: Array[bool] = []
var stickies: Array[bool] = []
var piece_of := PackedInt32Array()
## How high the hills are under each sample (see ground_height()).
var grounds := PackedFloat32Array()
var length := 0.0
var _noise: FastNoiseLite


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
	track.inspired_by = str(data.get("inspired_by", ""))
	track.about = str(data.get("about", ""))
	track.laps = int(data.get("laps", 3))
	track.width = float(data.get("width", WIDTH))
	track.hills = float(data.get("hills", 0.0))
	track.landmarks = data.get("landmarks", []).duplicate(true)
	track.start = start_from(data.get("start", []))
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


func to_dict() -> Dictionary:
	var specs := []
	for piece in pieces:
		specs.append(piece.to_spec())
	var out := { "name": name, "theme": theme, "inspired_by": inspired_by, "about": about, "laps": laps, "width": width, "grid": TrackPiece.TILE, "pieces": specs }
	if hills > 0.0:
		out.hills = hills
	return out


## How high the hills are here, in metres above (or below) the start. The
## hills are smooth and long, so the road never climbs or drops more steeply
## than about STEEPEST, however high they are. They're the same every time for
## a course of this name.
func ground_height(x: float, z: float) -> float:
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
	return (_noise.get_noise_2d(x, z) - _noise.get_noise_2d(start.origin.x, start.origin.z)) * hills * 0.9


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
	points.clear()
	forwards.clear()
	ups.clear()
	rights.clear()
	distances.clear()
	solids.clear()
	stickies.clear()
	piece_of.clear()
	piece_starts.clear()
	grounds.clear()
	var pose := start
	for i in pieces.size():
		var piece := pieces[i]
		piece_starts.append(pose)
		var steps := maxi(2, ceili(piece.path_length() / SAMPLE))
		for k in steps:
			var t := float(k) / steps
			var t_ahead := minf(t + 0.001, 1.0)
			var t_behind := maxf(t - 0.001, 0.0)
			var ahead := pose * piece.point(t_ahead) + Vector3.UP * _hill(pose, piece, t_ahead)
			var behind := pose * piece.point(t_behind) + Vector3.UP * _hill(pose, piece, t_behind)
			var forward := (ahead - behind).normalized()
			var hill := _hill(pose, piece, t)
			var base_up := (pose.basis * piece.up(t)).normalized()
			var flat_right := forward.cross(base_up).normalized()
			var flat_up := flat_right.cross(forward)
			var lean := piece.bank_at(t)
			var up := flat_up * cos(lean) + flat_right * sin(lean)
			# Banked road leans up from its low edge instead of around its
			# middle, so the inside edge stays at road height instead of
			# sinking into the ground.
			var rise := (width * 0.5 + KERB) * absf(sin(lean))
			points.append(pose * piece.point(t) + Vector3.UP * hill + flat_up * rise)
			grounds.append(hill)
			forwards.append(forward)
			ups.append(up)
			rights.append(forward.cross(up))
			solids.append(piece.solid(t))
			stickies.append(piece.sticky)
			piece_of.append(i)
		pose = pose * piece.exit()
	closes = not pieces.is_empty() and pose.origin.distance_to(start.origin) < 0.5 \
		and (-pose.basis.z).dot(-start.basis.z) > 0.999

	var total := 0.0
	for k in points.size():
		distances.append(total)
		total += points[k].distance_to(points[(k + 1) % points.size()])
	length = total


## How high the hills lift the road `t` of the way through a piece. Loops and
## jumps only lean with the hill from one end to the other, so their shape
## stays as it was made.
func _hill(pose: Transform3D, piece: TrackPiece, t: float) -> float:
	if hills <= 0.0:
		return 0.0
	if piece.type == "loop" or piece.type == "jump":
		var from := pose.origin
		var to := (pose * piece.exit()).origin
		return lerpf(ground_height(from.x, from.z), ground_height(to.x, to.z), t)
	var p := pose * piece.point(t)
	return ground_height(p.x, p.z)


func _index_before(offset: float) -> int:
	var d := fposmod(offset, length)
	var lo := 0
	var hi := distances.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if distances[mid] <= d:
			lo = mid
		else:
			hi = mid - 1
	return lo


func _blend(offset: float) -> Array:
	var i := _index_before(offset)
	var j := (i + 1) % points.size()
	var span := (distances[j] if j != 0 else length) - distances[i]
	var f := clampf((fposmod(offset, length) - distances[i]) / maxf(span, 0.0001), 0.0, 1.0)
	return [i, j, f]


## What kind of piece of track is at this distance around it, like
## "straight" or "jump".
func piece_type_at(offset: float) -> String:
	if piece_of.is_empty():
		return ""
	return pieces[piece_of[_index_before(offset)]].type


func point_at(offset: float) -> Vector3:
	var b := _blend(offset)
	return points[b[0]].lerp(points[b[1]], b[2])


func forward_at(offset: float) -> Vector3:
	var b := _blend(offset)
	return forwards[b[0]].lerp(forwards[b[1]], b[2]).normalized()


func up_at(offset: float) -> Vector3:
	var b := _blend(offset)
	return ups[b[0]].lerp(ups[b[1]], b[2]).normalized()


func right_at(offset: float) -> Vector3:
	var b := _blend(offset)
	return rights[b[0]].lerp(rights[b[1]], b[2]).normalized()


func solid_at(offset: float) -> bool:
	return solids[_index_before(offset)]


## The road's own frame here, with -Z along the track, Y up off the road and X
## to the right.
func frame_at(offset: float) -> Transform3D:
	var forward := forward_at(offset)
	var up := up_at(offset)
	var right := forward.cross(up).normalized()
	return Transform3D(Basis(right, right.cross(forward), -forward), point_at(offset))


## How far along the track a position is. With a hint (where it was a moment
## ago) it only looks nearby, so a kart on a bridge isn't mistaken for one on
## the road underneath, or the other way around.
func offset_of(position: Vector3, hint := -1.0, window := 60.0) -> float:
	var count := points.size()
	var first := 0
	var steps := count
	if hint >= 0.0:
		first = _index_before(hint - window)
		steps = mini(count, ceili(window * 2.0 / SAMPLE) + 2)
	var best := first
	var best_distance := INF
	for n in steps:
		var k := (first + n) % count
		var d := points[k].distance_squared_to(position)
		if d < best_distance:
			best_distance = d
			best = k
	# Slide along the segment on either side of the nearest sample.
	var result := distances[best]
	var best_along := INF
	for side in [-1, 1]:
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
func bend_at(offset: float, span := 6.0) -> float:
	var a := forward_at(offset - span * 0.5)
	var b := forward_at(offset + span * 0.5)
	# It's measured across the road itself, so the way a loop curls over the
	# top doesn't count as a bend but a wall ride does.
	var up := up_at(offset)
	a = (a - up * a.dot(up)).normalized()
	b = (b - up * b.dot(up)).normalized()
	return absf(a.signed_angle_to(b, up)) / span


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


## Places where two bits of road that aren't next to each other along the
## track come too close without one being well above the other. A good track
## has none. Each is [offset, offset].
func clashes(clearance := 5.0) -> Array:
	var out := []
	var step := 4
	# Road, curbs and a half metre wall on each side. Any closer and the walls
	# would overlap. A loop's way in and way out sit 1 m apart wall to wall,
	# which is fine.
	var reach := width + 2.0 * KERB + 1.0
	var skip := int(ceil(reach * 2.0 / SAMPLE))
	var count := points.size()
	for i in range(0, count, step):
		for j in range(i + skip, count, step):
			if count - (j - i) < skip:
				continue
			var a := points[i]
			var b := points[j]
			var flat := Vector2(a.x - b.x, a.z - b.z).length()
			if flat < reach and absf(a.y - b.y) < clearance:
				out.append([distances[i], distances[j]])
	return out
