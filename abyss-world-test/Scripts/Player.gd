extends CharacterBody3D

@onready var jump_timer: Timer = $StartUpTimer
@onready var slope_ray_cast: RayCast3D = $SlopeRayCast
@onready var wall_ray_casts: Array[RayCast3D] = []
var wall_ray_collision: bool = false

#-----------------------------Camera Stuff--------------------------------------
var cam_mode: int = 0
@onready var pivot: Node3D = $CamOrigin
var local_sens = Global.sens
@onready var camera: Camera3D = $CamOrigin/CameraDistance/Camera3D
@onready var camera_distance: SpringArm3D = $CamOrigin/CameraDistance
var min_zoom: float = 2.5
var max_zoom: float = 6.0
@export var zoom_speed: float = 0.25
var camera_lock: bool = false
var mouse_unlocked: bool = false
var mouse_mode: int = 0

#-------------------------------Gravity----------------------------------------#
var gravity: float = 30.0
var fall_multiplier: float = 1.3

#-------------------------------Jumping----------------------------------------#
var can_walk: bool = true
var is_jumping: bool = false
var jump_start_up: bool = false

#------                       Jump Force                                 ------#
var jump_force = 13.0
var default_jump = 13.0
@export var max_jump_force: float = 20.0

#------                      Jump Distance                               ------#
@export var jump_distance: float = 10.0
@export var max_jump_distance: float = 20.0
var default_distance: float = 10.0


#-------------------------------Movement---------------------------------------#
var speed = 6.0
var run_speed = 2 # Multiplier for run
var was_in_air: bool = false
var recent_reset = Vector3(0, 2, 0)

#==============================================================================#
func _ready() -> void:
	camera_distance.add_excluded_object(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Fetch all 7 RayCasts automatically[cite: 2]
	for child in $WallRayCasts.get_children():
		if child is RayCast3D:
			wall_ray_casts.append(child)

#==============================================================================#
func _physics_process(delta: float) -> void:
	
	slope_slide(delta)
	state_machine()
	reset()
	camera_position()
	handle_movement()
	handle_jump(delta)
	my_gravity(delta)

	move_and_slide()

#==============================================================================#
#- - - - - - - - - - - - - - - Funcy Town - - - - - - - - - - - - - - - - - - -#
#==============================================================================#
func handle_jump(_delta: float) -> void:
	var forward_dir: Vector3 = -global_transform.basis.z
	forward_dir.y = 0.0
	forward_dir = forward_dir.normalized()

	#===============================Tap Jump===================================#
	if Input.is_action_just_pressed("jump") and (slope_ray_cast.is_colliding() or is_on_floor()):
		jump_timer.start()
		can_walk = false
		is_jumping = true

	#============================Calculations==================================#
	if Input.is_action_pressed("jump") and is_jumping:
		if jump_timer.time_left == 0.0:
			jump_force = min(jump_force + 0.1667, max_jump_force)
			jump_distance = min(jump_distance + 0.25, max_jump_distance)
			if velocity.y < 0:
				jump_distance += -velocity.y / 8.0
			if jump_force < max_jump_force:
				$AnimationPlayer.play("Jump_Charge")
				$AnimationPlayer.queue("Max_Charge")

	#==============================Cancel Jump=================================#
	if Input.is_action_pressed("cancel jump") and is_on_floor():
		jump_force = default_jump
		jump_distance = default_distance
		can_walk = true
		is_jumping = false
		$AnimationPlayer.stop()

	#==============================Released Jump===============================#
	if Input.is_action_just_released("jump") and is_jumping and (is_on_floor() or slope_ray_cast.is_colliding()):
		if jump_force == max_jump_force:
			$AnimationPlayer.play("max_jump")
		elif jump_force == default_jump:
			$AnimationPlayer.play("tap_jump")
		else:
			$AnimationPlayer.play("mid_jump")
	
		velocity.y = jump_force
		velocity.x = forward_dir.x * jump_distance
		velocity.z = forward_dir.z * jump_distance
		jump_force = default_jump
		jump_distance = default_distance
		can_walk = true
		is_jumping = false
		$Body.rotation.y = 0
		$WallRayCasts.rotation.y = 0
		recent_reset = global_position

	#==============================Wall Jump===================================#
	if not is_on_floor() and not slope_ray_cast.is_colliding():
		var total_normal: Vector3 = Vector3.ZERO
		var hit_count: int = 0

		for ray in wall_ray_casts:
			if ray.is_colliding():
				total_normal += ray.get_collision_normal()
				hit_count += 1

		if hit_count > 0:
			var wall_normal: Vector3 = (total_normal / float(hit_count)).normalized()

			var incoming_h_vel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
			var entry_speed: float = max(incoming_h_vel.length(), speed * 1.2)

			var bounce_dir: Vector3 = incoming_h_vel.bounce(wall_normal)
			bounce_dir.y = 0.0

			var min_deflection: float = 0.35
			if bounce_dir.normalized().dot(wall_normal) < min_deflection:
				bounce_dir = (bounce_dir.normalized() + wall_normal * min_deflection).normalized()
			else:
				bounce_dir = bounce_dir.normalized()

			#  Apply full entry speed to new bounce direction
			velocity.x = bounce_dir.x * entry_speed
			velocity.z = bounce_dir.z * entry_speed

			#  Push character off wall geometry to prevent sticking
			global_position += wall_normal * 0.15

			#  Align mesh visuals smoothly toward bounce trajectory
			if bounce_dir.length_squared() > 0.001:
				$Body.global_transform.basis = Basis.looking_at(bounce_dir, Vector3.UP)
				$WallRayCasts.global_transform.basis = Basis.looking_at(bounce_dir, Vector3.UP)

#==============================================================================#
func handle_movement() -> void:
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction and can_walk and is_on_floor():
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		if is_on_floor():
			velocity.x = 0
			velocity.z = 0
		else:
			# Scale horizontal vector proportionally so flight direction doesn't skew
			var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
			horiz_vel = horiz_vel.move_toward(Vector3.ZERO, 0.05)
			velocity.x = horiz_vel.x
			velocity.z = horiz_vel.z

#===============================Quit===========================================#
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

#============================CAMERA CONTROLS===================================#
func _input(event: InputEvent) -> void: 
	if event is InputEventMouseMotion and not mouse_unlocked:
		var y_angle: float = deg_to_rad(-event.relative.x * local_sens)

		rotate_y(y_angle)
		if not is_on_floor() or camera_lock:
			$Body.rotate_y(-y_angle)
			$WallRayCasts.rotate_y(-y_angle)
		pivot.rotate_x(deg_to_rad(-event.relative.y * local_sens))
		pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-60), deg_to_rad(40))

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance.spring_length = clamp(camera_distance.spring_length - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance.spring_length = clamp(camera_distance.spring_length + zoom_speed, min_zoom, max_zoom)

#==============================================================================#
func my_gravity(delta: float) -> void:
	if not is_on_floor():
		if velocity.y > 0.0:
			velocity.y -= gravity * delta
		else:
			velocity.y -= gravity * fall_multiplier * delta

#===========================Camera and Mouse===================================#
func camera_position() -> void:
	if Input.is_action_just_pressed("camera mode"):
		cam_mode += 1
	if cam_mode == 0:
		camera_distance.position.x = 0
	elif cam_mode == 1:
		camera_distance.position.x = 1
	elif cam_mode == 2:
		camera_distance.position.x = 0
	elif cam_mode == 3:
		camera_distance.position.x = -1
	elif cam_mode > 3:
		cam_mode = 0

	if Input.is_action_just_pressed("camera lock"):
		camera_lock = true
	if Input.is_action_just_released("camera lock"):
		camera_lock = false

	if Input.is_action_just_pressed("mouse unlock"):
		if mouse_mode < 1:
			mouse_mode += 1
		else: 
			mouse_mode = 0
	
		if mouse_mode == 1:
			mouse_unlocked = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			mouse_unlocked = false
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

#==============================================================================#
func reset() -> void:
	if Input.is_action_just_pressed("one"):
		$".".global_position = $"../Teleports/TeleportPoint".global_position
		recent_reset = global_position
	if Input.is_action_just_pressed("two"):
		$".".global_position = $"../Teleports/TeleportPoint3".global_position
		recent_reset = global_position
	if Input.is_action_just_pressed("three"):
		$".".global_position = $"../Teleports/TeleportPoint2".global_position
		recent_reset = global_position
	if Input.is_action_just_pressed("Reset"):
		$".".global_position = recent_reset
		velocity = Vector3.ZERO

#==============================================================================#
func animation_reset(delta: float) -> void:
	$Body.rotation = $Body.rotation.lerp(Vector3.ZERO, 15.0 * delta)
	$WallRayCasts.rotation = $WallRayCasts.rotation.lerp(Vector3.ZERO, 15.0 * delta)

#==============================================================================#
func state_machine() -> void:
	if (slope_ray_cast.is_colliding() or is_on_floor()) and not is_jumping:
		$AnimationPlayer.play("Idle")

#==============================================================================#
func time_slow() -> void:
	Engine.time_scale = 0.5

#==============================================================================#
func resolution() -> void:
	ProjectSettings.set_setting("display/window/size/width", 1600)
	ProjectSettings.set_setting("display/window/size/height", 800)   

#==============================================================================#
func slope_slide(delta: float) -> void:
	if (is_on_floor() or slope_ray_cast.is_colliding()) and !camera_lock:
		animation_reset(delta)
	
	if slope_ray_cast.is_colliding():
		var normal = slope_ray_cast.get_collision_normal()
		if normal.y < 0.99: 
			var slide_dir = Vector3.DOWN.slide(normal).normalized()
			velocity += slide_dir * gravity * delta
