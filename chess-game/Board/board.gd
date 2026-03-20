# =======================================================
# Board/board.gd
# -------------------------------------------------------
# Cerveau du plateau — NE gère PAS l'affichage.
#
#   - Définit les types de cases (enum CaseType)
#   - Stocke l'état du plateau dans un tableau 2D
#   - Gère les cases occupées par les joueurs
#   - Génère les cases spéciales au démarrage
#
# Séparé de renderer.gd : la logique reste indépendante du visuel,
# ce qui permettra de remplacer le rendu 2D par Blender sans toucher ici.
# =======================================================
extends Node


# =======================================================
# CONSTANTES — Plateau
# =======================================================

const TAILLE_PLATEAU : int = 8  # Plateau carré N×N


# =======================================================
# CONSTANTES — Génération des cases spéciales
# =======================================================

# Nombre de cases générées par type spécial au démarrage
const NB_MIN_CASES_SPECIALES : int = 1
const NB_MAX_CASES_SPECIALES : int = 3


# =======================================================
# TYPES DE CASES
# -------------------------------------------------------
# Utilisé dans tout le projet pour identifier les cases.
# Les valeurs entières sont utilisées comme clés dans les
# dictionnaires de couleurs de renderer.gd.
# =======================================================
enum CaseType {
	NORMAL,  # Case traversable sans effet
	LAVE,    # Dégâts à l'arrivée + dégâts persistants en fin de tour
	EAU,     # Soin à l'arrivée + soin persistant en fin de tour
	VIDE,    # Infranchissable — trou dans le plateau
	FORET,   # Coûte 2 PM à traverser + résistance passive +10%
	MUR,     # Infranchissable — obstacle solide (posable par Guerrier)
	TOUR     # Bonus portée sorts (+1), indestructible, fixe dans les coins
}


# =======================================================
# ÉTAT DU PLATEAU
# =======================================================

# Tableau 2D [x][y] → CaseType
# Accès : plateau[x][y] pour lire/modifier le type d'une case
var plateau : Array = []

# Cases actuellement occupées par un joueur vivant
# Clé : "x,y" → true — bloque déplacement et placement
var _positions_occupees : Dictionary = {}


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	_initialiser_plateau()


# -------------------------------------------------------
# Remet le plateau à zéro et régénère les cases spéciales.
# Peut être rappelée pour réinitialiser une partie.
# -------------------------------------------------------
func _initialiser_plateau() -> void:
	plateau.clear()

	for x in range(TAILLE_PLATEAU):
		plateau.append([])
		for y in range(TAILLE_PLATEAU):
			plateau[x].append(CaseType.NORMAL)

	_generer_cases_speciales()

	# Les Tours sont placées après la génération aléatoire pour
	# garantir qu'elles ne soient pas écrasées par une case spéciale
	_placer_tours_coins()


# -------------------------------------------------------
# Génère aléatoirement les cases spéciales (Lave, Eau, etc.)
# Les Tours sont exclues — elles sont placées séparément dans les coins.
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
		var nb : int = randi_range(NB_MIN_CASES_SPECIALES, NB_MAX_CASES_SPECIALES)
		for _i in range(nb):
			var x : int = randi_range(0, TAILLE_PLATEAU - 1)
			var y : int = randi_range(0, TAILLE_PLATEAU - 1)
			plateau[x][y] = type_case


# -------------------------------------------------------
# Place une Tour dans chaque coin du plateau.
# Les Tours ne peuvent pas être remplacées ni détruites.
# -------------------------------------------------------
func _placer_tours_coins() -> void:
	var coins : Array[Vector2i] = [
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
# CASES OCCUPÉES
# -------------------------------------------------------
# Une case occupée bloque tout déplacement et placement.
# Libérée quand le joueur quitte la case ou est éliminé.
# =======================================================

func occuper_case(x: int, y: int) -> void:
	_positions_occupees[_cle_case(x, y)] = true


func liberer_case(x: int, y: int) -> void:
	_positions_occupees.erase(_cle_case(x, y))


func case_occupee(x: int, y: int) -> bool:
	return _positions_occupees.has(_cle_case(x, y))


# -------------------------------------------------------
# Génère une clé string unique pour une position
# Format "x,y" — utilisé comme clé du dictionnaire
# -------------------------------------------------------
func _cle_case(x: int, y: int) -> String:
	return "%d,%d" % [x, y]
