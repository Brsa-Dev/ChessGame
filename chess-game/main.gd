extends Node2D

@onready var renderer = $Renderer

func _ready():
	print("Main prêt !")

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var cell = renderer.screen_to_grid(event.position)
		if cell.x >= 0 and cell.x < 8 and cell.y >= 0 and cell.y < 8:
			print("Case cliquée : (", cell.x, ", ", cell.y, ")")
