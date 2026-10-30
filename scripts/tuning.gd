class_name Tuning
extends Resource
## Every balance and game-feel value lives here so it can be edited in the
## Inspector (data/tuning.tres) while the game is running.

@export_group("Building")
@export var cols := 3
@export var floors := 3
@export var room_w := 360.0
@export var room_h := 230.0
@export var slab := 40.0
@export var depth := 220.0
@export var wall_margin := 18.0
@export var door_height := 150.0

@export_group("Fake 3D")
## Distance from the eye to the cut plane. Lower means stronger perspective.
@export var focal := 560.0
## How far above each floor the eye sits. Higher shows more of the floor.
@export var eye_h := 400.0
@export var actor_scale := 3.6
@export var camera_zoom := 1.0

@export_group("Player")
@export var move_speed := 200.0
@export var depth_speed_ratio := 0.75
@export var accel_time := 0.08
@export var max_hp := 100.0
@export var dash_speed := 720.0
@export var dash_time := 0.2
@export var dash_iframes := 0.25
@export var dash_cooldown := 6.0
@export var climb_time := 0.55

@export_group("Gun")
@export var fire_rate := 6.0
@export var bullet_damage := 10.0
@export var bullet_speed := 1100.0
@export var aim_range := 560.0
@export var close_range := 90.0

@export_group("Feedback")
@export var hit_flash_time := 0.07
@export var number_time := 0.5
@export var hitstop_big := 0.04
@export var shake_max := 16.0
@export var shot_trauma := 0.05

@export_group("Run")
@export var danger_interval := 30.0
@export var wave_warning := 10.0
@export var early_exit_opens_at := 120.0
@export var early_exit_hold := 5.0
@export var rescue_opens_at := 180.0
@export var rescue_call_hold := 1.0
@export var rescue_time := 35.0
@export var rescue_gold_bonus := 0.5
@export var boss_at := 210.0
@export var crate_open_times: Array[float] = [1.0, 2.5, 5.0]
@export var backpack_slots := 12
@export var death_keep_gold := 0.2
@export var max_zombies := 150
@export var zombie_hp_per_danger := 1.10


func wave_size(danger: int) -> int:
	if danger <= 2:
		return 5 + (danger - 1) * 5
	if danger <= 5:
		return 15 + (danger - 3) * 5
	if danger <= 8:
		return 30 + (danger - 6) * 10
	return 60 + (danger - 9) * 5
