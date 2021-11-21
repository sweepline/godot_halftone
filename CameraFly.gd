extends Camera3D

@export var mouse_sensitivity = 0.8
@export var camera_speed = 1.0

const X_AXIS = Vector3(1, 0, 0)
const Y_AXIS = Vector3(0, 1, 0)


var _mouse_motion = Vector2.ZERO

func _physics_process(delta):
	# Only rotates mouse if the mouse is captured
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var yaw = _mouse_motion.x
		var pitch = _mouse_motion.y
		_mouse_motion = Vector2(0, 0)
		
		# Prevents looking up/down too far
		rotation.y -= deg2rad(yaw)
		rotation.x -= deg2rad(pitch)
		rotation.x = clamp(rotation.x, -PI/2, PI/2)
	
	var speed = camera_speed * delta
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= 3
	# Uhh we are moving the tiles for ZX plane instead to keep the numerical errors small
	# Camera still moves on the Y axis for keeping the elevations correct
	var z = transform.basis.z * speed
	var x = transform.basis.x * speed
	var y = transform.basis.y * speed
	
	if (Input.is_key_pressed(KEY_W)):
		position -= z
	if (Input.is_key_pressed(KEY_S)):
		position -= -z
	if (Input.is_key_pressed(KEY_A)):
		position -= x
	if (Input.is_key_pressed(KEY_D)):
		position -= -x
	if (Input.is_key_pressed(KEY_Q)):
		position -= y
	if (Input.is_key_pressed(KEY_E)):
		position -= -y


func _input(event):
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_mouse_motion = event.relative * mouse_sensitivity
			
	# Receives mouse button input
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT: # Only allows rotation if right click down
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)

	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()
