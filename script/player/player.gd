extends CharacterBody2D

# ============================================================
# Player Controller - Metroidvania Movement
# Godot 4.x | CharacterBody2D
# ============================================================
# Inputs esperados no InputMap:
#   "right" -> D, Seta Direita
#   "left"  -> A, Seta Esquerda
#   "jump"  -> Espaço, K
# ============================================================

# --- Movimento Horizontal ---
@export_group("Movimento")
@export var max_speed: float = 200.0          ## Velocidade máxima horizontal
@export var acceleration: float = 1200.0      ## Aceleração no chão
@export var deceleration: float = 1400.0      ## Desaceleração no chão (freio)
@export var air_acceleration: float = 900.0   ## Aceleração no ar
@export var air_deceleration: float = 600.0   ## Desaceleração no ar
@export var turn_speed_boost: float = 1.6     ## Multiplicador ao mudar de direção (responsividade)

# --- Pulo e Gravidade ---
@export_group("Pulo")
@export var jump_height: float = 72.0         ## Altura máxima do pulo (pixels)
@export var jump_time_to_peak: float = 0.35   ## Tempo até o pico do pulo (segundos)
@export var jump_time_to_fall: float = 0.3    ## Tempo do pico até o chão (segundos)
@export var max_fall_speed: float = 500.0     ## Velocidade máxima de queda

# --- Mecânicas de Pulo Avançadas ---
@export_group("Mecânicas Avançadas")
@export var coyote_time: float = 0.1          ## Tempo extra para pular após sair da plataforma
@export var jump_buffer_time: float = 0.12    ## Buffer de input do pulo
@export var variable_jump_cut: float = 0.4    ## Multiplicador ao soltar o botão de pulo (pulo curto)

# --- Referências ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# --- Gravidade Calculada (assimétrica) ---
# Fórmulas baseadas em cinemática para controle preciso:
#   gravity_up   = 2 * jump_height / jump_time_to_peak²
#   gravity_down = 2 * jump_height / jump_time_to_fall²
#   jump_velocity = -2 * jump_height / jump_time_to_peak
@onready var gravity_up: float = (2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
@onready var gravity_down: float = (2.0 * jump_height) / (jump_time_to_fall * jump_time_to_fall)
@onready var jump_velocity: float = -(2.0 * jump_height) / jump_time_to_peak

# --- Estado Interno ---
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _is_jumping: bool = false
var _was_on_floor: bool = false
var _facing_direction: float = 1.0  # 1.0 = direita, -1.0 = esquerda


func _physics_process(delta: float) -> void:
	var input_direction: float = _get_input_direction()

	_update_timers(delta)
	_apply_gravity(delta)
	_handle_jump()
	_apply_horizontal_movement(input_direction, delta)
	_update_animation(input_direction)
	_update_sprite_direction(input_direction)

	_was_on_floor = is_on_floor()
	move_and_slide()


# ============================================================
# INPUT
# ============================================================

func _get_input_direction() -> float:
	return Input.get_axis("left", "right")


# ============================================================
# TIMERS (Coyote Time + Jump Buffer)
# ============================================================

func _update_timers(delta: float) -> void:
	# Coyote Time: permite pular por um curto período após sair da borda
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	# Se acabou de sair do chão sem pular, reseta o estado de pulo
	if _was_on_floor and not is_on_floor() and not _is_jumping:
		pass  # Coyote time já está ativo

	# Jump Buffer: registra a intenção de pulo antes de tocar o chão
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


# ============================================================
# GRAVIDADE (Assimétrica)
# ============================================================

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	# Gravidade mais forte na descida → pulo com mais "peso" e game feel
	var current_gravity: float
	if velocity.y < 0.0:
		current_gravity = gravity_up
	else:
		current_gravity = gravity_down

	velocity.y = minf(velocity.y + current_gravity * delta, max_fall_speed)


# ============================================================
# PULO
# ============================================================

func _handle_jump() -> void:
	var can_jump: bool = is_on_floor() or _coyote_timer > 0.0
	var wants_jump: bool = _jump_buffer_timer > 0.0

	# Executar pulo
	if can_jump and wants_jump:
		velocity.y = jump_velocity
		_is_jumping = true
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

	# Pulo variável: soltar o botão corta a altura do pulo
	if _is_jumping and velocity.y < 0.0 and Input.is_action_just_released("jump"):
		velocity.y *= variable_jump_cut

	# Reset do estado de pulo ao tocar o chão
	if is_on_floor():
		_is_jumping = false


# ============================================================
# MOVIMENTO HORIZONTAL (com aceleração/desaceleração)
# ============================================================

func _apply_horizontal_movement(input_dir: float, delta: float) -> void:
	if input_dir != 0.0:
		# Detecta se está mudando de direção (turn around)
		var is_turning: bool = signf(input_dir) != signf(velocity.x) and velocity.x != 0.0
		var accel: float

		if is_on_floor():
			accel = acceleration
		else:
			accel = air_acceleration

		# Boost ao mudar de direção → mais responsivo
		if is_turning:
			accel *= turn_speed_boost

		velocity.x = move_toward(velocity.x, input_dir * max_speed, accel * delta)
	else:
		# Desaceleração (mais rápida no chão, mais suave no ar)
		var decel: float
		if is_on_floor():
			decel = deceleration
		else:
			decel = air_deceleration

		velocity.x = move_toward(velocity.x, 0.0, decel * delta)


# ============================================================
# ANIMAÇÕES
# ============================================================

func _update_animation(input_dir: float) -> void:
	if not is_on_floor():
		if velocity.y < 0.0:
			_play_animation("jump")
		else:
			_play_animation("fall")
	elif absf(velocity.x) > 10.0 and input_dir != 0.0:
		_play_animation("walk")
	else:
		_play_animation("idle")


func _play_animation(anim_name: StringName) -> void:
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)


# ============================================================
# DIREÇÃO DO SPRITE (Flip)
# ============================================================

func _update_sprite_direction(input_dir: float) -> void:
	if input_dir != 0.0:
		_facing_direction = signf(input_dir)
		sprite.flip_h = _facing_direction < 0.0
