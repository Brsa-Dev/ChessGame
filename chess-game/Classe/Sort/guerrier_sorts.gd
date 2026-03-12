# -----------------------------------------------
# SORTS DU GUERRIER
# Chargés et gérés par guerrier.gd
# -----------------------------------------------
extends "res://joueur.gd"

# -----------------------------------------------
# Initialise les 4 sorts du Guerrier
# Appelée dans _ready() de guerrier.gd
# -----------------------------------------------
static func creer_sorts() -> Array:
	const SortScript = preload("res://sort.gd")
	return [
		# Sort 1 — Mur (touche A)
		# Crée une case MUR sur le plateau
		SortScript.creer(
			"guerrier_mur",
			"Mur",
			0,    # Pas de dégâts
			3,    # Portée 3
			2,    # CD 2 tours
			0,    # Pas de coût gold
			false,# Pas de ligne de vue
			"Crée une case Mur (dure 2 tours)"
		),
		# Sort 2 — Hache Empoisonnée (touche Z)
		# Dégâts immédiats + DoT 3 tours
		SortScript.creer(
			"guerrier_hache",
			"Hache Empoisonnée",
			5,    # 5 dégâts immédiats
			3,    # Portée 3
			2,    # CD 2 tours
			0,    # Pas de coût gold
			true, # Ligne de vue requise
			"5 dégâts + 5/tour pendant 3 tours"
		),
		# Sort 3 — Coup de Bouclier (touche E)
		# Gros dégâts + repousse de 2 cases
		SortScript.creer(
			"guerrier_bouclier",
			"Coup de Bouclier",
			30,   # 30 dégâts
			1,    # Corps à corps
			3,    # CD 3 tours
			0,
			false,
			"30 dégâts + repousse de 2 cases"
		),
		# Sort 4 — Rage Berserker (touche R)
		# Buff offensif puissant pendant 2 tours
		SortScript.creer(
			"guerrier_rage",
			"Rage Berserker",
			0,    # Pas de dégâts directs
			0,    # Sur soi-même
			4,    # CD 4 tours
			0,
			false,
			"x2 attaque, +2 PM, immunité (2 tours)"
		),
	]
