class_name RaceProgress
extends RefCounted

## Keeps count of one kart's laps from how far along the track it is.
##
## The loop is split into quarters, and a lap only counts once the kart has
## been through each quarter in turn, so you can't back over the line and
## drive forward again for a free lap. Backing over the line takes a lap off,
## so going back and forth never gains anything.
##
## Karts start the race behind the line, so the first time over it starts
## lap one instead of finishing a lap.

const QUARTERS := 4

var track_length := 1.0
var laps_to_win := 3

## Laps finished. It's -1 until the kart first crosses the start line.
var laps := -1
var offset := 0.0
var finished := false
var finish_time := 0.0
var lap_times: Array[float] = []

var _quarters_seen := {}
var _lap_started := 0.0
## When the lap before this one started, so backing over the line can put it
## back.
var _lap_before := 0.0


func _init(length: float, laps_needed: int, start_offset: float) -> void:
	track_length = length
	laps_to_win = laps_needed
	offset = start_offset


## How far around the whole race this kart has gotten, in metres. Karts are
## placed by this.
func distance() -> float:
	return laps * track_length + offset


## When the lap the kart is on now started, in race time.
func lap_started() -> float:
	return _lap_started


## The fastest lap so far, or 0 before the first one's done.
func best_lap() -> float:
	return lap_times.min() if not lap_times.is_empty() else 0.0


## The lap the kart is on now, counting from one, for the HUD.
func current_lap() -> int:
	return clampi(laps + 1, 1, laps_to_win)


func update(new_offset: float, time: float) -> void:
	if finished:
		return
	var half := track_length * 0.5
	var quarter := int(new_offset / track_length * QUARTERS) % QUARTERS
	if new_offset - offset < -half:
		# It went forward over the start line.
		if laps == -1 or _quarters_seen.size() >= QUARTERS - 1:
			if laps >= 0:
				lap_times.append(time - _lap_started)
			laps += 1
			_lap_before = _lap_started
			_lap_started = time
			_quarters_seen.clear()
			if laps >= laps_to_win:
				finished = true
				finish_time = time
		else:
			# It crossed the line without going around the lap. That doesn't
			# count, and it doesn't cost anything either.
			pass
	elif new_offset - offset > half:
		# It backed over the start line. Undo the lap it started, and the time
		# of the lap it finished there, and treat the quarters behind as seen,
		# so driving forward again gives it back.
		if laps >= 1 and not lap_times.is_empty():
			lap_times.pop_back()
			_lap_started = _lap_before
		laps -= 1
		for q in range(1, QUARTERS):
			_quarters_seen[q] = true
	elif quarter != 0:
		_quarters_seen[quarter] = true
	offset = new_offset
