class_name RaceNames
extends RefCounted

## Race labels stay unique and keep their points when a cup's roster changes.
## Entries have identity, name and a human field for the people racing.
var _assigned := {}


func assign(entries: Array) -> void:
	var reserved := {}
	for label in _assigned.values():
		reserved[label] = true
	for entry in entries:
		reserved[entry.name] = true
	var order := range(entries.size())
	order.sort_custom(func(a, b):
		var a_human: bool = entries[a].has("human")
		var b_human: bool = entries[b].has("human")
		return a_human if a_human != b_human else a < b)
	var used := {}
	for label in _assigned.values():
		used[label] = true
	for i in order:
		var entry: Dictionary = entries[i]
		var identity: String = entry.identity
		if not _assigned.has(identity):
			var base: String = entry.name
			var label := base
			var suffix := 2
			while used.has(label):
				label = "%s %d" % [base, suffix]
				while reserved.has(label):
					suffix += 1
					label = "%s %d" % [base, suffix]
			_assigned[identity] = label
			used[label] = true
			reserved[label] = true
		entry.name = _assigned[identity]
