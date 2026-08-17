class_name ElevatorUpgradeDefinition
extends RefCounted

## Immutable description of one run-only system improvement.
## `effect` stays data-shaped so future UI can render choices without owning
## simulation behavior.
var id: String
var title: String
var description: String
var effect: Dictionary


func _init(
	upgrade_id: String,
	upgrade_title: String,
	upgrade_description: String,
	upgrade_effect: Dictionary,
) -> void:
	id = upgrade_id
	title = upgrade_title
	description = upgrade_description
	effect = upgrade_effect.duplicate(true)
