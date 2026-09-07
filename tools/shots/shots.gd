## Знімки-еталони для перевірки, що оптимізація не зіпсувала картинку.
## Не частина гри — інструмент для docs/optimisation.
##
##   SHOT_TAG=before godot --path <старий-worktree> --fixed-fps 60 res://tools/shots/shots.tscn
##   SHOT_TAG=after  godot --fixed-fps 60 res://tools/shots/shots.tscn
##
## Кадри лягають у user://shots/<тег>/, поряд друкується статистика декору.
##
## ВАЖЛИВО:
## - `--fixed-fps 60` обов'язковий, і чекати треба кадрами, а не таймерами: інакше швидша
##   збірка встигає інше число кроків, стан гри розходиться і порівнювати нічого.
## - Однакове зерно дає однаковий декор ЛИШЕ якщо порядок викликів випадковості не змінився.
##   Якщо змінився (наприклад, предмет перестав бути вузлом), кадри порівнюють очима, а збіг
##   перевіряють за статистикою: скільки предметів на ряд і якої медіани.
extends Node

const SEED := 20260907

var _run: Node
var _dir := "user://shots/%s" % (OS.get_environment("SHOT_TAG") if OS.has_environment("SHOT_TAG") else "cur")


func _ready() -> void:
	seed(SEED)
	DirAccess.make_dir_recursive_absolute(_dir)
	_run = load("res://src/run3d/run3d.tscn").instantiate()
	add_child(_run)
	await _frames(30)
	_run.menu.hide_menu()
	_run._start_level(1)
	await _frames(300)
	await _shot("01-meadow-3lanes")
	_run.track.set_lanes(7, true)
	await _frames(90)
	await _shot("02-meadow-7lanes")
	_run.track.set_lanes(3, false)
	await _frames(18)
	_run._enter_world("forest", false)
	await _frames(21)
	await _shot("03-forest-rebuild-anim")   # ловимо «перебудову кубиками» посередині
	await _frames(150)
	await _shot("04-forest")
	_run._enter_world("beach", false)
	await _frames(150)
	await _shot("05-beach-sea")
	print("SHOT done -> ", _dir)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


## Скільки предметів декору в трасі — щоб порівняти розподіл між збірками.
func _stats() -> String:
	var t = _run.track
	var per_row := []
	var total := 0
	var critters := 0
	for i in range(t._rows.size()):
		per_row.append((t._decor_ids[i] as PackedInt32Array).size())
		total += per_row[i]
		critters += t._rows[i].get_child_count()
	per_row.sort()
	return "декор: усього %d, медіана на ряд %d, макс %d, живності вузлами %d" % [
		total, per_row[per_row.size() / 2], per_row[per_row.size() - 1], critters]


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, shot_name])
	print("SHOT ", shot_name, "  ", _stats())
