extends Node2D

@onready var grid = $Grid  # Référence au nœud TileMapLayer

func _ready():
	generate_grid()

func generate_grid():
	for x in range(8):
		for y in range(8):
			grid.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
