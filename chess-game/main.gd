extends Node2D

@onready var board = $Board
@onready var renderer = $Renderer

func _ready():
	# On assigne d'abord la référence au board...
	renderer.board = board
	# ...puis on déclenche le dessin maintenant que board est connu
	renderer.queue_redraw()
	print("Main prêt !")

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var cell = renderer.screen_to_grid(event.position)
		if cell.x >= 0 and cell.x < 8 and cell.y >= 0 and cell.y < 8:
			print("Case cliquée : (", cell.x, ", ", cell.y, ")")
