extends CharacterBody2D

var input
@export var vel = 100.0
@export var grav = 3

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	movement(delta)

func movement(delta):
	input = Input.get_action_strength("right") - Input.get_action_strength("left")
	
	if input != 0:
		if input > 0:
			velocity.x += vel * delta
			velocity.x = clamp(vel, 100.0, vel)
			$Sprite2D.scale.x = 1
			$AnimationPlayer.play("walk")
		if input < 0:
			velocity.x -= vel * delta
			velocity.x = clamp(-vel, -100.0, -vel)
			$Sprite2D.scale.x = -1
			$AnimationPlayer.play("walk")

	if input == 0:
		velocity.x = 0
		$AnimationPlayer.play("idle")

	velocity.y += grav
	move_and_slide()
