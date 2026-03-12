# Classe/Sort/mage_sorts.gd
# -----------------------------------------------
# SORTS DU MAGE
# -----------------------------------------------
extends Node

static func creer_sorts() -> Array:
	const SortScript = preload("res://sort.gd")
	return [
		# Sort 1 — Boule de Feu (touche A)
		# Sort simple et rapide, CD 1 tour
		SortScript.creer(
			"mage_boule_feu",
			"Boule de Feu",
			20,   # 20 dégâts
			3,    # Portée 3
			1,    # CD 1 tour
			0,    # Pas de coût gold
			false,# Pas de ligne de vue
			"20 dégâts (portée 3)"
		),
		# Sort 2 — Gel (touche Z)
		# Immobilise un ennemi 2 tours
		SortScript.creer(
			"mage_gel",
			"Gel",
			0,    # Pas de dégâts
			4,    # Portée 4
			3,    # CD 3 tours
			0,
			false,
			"Immobilise un ennemi 2 tours"
		),
		# Sort 3 — Météore (touche E)
		# Tombe 2 tours après le lancer
		SortScript.creer(
			"mage_meteore",
			"Météore",
			25,   # 25 dégâts sur zone 3x3
			5,    # Portée 5
			2,    # CD 2 tours
			0,
			false,
			"25 dégâts zone 3x3 — tombe dans 2 tours"
		),
		# Sort 4 — Tempête Arcanique (touche R)
		# Frappe tous les ennemis visibles, coûte 5 Gold
		SortScript.creer(
			"mage_tempete",
			"Tempête Arcanique",
			20,   # 20 dégâts par ennemi
			0,    # Portée illimitée (0 = illimité)
			4,    # CD 4 tours
			5,    # Coût 5 Gold
			true, # Ligne de vue requise
			"20 dégâts sur tous les ennemis visibles (5 Gold)"
		),
	]
