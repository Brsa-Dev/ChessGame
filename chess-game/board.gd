extends Node

enum CaseType {
	NORMAL, LAVE, EAU, VIDE, FORET, MUR, TOUR
}

var plateau = []

# Liste des positions occupées par les joueurs
# Format : { "x,y": true }
var positions_occupees: Dictionary = {}

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
	
	plateau[0][0] = CaseType.TOUR
	plateau[7][0] = CaseType.TOUR
	plateau[0][7] = CaseType.TOUR
	plateau[7][7] = CaseType.TOUR
	
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
	
func occuper_case(x: int, y: int):
	positions_occupees[str(x) + "," + str(y)] = true

# Libère la case quand un joueur la quitte
func liberer_case(x: int, y: int):
	positions_occupees.erase(str(x) + "," + str(y))

# Retourne true si la case est déjà occupée par un joueur
func case_occupee(x: int, y: int) -> bool:
	return positions_occupees.has(str(x) + "," + str(y))
