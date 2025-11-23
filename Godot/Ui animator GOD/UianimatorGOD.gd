@tool
extends Sprite2D
class_name UianimatorGod

## Universal UI Animation System for Godot 4
## Attach to any Control node for instant animation capabilities
## All animations are code-based (no AnimationPlayer/Tween required)

# ============================================================
# MOVEMENT / POSITION ANIMATIONS
# ============================================================

@export_group("Movement Animations")
@export var slide_enabled: bool = false
@export_enum("Left", "Right", "Up", "Down") var slide_direction: int = 0
@export var slide_distance: float = 100.0
@export var slide_speed: float = 2.0
@export var slide_delay: float = 0.0

@export var bounce_enabled: bool = false
@export var bounce_height: float = 20.0
@export var bounce_speed: float = 3.0
@export var bounce_dampening: float = 0.8

@export var float_enabled: bool = false
@export var float_amplitude: float = 10.0
@export var float_speed: float = 1.5
@export_enum("Vertical", "Horizontal", "Circular") var float_type: int = 0

# ============================================================
# SCALING / SIZE ANIMATIONS
# ============================================================

@export_group("Scale Animations")
@export var pop_enabled: bool = false
@export var pop_scale: float = 1.2
@export var pop_speed: float = 5.0
@export var pop_delay: float = 0.0

@export var pulse_enabled: bool = false
@export var pulse_min_scale: float = 0.95
@export var pulse_max_scale: float = 1.05
@export var pulse_speed: float = 2.0

@export var shrink_enabled: bool = false
@export var shrink_speed: float = 2.0
@export var shrink_delay: float = 0.0

# ============================================================
# FADE / TRANSPARENCY ANIMATIONS
# ============================================================

@export_group("Fade Animations")
@export var fade_in_enabled: bool = false
@export var fade_in_speed: float = 2.0
@export var fade_in_delay: float = 0.0

@export var fade_out_enabled: bool = false
@export var fade_out_speed: float = 2.0
@export var fade_out_delay: float = 0.0

@export var blink_enabled: bool = false
@export var blink_speed: float = 3.0
@export var blink_min_alpha: float = 0.3
@export var blink_max_alpha: float = 1.0

# ============================================================
# COLOR / TINT ANIMATIONS
# ============================================================

@export_group("Color Animations")
@export var color_shift_enabled: bool = false
@export var color_shift_start: Color = Color.WHITE
@export var color_shift_end: Color = Color.RED
@export var color_shift_speed: float = 1.0
@export var color_shift_loop: bool = true

@export var warning_flash_enabled: bool = false
@export var warning_color: Color = Color.RED
@export var warning_flash_speed: float = 5.0

@export var gradient_enabled: bool = false
@export var gradient_colors: Array[Color] = []
@export var gradient_speed: float = 1.0

# ============================================================
# ROTATION ANIMATIONS
# ============================================================

@export_group("Rotation Animations")
@export var rotate_enabled: bool = false
@export var rotate_speed: float = 1.0
@export_enum("Clockwise", "Counter-Clockwise") var rotate_direction: int = 0
@export var rotate_continuous: bool = true

@export var wobble_enabled: bool = false
@export var wobble_angle: float = 15.0
@export var wobble_speed: float = 4.0

# ============================================================
# SHAKE / JITTER ANIMATIONS
# ============================================================

@export_group("Shake Animations")
@export var shake_enabled: bool = false
@export var shake_intensity: float = 5.0
@export var shake_speed: float = 20.0
@export var shake_duration: float = 0.5
@export var shake_trigger_on_ready: bool = false

@export var jitter_enabled: bool = false
@export var jitter_amount: float = 2.0
@export var jitter_speed: float = 10.0

# ============================================================
# PROGRESS / FILL ANIMATIONS
# ============================================================

@export_group("Progress Animations")
@export var progress_fill_enabled: bool = false
@export_range(0.0, 1.0) var progress_target: float = 1.0
@export var progress_speed: float = 1.0
@export var progress_auto_start: bool = false

@export var countdown_enabled: bool = false
@export var countdown_duration: float = 10.0
@export var countdown_auto_start: bool = false

# ============================================================
# COMPOUND ANIMATIONS
# ============================================================

@export_group("Compound Animations")
@export var slide_fade_enabled: bool = false
@export_enum("Left", "Right", "Up", "Down") var slide_fade_direction: int = 0
@export var slide_fade_distance: float = 100.0
@export var slide_fade_speed: float = 2.0

@export var shake_flash_enabled: bool = false
@export var shake_flash_color: Color = Color.RED
@export var shake_flash_intensity: float = 5.0
@export var shake_flash_duration: float = 0.5

@export var bounce_scale_enabled: bool = false
@export var bounce_scale_height: float = 20.0
@export var bounce_scale_amount: float = 1.2
@export var bounce_scale_speed: float = 3.0

# ============================================================
# INTERNAL STATE VARIABLES
# ============================================================

var _time: float = 0.0
var _original_position: Vector2
var _original_scale: Vector2
var _original_rotation: float
var _original_modulate: Color
var _shake_time: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _bounce_velocity: float = 0.0
var _bounce_position: float = 0.0
var _current_progress: float = 0.0
var _countdown_time: float = 0.0
var _gradient_index: int = 0
var _has_modulate: bool = true
var _has_scale: bool = true
var _has_rotation: bool = true
var _has_progress: bool = false
var _is_ready: bool = false

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	_check_node_properties()
	_store_original_values()
	_initialize_animations()
	_is_ready = true
	
	if shake_trigger_on_ready and shake_enabled:
		trigger_shake()

func _check_node_properties() -> void:
	"""Check which properties this node supports"""
	_has_modulate = "modulate" in self
	_has_scale = "scale" in self
	_has_rotation = "rotation" in self
	
	# Check for progress-related properties using duck typing
	_has_progress = "value" in self and "max_value" in self
	
	# Warn about missing properties for enabled animations
	if not _has_modulate and (fade_in_enabled or fade_out_enabled or blink_enabled or color_shift_enabled):
		push_warning("Node doesn't have 'modulate' property. Color/fade animations disabled.")
	
	if not _has_scale and (pop_enabled or pulse_enabled or shrink_enabled):
		push_warning("Node doesn't have 'scale' property. Scale animations disabled.")
	
	if not _has_rotation and (rotate_enabled or wobble_enabled):
		push_warning("Node doesn't have 'rotation' property. Rotation animations disabled.")
	
	if not _has_progress and progress_fill_enabled:
		push_warning("Node doesn't support progress values. Progress animation disabled.")

func _store_original_values() -> void:
	"""Store original node values for reset/reference"""
	_original_position = position
	if _has_scale:
		_original_scale = scale
	if _has_rotation:
		_original_rotation = rotation
	if _has_modulate:
		_original_modulate = modulate
	
	if countdown_enabled:
		_countdown_time = countdown_duration
	
	if progress_fill_enabled and _has_progress:
		_current_progress = 0.0

func _initialize_animations() -> void:
	"""Set initial states for animations"""
	# Slide animation initialization
	if slide_enabled:
		var offset = _get_slide_offset(slide_direction, slide_distance)
		position = _original_position + offset
	
	# Fade in initialization
	if fade_in_enabled and _has_modulate:
		modulate.a = 0.0
	
	# Pop initialization
	if pop_enabled and _has_scale:
		scale = Vector2.ZERO
	
	# Shrink initialization
	if shrink_enabled and _has_scale:
		scale = _original_scale
	
	# Slide-fade initialization
	if slide_fade_enabled:
		var offset = _get_slide_offset(slide_fade_direction, slide_fade_distance)
		position = _original_position + offset
		if _has_modulate:
			modulate.a = 0.0
	
	# Progress initialization
	if progress_auto_start and progress_fill_enabled:
		start_progress_fill()
	
	if countdown_auto_start and countdown_enabled:
		start_countdown()

# ============================================================
# MAIN PROCESS LOOP
# ============================================================

func _process(delta: float) -> void:
	if not _is_ready:
		return
	
	_time += delta
	
	# Reset position for this frame (will be modified by animations)
	var frame_position = _original_position
	var frame_scale = _original_scale if _has_scale else Vector2.ONE
	var frame_rotation = _original_rotation if _has_rotation else 0.0
	
	# ============================================================
	# PROCESS MOVEMENT ANIMATIONS
	# ============================================================
	
	if slide_enabled:
		frame_position += _process_slide(delta)
	
	if bounce_enabled:
		frame_position.y += _process_bounce(delta)
	
	if float_enabled:
		frame_position += _process_float()
	
	if jitter_enabled:
		frame_position += _process_jitter()
	
	# ============================================================
	# PROCESS SCALE ANIMATIONS
	# ============================================================
	
	if pop_enabled and _has_scale:
		frame_scale = _process_pop(delta)
	
	if pulse_enabled and _has_scale:
		frame_scale *= _process_pulse()
	
	if shrink_enabled and _has_scale:
		frame_scale = _process_shrink(delta)
	
	if bounce_scale_enabled and _has_scale:
		frame_scale = _process_bounce_scale(delta)
	
	# ============================================================
	# PROCESS FADE ANIMATIONS
	# ============================================================
	
	if fade_in_enabled and _has_modulate:
		_process_fade_in(delta)
	
	if fade_out_enabled and _has_modulate:
		_process_fade_out(delta)
	
	if blink_enabled and _has_modulate:
		_process_blink()
	
	# ============================================================
	# PROCESS COLOR ANIMATIONS
	# ============================================================
	
	if color_shift_enabled and _has_modulate:
		_process_color_shift()
	
	if warning_flash_enabled and _has_modulate:
		_process_warning_flash()
	
	if gradient_enabled and _has_modulate and gradient_colors.size() > 1:
		_process_gradient()
	
	# ============================================================
	# PROCESS ROTATION ANIMATIONS
	# ============================================================
	
	if rotate_enabled and _has_rotation:
		frame_rotation = _process_rotation(delta)
	
	if wobble_enabled and _has_rotation:
		frame_rotation += _process_wobble()
	
	# ============================================================
	# PROCESS SHAKE ANIMATIONS
	# ============================================================
	
	if shake_enabled:
		frame_position += _process_shake(delta)
	
	# ============================================================
	# PROCESS PROGRESS ANIMATIONS
	# ============================================================
	
	if progress_fill_enabled and _has_progress:
		_process_progress_fill(delta)
	
	if countdown_enabled:
		_process_countdown(delta)
	
	# ============================================================
	# PROCESS COMPOUND ANIMATIONS
	# ============================================================
	
	if slide_fade_enabled:
		frame_position = _process_slide_fade(delta)
	
	if shake_flash_enabled:
		var shake_data = _process_shake_flash(delta)
		frame_position += shake_data.offset
	
	# ============================================================
	# APPLY FINAL TRANSFORMATIONS
	# ============================================================
	
	position = frame_position
	if _has_scale:
		scale = frame_scale
	if _has_rotation:
		rotation = frame_rotation

# ============================================================
# MOVEMENT ANIMATION FUNCTIONS
# ============================================================

func _process_slide(delta: float) -> Vector2:
	"""Slide animation from offset to original position"""
	if _time < slide_delay:
		return _get_slide_offset(slide_direction, slide_distance)
	
	var progress = min((_time - slide_delay) * slide_speed, 1.0)
	var eased = ease(progress, -2.0)  # Ease out
	var offset = _get_slide_offset(slide_direction, slide_distance)
	return offset * (1.0 - eased)

func _process_bounce(delta: float) -> float:
	"""Bounce animation with physics-like behavior"""
	_bounce_velocity += 400.0 * delta  # Gravity
	_bounce_position += _bounce_velocity * delta
	
	if _bounce_position >= 0.0:
		_bounce_position = 0.0
		_bounce_velocity = -abs(_bounce_velocity) * bounce_dampening
		
		if abs(_bounce_velocity) < 10.0:
			_bounce_velocity = -bounce_speed * 100.0
	
	return _bounce_position

func _process_float() -> Vector2:
	"""Floating oscillation animation"""
	match float_type:
		0:  # Vertical
			return Vector2(0, sin(_time * float_speed) * float_amplitude)
		1:  # Horizontal
			return Vector2(sin(_time * float_speed) * float_amplitude, 0)
		2:  # Circular
			return Vector2(
				cos(_time * float_speed) * float_amplitude,
				sin(_time * float_speed) * float_amplitude
			)
	return Vector2.ZERO

func _process_jitter() -> Vector2:
	"""Random jitter/shake effect"""
	return Vector2(
		randf_range(-jitter_amount, jitter_amount),
		randf_range(-jitter_amount, jitter_amount)
	)

func _get_slide_offset(direction: int, distance: float) -> Vector2:
	"""Get offset vector based on slide direction"""
	match direction:
		0: return Vector2(-distance, 0)  # Left
		1: return Vector2(distance, 0)   # Right
		2: return Vector2(0, -distance)  # Up
		3: return Vector2(0, distance)   # Down
	return Vector2.ZERO

# ============================================================
# SCALE ANIMATION FUNCTIONS
# ============================================================

func _process_pop(delta: float) -> Vector2:
	"""Pop-in scale animation"""
	if _time < pop_delay:
		return Vector2.ZERO
	
	var progress = min((_time - pop_delay) * pop_speed, 1.0)
	var overshoot = sin(progress * PI) * (pop_scale - 1.0)
	return _original_scale * (progress + overshoot)

func _process_pulse() -> float:
	"""Pulsing heartbeat effect"""
	var pulse = sin(_time * pulse_speed * PI)
	return lerp(pulse_min_scale, pulse_max_scale, (pulse + 1.0) * 0.5)

func _process_shrink(delta: float) -> Vector2:
	"""Shrink out animation"""
	if _time < shrink_delay:
		return _original_scale
	
	var progress = min((_time - shrink_delay) * shrink_speed, 1.0)
	return _original_scale * (1.0 - progress)

func _process_bounce_scale(delta: float) -> Vector2:
	"""Combined bounce and scale effect"""
	var bounce_offset = sin(_time * bounce_scale_speed) * bounce_scale_height
	var scale_factor = 1.0 + (abs(sin(_time * bounce_scale_speed)) * (bounce_scale_amount - 1.0))
	return _original_scale * scale_factor

# ============================================================
# FADE ANIMATION FUNCTIONS
# ============================================================

func _process_fade_in(delta: float) -> void:
	"""Fade in animation"""
	if _time < fade_in_delay:
		return
	
	var progress = min((_time - fade_in_delay) * fade_in_speed, 1.0)
	modulate.a = progress

func _process_fade_out(delta: float) -> void:
	"""Fade out animation"""
	if _time < fade_out_delay:
		return
	
	var progress = min((_time - fade_out_delay) * fade_out_speed, 1.0)
	modulate.a = 1.0 - progress

func _process_blink() -> void:
	"""Blinking attention effect"""
	var blink = sin(_time * blink_speed * PI * 2.0)
	modulate.a = lerp(blink_min_alpha, blink_max_alpha, (blink + 1.0) * 0.5)

# ============================================================
# COLOR ANIMATION FUNCTIONS
# ============================================================

func _process_color_shift() -> void:
	"""Color shift between two colors"""
	var progress = fmod(_time * color_shift_speed, 2.0)
	if progress > 1.0:
		progress = 2.0 - progress
	
	modulate = color_shift_start.lerp(color_shift_end, progress)
	
	if not color_shift_loop and _time * color_shift_speed >= 1.0:
		modulate = color_shift_end

func _process_warning_flash() -> void:
	"""Warning flash effect"""
	var flash = abs(sin(_time * warning_flash_speed * PI))
	modulate = _original_modulate.lerp(warning_color, flash)

func _process_gradient() -> void:
	"""Gradient color animation through multiple colors"""
	var total_time = gradient_colors.size() * gradient_speed
	var progress = fmod(_time, total_time) / gradient_speed
	var index = int(progress)
	var next_index = (index + 1) % gradient_colors.size()
	var blend = fmod(progress, 1.0)
	
	modulate = gradient_colors[index].lerp(gradient_colors[next_index], blend)

# ============================================================
# ROTATION ANIMATION FUNCTIONS
# ============================================================

func _process_rotation(delta: float) -> float:
	"""Continuous rotation animation"""
	var dir = 1.0 if rotate_direction == 0 else -1.0
	if rotate_continuous:
		return fmod(_time * rotate_speed * TAU * dir, TAU)
	else:
		return _original_rotation + sin(_time * rotate_speed) * PI * dir

func _process_wobble() -> float:
	"""Wobble rotation effect"""
	return sin(_time * wobble_speed) * deg_to_rad(wobble_angle)

# ============================================================
# SHAKE ANIMATION FUNCTIONS
# ============================================================

func _process_shake(delta: float) -> Vector2:
	"""Error shake animation"""
	if _shake_time <= 0.0:
		return Vector2.ZERO
	
	_shake_time -= delta
	var intensity = (_shake_time / shake_duration) * shake_intensity
	
	return Vector2(
		randf_range(-intensity, intensity),
		randf_range(-intensity, intensity)
	)

func trigger_shake() -> void:
	"""Manually trigger a shake animation"""
	_shake_time = shake_duration

# ============================================================
# PROGRESS ANIMATION FUNCTIONS
# ============================================================

func _process_progress_fill(delta: float) -> void:
	"""Progress bar fill animation"""
	if _current_progress < progress_target:
		_current_progress = min(_current_progress + delta * progress_speed, progress_target)
		
		if _has_progress:
			set("value", _current_progress * get("max_value"))

func _process_countdown(delta: float) -> void:
	"""Countdown timer animation"""
	if _countdown_time > 0.0:
		_countdown_time -= delta
		
		# Use duck typing to safely set properties
		if "text" in self:
			set("text", "%.1f" % max(_countdown_time, 0.0))
		elif _has_progress:
			set("value", (_countdown_time / countdown_duration) * get("max_value"))

func start_progress_fill() -> void:
	"""Start the progress fill animation"""
	_current_progress = 0.0

func start_countdown() -> void:
	"""Start the countdown timer"""
	_countdown_time = countdown_duration

func set_progress_target(target: float) -> void:
	"""Set a new progress target value (0.0 to 1.0)"""
	progress_target = clamp(target, 0.0, 1.0)

# ============================================================
# COMPOUND ANIMATION FUNCTIONS
# ============================================================

func _process_slide_fade(delta: float) -> Vector2:
	"""Combined slide and fade animation"""
	var progress = min(_time * slide_fade_speed, 1.0)
	var eased = ease(progress, -2.0)
	
	if _has_modulate:
		modulate.a = progress
	
	var offset = _get_slide_offset(slide_fade_direction, slide_fade_distance)
	return _original_position + offset * (1.0 - eased)

func _process_shake_flash(delta: float) -> Dictionary:
	"""Combined shake and color flash"""
	var result = {"offset": Vector2.ZERO, "color": _original_modulate}
	
	if _shake_time <= 0.0:
		return result
	
	_shake_time -= delta
	var intensity_factor = _shake_time / shake_flash_duration
	var intensity = intensity_factor * shake_flash_intensity
	
	result.offset = Vector2(
		randf_range(-intensity, intensity),
		randf_range(-intensity, intensity)
	)
	
	if _has_modulate:
		var flash = abs(sin(_time * 20.0))
		modulate = _original_modulate.lerp(shake_flash_color, flash * intensity_factor)
	
	return result

func trigger_shake_flash() -> void:
	"""Manually trigger shake-flash compound animation"""
	_shake_time = shake_flash_duration

# ============================================================
# UTILITY FUNCTIONS
# ============================================================

func reset_animation() -> void:
	"""Reset all animations to initial state"""
	_time = 0.0
	_shake_time = 0.0
	_bounce_velocity = 0.0
	_bounce_position = 0.0
	_current_progress = 0.0
	_countdown_time = countdown_duration
	
	position = _original_position
	if _has_scale:
		scale = _original_scale
	if _has_rotation:
		rotation = _original_rotation
	if _has_modulate:
		modulate = _original_modulate
	
	_initialize_animations()

func pause_animations() -> void:
	"""Pause all animations"""
	set_process(false)

func resume_animations() -> void:
	"""Resume all animations"""
	set_process(true)

func set_time_scale(scale: float) -> void:
	"""Adjust animation speed globally"""
	Engine.time_scale = scale
