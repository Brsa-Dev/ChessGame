# -----------------------------------------------
# SORTS DU MAGE
# Chargés et gérés par mage.gd
# -----------------------------------------------
extends Node

static func creer_sorts() -> Array:
	const SortScript = preload("res://sort.gd")
	return [
		# Sort 1 — Boule de Feu (touche A)
		# CD court (1 tour) → coût PM faible : 1 PM
		SortScript.creer(
			"mage_boule_feu",
			"Boule de Feu",
			20,    # 20 dégâts
			3,     # Portée 3
			1,     # CD 1 tour
			0,     # Pas de coût gold
			1,     # ← Coût 1 PM (sort rapide, CD compense)
			false, # Pas de ligne de vue
			"20 dégâts (portée 3)"
		),
		# Sort 2 — Gel (touche Z)
		# Contrôle fort (2 tours) → 2 PM
		SortScript.creer(
			"mage_gel",
			"Gel",
			0,     # Pas de dégâts
			4,     # Portée 4
			3,     # CD 3 tours
			0,
			2,     # ← Coût 2 PM
			false,
			"Immobilise un ennemi 2 tours"
		),
		# Sort 3 — Météore (touche E)
		# Zone 3x3 + lave → sort fort, 3 PM
		SortScript.creer(
			"mage_meteore",
			"Météore",
			25,    # 25 dégâts zone
			5,     # Portée 5
			2,     # CD 2 tours
			0,
			3,     # ← Coût 3 PM (impact majeur sur le terrain)
			false,
			"25 dégâts zone 3x3 — tombe dans 2 tours"
		),
		# Sort 4 — Tempête Arcanique (touche R)
		# Cible tout le monde + coûte 5 Gold → 3 PM
		SortScript.creer(
			"mage_tempete",
			"Tempête Arcanique",
			20,    # 20 dégâts par ennemi
			0,     # Portée illimitée (0 = illimité)
			4,     # CD 4 tours
			5,     # Coût 5 Gold
			3,     # ← Coût 3 PM (double coût Gold+PM pour équilibrer)
			true,  # Ligne de vue requise
			"20 dégâts sur tous les ennemis (5 Gold)"
		),
	]
