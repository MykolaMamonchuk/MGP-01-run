## Замірник заїкання на частинках. Не частина гри.
##
## Навіщо. Гра підвисає саме на ПЕРШИХ частинках. Підозра — компіляція шейдера: матеріал
## створюється на льоту, і перший кадр, у якому він з'явився, рушій витрачає на компіляцію.
## Щоб не гадати, міряємо час кожного кадру й дивимось, наскільки просідає той, у якому
## ефект спрацював УПЕРШЕ, проти того самого ефекту вдруге.
##
## Запуск (обов'язково З ВІКНОМ — у headless шейдери не компілюються взагалі):
##     godot res://tools/perf/fx_bench.tscn
##
## Звіт іде в консоль рядками "FXBENCH …".
extends Node3D

const SETTLE := 90          ## кадрів на розігрів, перш ніж щось міряти
const GAP := 45             ## кадрів між ефектами (щоб просідання не злипались)
const WINDOW := 12          ## скільки кадрів після пострілу вважаємо «наслідком»

var _frame := 0
var _last_us := 0
var _plan: Array = []
var _log: Array = []
var _pending: Array = []


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.3, 0.4)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	env.environment = e
	add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.0)
	add_child(cam)
	cam.current = true

	# кожен ефект стріляємо ДВІЧІ: перший раз ловить компіляцію, другий — чисту вартість
	for pass_i in 2:
		for name in ["dust", "burst", "splash", "confetti", "sparkles", "stars"]:
			_plan.append({"at": SETTLE + _plan.size() * GAP, "what": name, "pass": pass_i + 1})
	# PREHEAT=1 — спершу прогріти, щоб побачити, чи зникає затримка першого спрацювання
	if OS.get_environment("PREHEAT") != "":
		FX.preheat(self, Vector3(0, 0.4, 0))
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := float(now - _last_us) / 1000.0
	_last_us = now
	_frame += 1

	for item in _pending:
		if _frame - int(item["frame"]) <= WINDOW:
			item["peak"] = maxf(float(item["peak"]), ms)

	for shot in _plan:
		if int(shot["at"]) == _frame:
			_fire(String(shot["what"]))
			_pending.append({"frame": _frame, "peak": 0.0,
				"what": shot["what"], "pass": shot["pass"]})

	if _frame > SETTLE and _pending.size() == _plan.size():
		var done := true
		for item in _pending:
			if _frame - int(item["frame"]) <= WINDOW:
				done = false
		if done:
			_report()
			get_tree().quit()


func _fire(what: String) -> void:
	var at := Vector3(0, 0.4, 0)
	match what:
		"dust": FX.dust(self, at)
		"burst": FX.burst(self, at, Palette.STAR)
		"splash": FX.splash(self, at, Palette.SPLASH_WATER)
		"confetti": FX.confetti(self, at, 40)
		"sparkles":
			var p := FX.sparkles(self, 0.5, 12)
			get_tree().create_timer(1.0).timeout.connect(p.queue_free)
		"stars":
			var mi := MeshInstance3D.new()
			mi.mesh = FX.star_mesh(Palette.STAR)
			mi.position = at
			add_child(mi)


func _report() -> void:
	print("FXBENCH ефект            перший раз    вдруге    різниця")
	var first := {}
	for item in _pending:
		if int(item["pass"]) == 1:
			first[item["what"]] = float(item["peak"])
	var worst := 0.0
	for item in _pending:
		if int(item["pass"]) != 2:
			continue
		var a := float(first.get(item["what"], 0.0))
		var b := float(item["peak"])
		worst = maxf(worst, a - b)
		print("FXBENCH %-16s %8.1f мс %8.1f мс %8.1f мс" % [item["what"], a, b, a - b])
	print("FXBENCH найбільша разова затримка на першому спрацюванні: %.1f мс" % worst)
