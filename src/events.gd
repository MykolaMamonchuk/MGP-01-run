## Глобальна шина подій гри. Autoload: Events.
extends Node

signal star_collected(amount: int)
signal hero_tumbled(kind: String)
signal obstacle_passed(kind: String)
## seconds_to_hero — через скільки секунд перешкода дійде до героя (для виміру реакції у AgeAdapt).
signal obstacle_spawned(kind: String, seconds_to_hero: float)
signal player_input()               # будь-який тап/утримання дитини
signal gameplay_input()             # дія саме під час руху (не станція/сон/екран батьків)
signal checkpoint_reached(index: int)
signal profile_changed(profile: String)
signal session_warning(seconds_left: int)
signal session_finished()
signal world_changed(world_id: String)          # Розвилка: обрано новий сегмент
signal mini_event_started(event_id: String)
signal mini_event_finished(event_id: String)
signal quest_completed(quest_id: String, reward: int)
