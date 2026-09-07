## Капелюшки — тонка обгортка над Shop (слот "hat"), щоб старі виклики (hero3d.set_hat, wheel, run3d) працювали.
## Старий id "none" відображається на "hat_none".
class_name Hats
extends RefCounted


static func _id(id: String) -> String:
	return Shop.none_id("hat") if id == "none" or id == "" else id


static func load_all() -> Array:
	return Shop.by_slot(Shop.load_all(), "hat")


static func find(all: Array, id: String) -> Dictionary:
	return Shop.find(all, _id(id))


static func is_owned(def: Dictionary, owned: Array) -> bool:
	return Shop.is_owned(def, owned)


static func try_buy(def: Dictionary, stars: int, owned: Array) -> Dictionary:
	return Shop.try_buy(def, stars, owned)


static func random_unowned(all: Array, owned: Array, rng: RandomNumberGenerator) -> String:
	return Shop.random_unowned(all, owned, rng, "hat")


static func owned() -> Array:
	return Shop.owned()


static func equipped() -> String:
	return Shop.equipped("hat")


static func equip(id: String) -> void:
	Shop.equip("hat", _id(id))


static func buy(def: Dictionary) -> bool:
	return Shop.buy(def)


static func grant(id: String) -> void:
	Shop.grant(id)
