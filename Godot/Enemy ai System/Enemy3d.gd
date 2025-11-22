extends CharacterBody3D
class_name Enemy3D

## MODULAR 3D ENEMY AI SYSTEM FOR GODOT 4
## Drop-in ready enemy with patrolling, chasing, attacking, fleeing, and more
## Setup: 1) Add player reference 2) Set patrol points 3) Configure exported vars

# ===== EXPORTED VARIABLES (Configure in Inspector) =====

@export_group("Target & Detection")
@export var player: Node3D ## Assign the player node here
@export var detection_range: float = 15.0 ## How far enemy can detect player
@export var attack_range: float = 3.0 ## Distance to start attacking
@export var lose_target_range: float = 25.0 ## Distance where enemy gives up chase

@export_group("Movement")
@export var patrol_speed: float = 2.0
@export var chase_speed: float = 5.0
@export var flee_speed: float = 6.0
@export var rotation_speed: float = 5.0

@export_group("Patrol Settings")
@export var patrol_points: Array[Node3D] = [] ## Add Marker3D nodes as patrol points
@export var patrol_wait_time: float = 2.0 ## Seconds to wait at each patrol point

@export_group("Combat")
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var damage: float = 10.0
@export var attack_cooldown: float = 1.5
@export var is_ranged: bool = false ## Enable for ranged attacks
@export var flee_health_threshold: float = 20.0 ## Health % to start fleeing

@export_group("Visual Feedback")
@export var show_state_label: bool = true ## Show debug state label above enemy
@export var change_color_by_state: bool = true ## Change mesh color based on state

@export_group("Advanced")
@export var investigate_duration: float = 5.0 ## Time spent investigating
@export var nav_agent_path: NodePath = "NavigationAgent3D" ## Path to NavigationAgent3D

# ===== STATE MACHINE =====
enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	FLEE,
	INVESTIGATE,
	DEAD
}

var current_state: State = State.IDLE
var previous_state: State = State.IDLE

# ===== INTERNAL VARIABLES =====
var current_patrol_index: int = 0
var patrol_wait_timer: float = 0.0
var attack_timer: float = 0.0
var investigate_timer: float = 0.0
var investigate_position: Vector3 = Vector3.ZERO
var last_known_player_pos: Vector3 = Vector3.ZERO

var nav_agent: NavigationAgent3D
var mesh_instance: MeshInstance3D
var state_label: Label3D
var original_color: Color

# State colors for visual feedback
var state_colors = {
	State.IDLE: Color.YELLOW,
	State.PATROL: Color.GREEN,
	State.CHASE: Color.RED,
	State.ATTACK: Color.ORANGE_RED,
	State.FLEE: Color.PURPLE,
	State.INVESTIGATE: Color.CYAN,
	State.DEAD: Color.GRAY
}

# ===== INITIALIZATION =====

func _ready():
	# Setup NavigationAgent3D
	nav_agent = get_node_or_null(nav_agent_path)
	if not nav_agent:
		nav_agent = NavigationAgent3D.new()
		add_child(nav_agent)
	
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	nav_agent.avoidance_enabled = true
	
	# CRITICAL: Wait for navigation to be ready
	call_deferred("_on_navigation_ready")
	# CRITICAL: Wait for navigation to be ready
	call_deferred("_on_navigation_ready")

func _on_navigation_ready():
	# Wait for physics frame
	await get_tree().physics_frame
	
	# Find mesh for color changing
	mesh_instance = _find_mesh_instance(self)
	if mesh_instance and mesh_instance.get_surface_override_material_count() > 0:
		var mat = mesh_instance.get_surface_override_material(0)
		if mat:
			original_color = mat.albedo_color
	
	# Create state label if enabled
	if show_state_label:
		state_label = Label3D.new()
		state_label.pixel_size = 0.01
		state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		state_label.position = Vector3(0, 2, 0)
		add_child(state_label)
	
	# Start with patrol or idle
	if patrol_points.size() > 0:
		change_state(State.PATROL)
	else:
		change_state(State.IDLE)

# ===== STATE MACHINE LOGIC =====

func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	# Update timers
	if attack_timer > 0:
		attack_timer -= delta
	if patrol_wait_timer > 0:
		patrol_wait_timer -= delta
	if investigate_timer > 0:
		investigate_timer -= delta
	
	# State logic
	match current_state:
		State.IDLE:
			process_idle(delta)
		State.PATROL:
			process_patrol(delta)
		State.CHASE:
			process_chase(delta)
		State.ATTACK:
			process_attack(delta)
		State.FLEE:
			process_flee(delta)
		State.INVESTIGATE:
			process_investigate(delta)
	
	# Apply movement
	move_and_slide()
	
	# Update state label
	if state_label:
		state_label.text = State.keys()[current_state]

# ===== STATE PROCESSING FUNCTIONS =====

func process_idle(delta):
	velocity = Vector3.ZERO
	
	# Check for player in range
	if can_see_player():
		change_state(State.CHASE)
		return
	
	# Return to patrol if available
	if patrol_points.size() > 0:
		change_state(State.PATROL)

func process_patrol(delta):
	if patrol_points.size() == 0:
		change_state(State.IDLE)
		return
	
	# Check for player
	if can_see_player():
		change_state(State.CHASE)
		return
	
	# Wait at patrol point
	if patrol_wait_timer > 0:
		velocity = Vector3.ZERO
		return
	
	# Navigate to current patrol point
	var target_point = patrol_points[current_patrol_index].global_position
	nav_agent.target_position = target_point
	
	# Debug print
	if Engine.get_physics_frames() % 60 == 0:  # Print every 60 frames
		print("Patrolling to point ", current_patrol_index, " at ", target_point)
		print("Distance: ", global_position.distance_to(target_point))
		print("Nav finished: ", nav_agent.is_navigation_finished())
	
	if nav_agent.is_navigation_finished():
		# Reached patrol point, wait then move to next
		patrol_wait_timer = patrol_wait_time
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		print("Reached patrol point! Moving to next.")
	else:
		var next_pos = nav_agent.get_next_path_position()
		move_toward_target(next_pos, patrol_speed, delta)

func process_chase(delta):
	if not player:
		change_state(State.PATROL if patrol_points.size() > 0 else State.IDLE)
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Check if should flee
	if should_flee():
		change_state(State.FLEE)
		return
	
	# Lost target
	if distance > lose_target_range:
		last_known_player_pos = player.global_position
		change_state(State.INVESTIGATE)
		return
	
	# In attack range
	if distance <= attack_range:
		change_state(State.ATTACK)
		return
	
	# Chase player
	nav_agent.target_position = player.global_position
	if not nav_agent.is_navigation_finished():
		move_toward_target(nav_agent.get_next_path_position(), chase_speed, delta)

func process_attack(delta):
	if not player:
		change_state(State.PATROL if patrol_points.size() > 0 else State.IDLE)
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Check if should flee
	if should_flee():
		change_state(State.FLEE)
		return
	
	# Player moved away
	if distance > attack_range * 1.5:
		change_state(State.CHASE)
		return
	
	# Face player
	look_at_target(player.global_position, delta)
	velocity = Vector3.ZERO
	
	# Attack when ready
	if attack_timer <= 0:
		perform_attack()
		attack_timer = attack_cooldown

func process_flee(delta):
	if not player:
		change_state(State.IDLE)
		return
	
	# Stop fleeing if health recovered or far enough
	if health > flee_health_threshold or global_position.distance_to(player.global_position) > lose_target_range:
		change_state(State.INVESTIGATE)
		return
	
	# Run away from player
	var flee_direction = (global_position - player.global_position).normalized()
	var flee_target = global_position + flee_direction * 10.0
	nav_agent.target_position = flee_target
	
	if not nav_agent.is_navigation_finished():
		move_toward_target(nav_agent.get_next_path_position(), flee_speed, delta)

func process_investigate(delta):
	# Check for player again
	if can_see_player():
		change_state(State.CHASE)
		return
	
	# Timeout investigation
	if investigate_timer <= 0:
		change_state(State.PATROL if patrol_points.size() > 0 else State.IDLE)
		return
	
	# Move to last known position
	nav_agent.target_position = last_known_player_pos
	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
	else:
		move_toward_target(nav_agent.get_next_path_position(), patrol_speed, delta)

# ===== HELPER FUNCTIONS =====

func change_state(new_state: State):
	previous_state = current_state
	current_state = new_state
	
	# State entry logic
	match new_state:
		State.INVESTIGATE:
			investigate_timer = investigate_duration
			last_known_player_pos = player.global_position if player else global_position
		State.PATROL:
			patrol_wait_timer = 0
	
	# Update visual feedback
	update_visual_state()

func can_see_player() -> bool:
	if not player:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	if distance > detection_range:
		return false
	
	# Debug print occasionally
	if Engine.get_physics_frames() % 120 == 0:  # Every 2 seconds
		print("Player distance: ", distance, " / Detection range: ", detection_range)
	
	# Optional: Add line-of-sight raycast check here
	return true

func should_flee() -> bool:
	return health <= flee_health_threshold

func move_toward_target(target: Vector3, speed: float, delta: float):
	var direction = (target - global_position).normalized()
	velocity = direction * speed
	look_at_target(target, delta)

func look_at_target(target: Vector3, delta: float):
	var look_dir = Vector3(target.x, global_position.y, target.z)
	var direction = (look_dir - global_position).normalized()
	if direction.length() > 0.001:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func perform_attack():
	if not player:
		return
	
	if is_ranged:
		# Ranged attack - spawn projectile (implement separately)
		print("Enemy fires ranged attack!")
		# You can add projectile spawning here
	else:
		# Melee attack - check if player is in range
		if global_position.distance_to(player.global_position) <= attack_range:
			if player.has_method("take_damage"):
				player.take_damage(damage)
			print("Enemy deals ", damage, " damage!")

func take_damage(amount: float):
	if current_state == State.DEAD:
		return
	
	health -= amount
	
	if health <= 0:
		die()
	elif health <= flee_health_threshold and current_state != State.FLEE:
		change_state(State.FLEE)

func die():
	change_state(State.DEAD)
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	print("Enemy died!")
	# Optional: play death animation, drop loot, etc.

func update_visual_state():
	if not change_color_by_state or not mesh_instance:
		return
	
	var target_color = state_colors.get(current_state, Color.WHITE)
	var mat = mesh_instance.get_active_material(0)
	
	if mat:
		# Create material instance if needed
		if not mat.resource_local_to_scene:
			mat = mat.duplicate()
			mesh_instance.set_surface_override_material(0, mat)
		
		if mat is StandardMaterial3D:
			mat.albedo_color = target_color

func investigate_noise(noise_position: Vector3):
	## Call this function from external sources to make enemy investigate a position
	if current_state in [State.IDLE, State.PATROL]:
		last_known_player_pos = noise_position
		change_state(State.INVESTIGATE)

# ===== UTILITY FUNCTIONS =====

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null
