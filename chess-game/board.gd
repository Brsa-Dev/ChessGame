extends Node

enum CaseType {
	NORMAL, LAVE, EAU, VIDE, FORET, MUR, TOUR
}

var plateau = []

func _ready():
	init_plateau()

func init_plateau():
	# On repart d'un plateau vide à chaque initialisation
	plateau.clear()
	for x in range(8):
		plateau.append([])
		for y in range(8):
			plateau[x].append(CaseType.NORMAL)
	_generer_cases_speciales()
	print("Plateau initialisé !")

func _generer_cases_speciales():
	# Pour chaque type spécial, on place entre 1 et 3 cases aléatoirement
	# TOUR est exclu — elle sera placée manuellement plus tard
	var types_speciaux = [CaseType.LAVE, CaseType.EAU, CaseType.VIDE, CaseType.FORET, CaseType.MUR]
	
	for type in types_speciaux:
		var nombre = randi_range(1, 3)
		for i in range(nombre):
			var x = randi_range(0, 7)
			var y = randi_range(0, 7)
			plateau[x][y] = type

# Retourne le type d'une case à la position (x, y)
func get_case(x: int, y: int) -> CaseType:
	return plateau[x][y]
