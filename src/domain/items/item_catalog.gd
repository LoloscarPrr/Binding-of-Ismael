extends RefCounted
class_name IsmaelItemCatalog

const REWARD_ORDER: Array[String] = [
	"vida","curacion","movimiento","cadencia","proyectil","dano",
	"buscadora","perforante","escudo","rafaga","mapa","monedero"
]

const REWARDS := {
	"vida":{"title":"CORAZÓN VOTIVO","effect":"+1 VIDA MÁXIMA"},
	"curacion":{"title":"VENDA RITUAL","effect":"CURA 1 CADA 3 SALAS"},
	"movimiento":{"title":"BOTAS GASTADAS","effect":"+ MOVIMIENTO"},
	"cadencia":{"title":"RELOJ ROTO","effect":"+ CADENCIA"},
	"proyectil":{"title":"LÁGRIMA DE VIDRIO","effect":"+ VELOCIDAD DE LÁGRIMA"},
	"dano":{"title":"OJO ROJO","effect":"+ DAÑO"},
	"buscadora":{"title":"OJO DE POLILLA","effect":"LÁGRIMAS BUSCADORAS"},
	"perforante":{"title":"AGUJA HUECA","effect":"LÁGRIMAS PERFORANTES"},
	"escudo":{"title":"ROSARIO DE HIERRO","effect":"BLOQUEA 1 GOLPE POR PISO"},
	"rafaga":{"title":"GUANTE NERVIOSO","effect":"RÁFAGA DE 3 LÁGRIMAS"},
	"mapa":{"title":"MAPA QUEMADO","effect":"REVELA EL PISO"},
	"monedero":{"title":"MONEDERO VIEJO","effect":"+ ECONOMÍA POR SALA"}
}

const PICKUPS := {
	"heart":{"title":"CORAZÓN"},
	"coin":{"title":"MONEDA"},
	"bomb":{"title":"BOMBA"},
	"key":{"title":"LLAVE"}
}

static func reward_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in REWARD_ORDER:
		ids.append(id)
	return ids

static func reward_definition(id: String) -> Dictionary:
	if REWARDS.has(id):
		return Dictionary(REWARDS[id]).duplicate(true)
	return {"title":id.to_upper(),"effect":""}

static func reward_full_name(id: String) -> String:
	var definition := reward_definition(id)
	var title := String(definition.get("title",id.to_upper()))
	var effect := String(definition.get("effect",""))
	return title if effect.is_empty() else "%s\n%s" % [title,effect]

static func pickup_definition(id: String) -> Dictionary:
	if PICKUPS.has(id):
		return Dictionary(PICKUPS[id]).duplicate(true)
	return {"title":id.to_upper()}

static func pickup_name(id: String) -> String:
	return String(pickup_definition(id).get("title",id.to_upper()))

static func shop_stock(floor_index: int) -> Array[Dictionary]:
	var stock: Array[Dictionary] = []
	if floor_index <= 1:
		stock.append({"type":"reward","reward":"curacion","cost":4,"name":"VENDA"})
		stock.append({"type":"reward","reward":"cadencia","cost":6,"name":"RELOJ"})
		stock.append({"type":"reward","reward":"monedero","cost":8,"name":"MONEDERO"})
	else:
		stock.append({"type":"reward","reward":"movimiento","cost":5,"name":"BOTAS"})
		stock.append({"type":"reward","reward":"perforante","cost":7,"name":"AGUJA"})
		stock.append({"type":"reward","reward":"escudo","cost":9,"name":"ROSARIO"})

	# Consumibles básicos: un puesto de cada tipo por tienda y por piso.
	# Los precios son deliberadamente menores que los objetos permanentes para
	# que comprar recursos sea una decisión útil durante una run, no un lujo.
	stock.append({"type":"pickup","reward":"heart","cost":3,"name":"CORAZÓN"})
	stock.append({"type":"pickup","reward":"bomb","cost":3,"name":"BOMBA"})
	stock.append({"type":"pickup","reward":"key","cost":4,"name":"LLAVE"})
	return stock
