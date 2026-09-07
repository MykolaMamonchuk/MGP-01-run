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
# v1.3: життя, пікапи, перегравання рівня
signal hearts_changed(hearts: int)                   # серця героя змінились (втрата/сердечко/скидання)
signal pickup_started(kind: String, seconds: float)  # підібрано пікап із тривалістю (0 — миттєвий)
signal pickup_ended(kind: String)                    # дія пікапа закінчилась (час або щит поглинув удар)
signal level_restarted(level: int)                   # серця скінчились — рівень починається знову
