extends CharacterBody3D
class_name Player

## SIMPLE PLAYER CONTROLLER FOR TESTING ENEMY AI
## WASD to move, Space to jump, Mouse to look around

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003
@export var health: float = 100.0
@export var max_health: float = 100.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera: Camera3D
var head: Node3D

func _ready():
	# Create camera setup
	head = Node3D.new()
	head.name = "Head"
	add_child(head)
	head.position = Vector3(0, 1.6, 0)
	
	camera = Camera3D.new()
	camera.name = "Camera"
	head.add_child(camera)
	
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)
	
	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
	
	# Movement
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()

func take_damage(amount: float):
	health -= amount
	print("Player took ", amount, " damage! Health: ", health)
	
	if health <= 0:
		die()

func die():
	print("Player died!")
	# Respawn or game over logic here
	health = max_health
	global_position = Vector3.ZERO
