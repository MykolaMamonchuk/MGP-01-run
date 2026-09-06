## Разова покупка «Повна гра». Заглушка; Play Billing / StoreKit — у вертикальному зрізі.
## Autoload: Purchase.
extends Node

const PRODUCT_FULL := "mgp_run_full_game"

signal purchase_finished(product: String, success: bool)

func is_full_game() -> bool:
	return bool(SaveService.data.get("full_game", false))

## Викликати ТІЛЬКИ після ParentGate("money").
func buy_full_game() -> void:
	# TODO: стор. Поки — локальний debug-розблок лише в редакторі.
	if OS.has_feature("editor"):
		SaveService.data["full_game"] = true
		SaveService.save_game()
		purchase_finished.emit(PRODUCT_FULL, true)
	else:
		purchase_finished.emit(PRODUCT_FULL, false)

func restore() -> void:
	purchase_finished.emit(PRODUCT_FULL, is_full_game())
