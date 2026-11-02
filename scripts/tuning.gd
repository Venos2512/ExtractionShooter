class_name Tuning
extends Resource
## Every balance and game-feel value lives here so it can be edited in the
## Inspector (data/tuning.tres) while the game is running.

@export_group("Test build")
## The arena with one sample alien, instead of the random map and its swarm. Turn off,
## or run with --oldmap, for the old game.
@export var sample_build := true

@export_group("Map")
## Grid the random map is carved from. The last two columns are the landing zone.
@export var cols := 12
@export var floors := 3
@export var room_w := 546.0
@export var room_h := 230.0
@export var slab := 40.0
@export var wall_margin := 18.0
@export var door_height := 150.0
## Odds the route changes floor in a column.
@export var route_turn_chance := 0.45
## Odds an empty cell next to the map becomes a side room.
@export var side_room_chance := 0.55
## Odds two rooms joined by a door become one long hall.
@export var hall_chance := 0.2

@export_group("Camera")
## Size of one art pixel on screen for actors and the building.
@export var pixel_scale := 2.0
## 886 / 720: the screen is wider than the art was sized for, so this keeps the hero and
## the alien the same size against its width.
@export var camera_zoom := 1.2306
## How far above the hero the camera centers.
@export var camera_lift := 170.0
## The same in the arena, which centers the room and leaves the lower screen to the thumbs.
@export var arena_camera_lift := 280.0

@export_group("Parallax")
## 0 stays glued to the screen, 1 moves with the world, above 1 passes in front.
@export var scroll_meteor := 0.03
@export var scroll_far := 0.1
@export var scroll_smog := 0.16
@export var scroll_mid := 0.22
@export var scroll_near := 0.42
@export var scroll_embers_back := 0.55
@export var scroll_street := 0.68
## How big the back wall of each room is against its front, which is the play plane.
## The room's two side walls, floor and ceiling fill the space between, and turn as
## the camera moves. Lower is deeper, 1 is flat.
@export var scroll_walls := 0.78
@export var scroll_embers_front := 1.25
## Pillars, cables and rubble heaps pinned to rooms.
@export var scroll_front := 1.3
@export var scroll_rubble := 1.7

@export_group("Player")
@export var move_speed := 200.0
@export var accel_time := 0.08
@export var max_hp := 100.0
@export var dash_speed := 720.0
@export var dash_time := 0.2
@export var dash_iframes := 0.25
@export var dash_cooldown := 4.0
@export var gravity := 1700.0
@export var climb_time := 0.55

@export_group("Gun")
@export var fire_rate := 3.0
@export var bullet_damage := 20.0
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
@export var early_exit_hold := 5.0
@export var rescue_call_hold := 1.0
@export var rescue_time := 35.0
@export var rescue_gold_bonus := 0.5
@export var boss_at := 210.0
@export var crate_open_times: Array[float] = [1.0, 2.5, 5.0]
@export var backpack_slots := 12
@export var death_keep_gold := 0.2
@export var max_bugs := 150
@export var bug_hp_per_danger := 1.10


func wave_size(danger: int) -> int:
	if danger <= 2:
		return 5 + (danger - 1) * 5
	if danger <= 5:
		return 15 + (danger - 3) * 5
	if danger <= 8:
		return 30 + (danger - 6) * 10
	return 60 + (danger - 9) * 5
