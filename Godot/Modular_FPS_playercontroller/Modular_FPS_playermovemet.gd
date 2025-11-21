extends CharacterBody3D
# ----------------------------------------------
# SIMPLE 3D PLAYER CONTROLLER WITH HEAD BOB, SPRINT & CAMERA FOV
# ----------------------------------------------

# ----- HEAD BOB SETTINGS -----
const BOB_SPEED = 2.0      
const BOB_AMOUNT = 0.08    
var bob_time = 0.0         

# ----- MOVEMENT SETTINGS -----
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.8
@export var jump_power: float = 4.5
@export var mouse_sensitivity: float = 0.003

# ----- CAMERA SETTINGS -----
@export var walk_fov: float = 70.0     
@export var sprint_fov: float = 85.0   
@export var fov_change_speed: float = 6.0

# ----- GRAVITY -----
var gravity: float = 9.8

# ----- NODE REFERENCES -----
@onready var head: Node3D = $HEAD
@onready var camera: Camera3D = $HEAD/Camera3D

# Base camera position for head bob
var base_camera_position: Vector3 = Vector3.ZERO

# Current movement speed
var current_speed: float = 0.0


# ----------------------------------------------
# 🟢 STARTUP
# ----------------------------------------------
func _ready() -> void:
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	current_speed = walk_speed
	base_camera_position = camera.transform.origin
	camera.fov = walk_fov

	# --- EXPLANATION ---
	# This runs once at the start. It sets up gravity so the player falls naturally,
	# locks the mouse for smooth camera control, and remembers the camera's base position
	# to add head bob later. It also sets the starting speed and camera FOV.


# ----------------------------------------------
# 🖱️ MOUSE LOOK
# ----------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -40.0, 60.0)

	# --- EXPLANATION ---
	# Lets the player look around using the mouse. Rotates the head left/right,
	# rotates the camera up/down, and clamps the vertical rotation so you can't flip over.
	# This creates the classic first-person look control.


# ----------------------------------------------
# 🔁 MAIN MOVEMENT LOOP
# ----------------------------------------------
func _physics_process(delta: float) -> void:

	# --- GRAVITY ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	# --- JUMP ---
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_power

	# --- SPRINT OR WALK ---
	if Input.is_action_pressed("sprint"):
		current_speed = sprint_speed
	else:
		current_speed = walk_speed

	# --- MOVEMENT INPUT ---
	# Custom input order: backward, forward, left, right
	var input_move: Vector2 = Input.get_vector("move_backward", "move_forward", "move_left", "move_right")
	var move_direction: Vector3 = (head.transform.basis * Vector3(input_move.x, 0.0, input_move.y)).normalized()

	# --- MOVE ONLY WHEN ON FLOOR ---
	if is_on_floor():
		if move_direction != Vector3.ZERO:
			velocity.x = move_direction.x * current_speed
			velocity.z = move_direction.z * current_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	# In air: player keeps last direction

	# --- HEAD BOB EFFECT ---
	bob_time += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = base_camera_position + _get_headbob(bob_time) * float(is_on_floor())

	# --- CAMERA FOV (ZOOM WHILE SPRINTING) ---
	var target_fov = sprint_fov if current_speed > walk_speed else walk_fov
	camera.fov = lerp(camera.fov, target_fov, clamp(delta * fov_change_speed, 0.0, 1.0))

	# --- MOVE PLAYER ---
	move_and_slide()

	# --- EXPLANATION ---
	# Handles everything every frame. Gravity makes the player fall.
	# Jumping works only when on the ground. Sprinting increases speed and changes FOV for a “fast” feeling.
	# Movement input now uses your custom backward/forward/left/right order.
	# The player cannot steer in the air. Head bob adds realism, and move_and_slide actually moves the player using Godot's physics.


# ----------------------------------------------
# 🎥 HEAD BOB FUNCTION
# ----------------------------------------------
func _get_headbob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_SPEED) * BOB_AMOUNT
	pos.x = cos(time * (BOB_SPEED / 2.0)) * BOB_AMOUNT
	return pos

	# --- EXPLANATION ---
	# Calculates the little up-and-down and side-to-side motion of the camera when walking.
	# Only applied on the floor. Makes movement feel alive and realistic like in real first-person games.








#Defining actions 
#use them or use your custom actions for certain actions
#Open project → Project Settings → Input Map.
#Add these actions (click “Add Action”)

#move_forward → assign W or Up Arrow
#move_backward → assign S or Down Arrow
#move_left → assign A or Left Arrow
#move_right → assign D or Right Arrow
#sprint → assign Shift
#ui_accept → already exists (default is Space for jump)
