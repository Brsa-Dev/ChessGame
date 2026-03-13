# =======================================================
# board.gd
# -------------------------------------------------------
# Cerveau du plateau de jeu — NE gère PAS l'affichage.
#
#   - Définit les types de cases (enum CaseType)
#   - Stocke l'état du plateau (tableau 2D)
#   - Gère les cases occupées par les joueurs
#   - Génère les cases spéciales au démarrage
#
# Séparé de renderer.gd pour rester scalable
# (remplacement futur par un modèle 3D Blender).
# =======================================================
extends Node

# -------------------------------------------------------
# Constantes — dimensions du plateau
# -------------------------------------------------------
const TAILLE_PLATEAU    : int = 8   # Plateau carré N×N
const NB_TOURS_FIXES    : int = 4   # Une tour dans chaque coin

# -------------------------------------------------------
# Constantes — génération des cases spéciales
# -------------------------------------------------------
const NB_MIN_CASES_SPECIALES : int = 1  # Minimum de cases par type
const NB_MAX_CASES_SPECIALES : int = 3  # Maximum de cases par type

# -------------------------------------------------------
# Types de cases disponibles
# Utilisé dans tout le projet pour identifier les cases
# -------------------------------------------------------
enum CaseType {
	NORMAL,  # Case traversable sans effet
	LAVE,    # Dégâts à l'arrivée + persistants
	EAU,     # Soin à l'arrivée + persistant
	VIDE,    # Infranchissable (trou)
	FORET,   # Coûte 2 PM + résistance passive
	MUR,     # Infranchissable (obstacle)
	TOUR     # Bonus portée sorts, indestructible
}

# -------------------------------------------------------
# Tableau 2D représentant les types de cases
# Accès : plateau[x][y] → CaseType
# -------------------------------------------------------
var plateau : Array = []

# -------------------------------------------------------
# Cases actuellement occupées par un joueur
# Clé : "x,y" (String) → Valeur : true
# Utilisé pour bloquer le déplacement et le placement
# -------------------------------------------------------
var _positions_occupees : Dictionary = {}


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	_initialiser_plateau()


# -------------------------------------------------------
# Remet le plateau à zéro et génère les cases spéciales
# Peut être rappelée pour réinitialiser une partie
# -------------------------------------------------------
func _initialiser_plateau() -> void:
	plateau.clear()

	# Remplit le plateau de cases normales
	for x in range(TAILLE_PLATEAU):
		plateau.append([])
		for y in range(TAILLE_PLATEAU):
			plateau[x].append(CaseType.NORMAL)

	# Place les cases spéciales aléatoires
	_generer_cases_speciales()

	# Place les Tours fixes dans les 4 coins — indestructibles
	_placer_tours_coins()

	print("✅ Plateau %d×%d initialisé !" % [TAILLE_PLATEAU, TAILLE_PLATEAU])


# -------------------------------------------------------
# Génère aléatoirement les cases spéciales (Lave, Eau, etc.)
# Chaque type obtient entre NB_MIN et NB_MAX cases
# Les Tours sont exclues — elles sont placées manuellement
# -------------------------------------------------------
func _generer_cases_speciales() -> void:
	var types_a_generer : Array = [
		CaseType.LAVE,
		CaseType.EAU,
		CaseType.VIDE,
		CaseType.FORET,
		CaseType.MUR
	]
	for type_case in types_a_generer:
		var nombre_cases : int = randi_range(NB_MIN_CASES_SPECIALES, NB_MAX_CASES_SPECIALES)
		for _i in range(nombre_cases):
			var x : int = randi_range(0, TAILLE_PLATEAU - 1)
			var y : int = randi_range(0, TAILLE_PLATEAU - 1)
			plateau[x][y] = type_case


# -------------------------------------------------------
# Place une Tour dans chaque coin du plateau
# Les Tours sont fixes et ne peuvent pas être remplacées
# -------------------------------------------------------
func _placer_tours_coins() -> void:
	var coins : Array = [
		Vector2i(0,                  0                 ),
		Vector2i(TAILLE_PLATEAU - 1, 0                 ),
		Vector2i(0,                  TAILLE_PLATEAU - 1),
		Vector2i(TAILLE_PLATEAU - 1, TAILLE_PLATEAU - 1),
	]
	for coin in coins:
		plateau[coin.x][coin.y] = CaseType.TOUR


# =======================================================
# LECTURE DU PLATEAU
# =======================================================

# -------------------------------------------------------
# Retourne le type de la case en (x, y)
# -------------------------------------------------------
func get_case(x: int, y: int) -> CaseType:
	return plateau[x][y]


# =======================================================
# GESTION DES CASES OCCUPÉES
# -------------------------------------------------------
# Une case occupée ne peut pas être traversée
# ni ciblée pour un placement.
# =======================================================

# -------------------------------------------------------
# Marque la case (x, y) comme occupée par un joueur
# -------------------------------------------------------
func occuper_case(x: int, y: int) -> void:
	_positions_occupees[_cle_case(x, y)] = true


# -------------------------------------------------------
# Libère la case (x, y) quand un joueur la quitte
# -------------------------------------------------------
func liberer_case(x: int, y: int) -> void:
	_positions_occupees.erase(_cle_case(x, y))


# -------------------------------------------------------
# Retourne true si la case (x, y) est occupée
# -------------------------------------------------------
func case_occupee(x: int, y: int) -> bool:
	return _positions_occupees.has(_cle_case(x, y))


# -------------------------------------------------------
# Génère la clé string unique pour une position
# Format "x,y" — utilisé comme clé du dictionnaire
# -------------------------------------------------------
func _cle_case(x: int, y: int) -> String:
	return "%d,%d" % [x, y]
