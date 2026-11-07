class_name RearViewMirror
extends Control

## A narrow rear view sharing the race's world. Split screen never creates one.

const RENDER_SIZE := Vector2i(384, 96)
const FRAME := 3.0
const GAP := 8.0
const RADIUS := 9

var camera: RaceCamera
var blockers: Array[Control] = []
var viewport: SubViewport
var rear_camera: Camera3D
var picture: TextureRect
var _frame: StyleBoxFlat


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visibility_changed.connect(_sync_render)
	resized.connect(queue_redraw)
	_frame = _rounded(Color(0.05, 0.07, 0.09), RADIUS)
	_frame.border_color = Color(0.7, 0.75, 0.8, 0.65)
	_frame.set_border_width_all(1)
	queue_redraw()


func is_active() -> bool:
	return is_visible_in_tree() and camera != null and camera.mirror_available and not camera.finished and camera.view in ["driver", "hood", "bumper"] and Game.rear_view_mirror()


func _process(_delta: float) -> void:
	# The control keeps its place while off, but doesn't allocate a render
	# target until it's first used.
	if not is_active():
		if viewport != null:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		modulate.a = 0.0
		return
	_fit()
	modulate.a = 1.0
	if not is_visible_in_tree():
		_sync_render()
		return
	if viewport == null:
		_build_view()
	var kart := camera.target
	if kart == null or not is_instance_valid(kart):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	# Behind the whole kart, so a cab, wing or driver's head can't block it.
	var turn := kart.global_basis.orthonormalized()
	rear_camera.global_transform = Transform3D(turn.rotated(turn.y, PI), kart.to_global(kart.rear_hood_point()))
	rear_camera.cull_mask = camera.cull_mask
	if camera.head_layer > 0:
		rear_camera.set_cull_mask_value(camera.head_layer, false)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _build_view() -> void:
	viewport = SubViewport.new()
	viewport.size = RENDER_SIZE
	viewport.world_3d = camera.get_world_3d()
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.disable_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.positional_shadow_atlas_size = 0
	add_child(viewport)
	rear_camera = Camera3D.new()
	rear_camera.keep_aspect = Camera3D.KEEP_WIDTH
	rear_camera.fov = 80.0
	rear_camera.near = 0.05
	rear_camera.far = 150.0
	viewport.add_child(rear_camera)
	rear_camera.make_current()
	var glass := Panel.new()
	glass.mouse_filter = MOUSE_FILTER_IGNORE
	glass.add_theme_stylebox_override("panel", _rounded(Color.BLACK, RADIUS - int(FRAME)))
	glass.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(glass)
	glass.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	glass.offset_left = FRAME
	glass.offset_top = FRAME
	glass.offset_right = -FRAME
	glass.offset_bottom = -FRAME
	picture = TextureRect.new()
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.flip_h = true
	glass.add_child(picture)
	picture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)


static func _rounded(colour: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	return style


func _fit() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	var width := clampf(parent.size.x * 0.25, 180.0, 260.0)
	size = Vector2(width, (width - FRAME * 2.0) / 4.0 + FRAME * 2.0)
	var centre := (parent.size.x - width) * 0.5
	var taken: Array[Rect2] = SafeArea.holes_in(get_viewport())
	var into := parent.get_global_transform_with_canvas().affine_inverse()
	for i in taken.size():
		taken[i] = into * taken[i]
	for control in blockers:
		if is_instance_valid(control) and control.is_visible_in_tree():
			taken.append(into * control.get_global_rect())
	var xs: Array[float] = [centre]
	var ys: Array[float] = [10.0]
	for rect in taken:
		xs.append(rect.position.x - width - GAP)
		xs.append(rect.end.x + GAP)
		ys.append(rect.end.y + GAP)
	ys.sort()
	xs.sort_custom(func(a: float, b: float) -> bool: return absf(a - centre) < absf(b - centre))
	for y in ys:
		for x in xs:
			var room := Rect2(Vector2(x, y), size)
			if x < GAP or room.end.x > parent.size.x - GAP or room.end.y > parent.size.y - GAP:
				continue
			if taken.any(func(rect: Rect2) -> bool: return room.intersects(rect.grow(GAP - 0.1))):
				continue
			position = room.position
			return
	position = Vector2(centre, 10.0)


func _sync_render() -> void:
	if viewport != null and (not is_visible_in_tree() or not can_process()):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _draw() -> void:
	if _frame != null:
		draw_style_box(_frame, Rect2(Vector2.ZERO, size))
