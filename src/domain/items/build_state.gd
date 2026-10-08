extends RefCounted
class_name IsmaelBuildState

var owned_items: Dictionary = {}
var tag_counts: Dictionary = {}
var active_synergies: Dictionary = {}

func register_item(item_id: String, tags: Array[String], synergy_definitions: Dictionary) -> Array[String]:
	owned_items[item_id] = int(owned_items.get(item_id,0))+1
	for tag in tags:
		tag_counts[tag] = int(tag_counts.get(tag,0))+1
	var newly_active: Array[String] = []
	for synergy_id in synergy_definitions.keys():
		if bool(active_synergies.get(synergy_id,false)):
			continue
		var definition: Dictionary = synergy_definitions[synergy_id]
		if _meets_definition(definition):
			active_synergies[synergy_id] = true
			newly_active.append(String(synergy_id))
	return newly_active

func _meets_definition(definition: Dictionary) -> bool:
	var required_tags: Dictionary = definition.get("requires_tags",{})
	for tag in required_tags.keys():
		if int(tag_counts.get(tag,0)) < int(required_tags[tag]):
			return false
	var required_items: Array = definition.get("requires_items",[])
	for item_id in required_items:
		if int(owned_items.get(String(item_id),0)) <= 0:
			return false
	return true

func has_synergy(synergy_id: String) -> bool:
	return bool(active_synergies.get(synergy_id,false))

func snapshot() -> Dictionary:
	return {
		"owned_items":owned_items.duplicate(true),
		"tag_counts":tag_counts.duplicate(true),
		"active_synergies":active_synergies.duplicate(true)
	}
