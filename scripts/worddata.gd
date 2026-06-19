class_name WordData
extends Resource

@export var id: String = ""
@export var text: String = ""

enum Category { POLICY, ABSURD, EMOTIONAL, ACTION, RHETORICAL, CLOSER }
@export var category: Category = Category.POLICY
