## Глобальна шина подій гри. Autoload: Events.
extends Node

signal star_collected(amount: int)
signal hero_tumbled(kind: String)
signal obstacle_passed(kind: String)
signal obstacle_spawned(kind: String, node: Node2D)
signal player_input()               # будь-який тап/утримання дитини
signal gameplay_input()             # тап саме під час бігу (не станція/сон/екран батьків)
signal checkpoint_reached(index: int)
signal profile_changed(profile: String)
signal session_warning(seconds_left: int)
signal session_finished()
