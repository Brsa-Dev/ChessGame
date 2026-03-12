# -----------------------------------------------
# SORTS DE L'ARCHER
# Chargés et gérés par archer.gd
# -----------------------------------------------
extends "res://joueur.gd"

static func creer_sorts() -> Array:
	const SortScript = preload("res://sort.gd")
	return [
		# Sort 1 — Flèche Rebondissante (touche A)
		# Agit comme une attaque de base (déclenche a_attaque_ce_tour)
		# Dévastateur en forêt grâce au passif (+1 range, +10 atk)
		# CD court mais coût PM élevé pour compenser la portée 5
		SortScript.creer(
			"archer_fleche",
			"Flèche Rebondissante",
			20,    # 20 dégâts
			5,     # Portée 5
			1,     # CD 1 tour
			0,     # Pas de coût gold
			3,     # 3 PM — cher car même comportement qu'une attaque de base
			false, # Pas de ligne de vue
			"20 dmg + rebond (10 dmg) sur l'ennemi le plus proche si ligne de vue"		),
		# Sort 2 — Piège (touche Z)
		# Pose un piège INVISIBLE sur une case vide
		# Déclenché quand un ennemi marche dessus : 10 dmg + immobilisé 1 tour
		# Reste en place jusqu'à déclenchement
		SortScript.creer(
			"archer_piege",
			"Piège",
			10,    # 10 dégâts si déclenché
			2,     # Portée 2
			3,     # CD 3 tours
			0,     # Pas de coût gold
			1,     # 1 PM — utilitaire léger
			false, # Pas de ligne de vue
			"Pose un piège invisible (10 dmg + immobilise 1 tour si déclenché)"
		),
		# Sort 3 — Tir Ciblé (touche E)
		# Sort sniper — ligne de vue requise
		# Bonus si la cible est sur une case Forêt : 60 dmg au lieu de 40
		# Coût 5 Gold si cible sur forêt (dégâts bonus = contrepartie)
		SortScript.creer(
			"archer_tir_cible",
			"Tir Ciblé",
			40,    # 40 dégâts de base (60 si cible sur forêt)
			5,     # Portée 5
			3,     # CD 3 tours
			0,     # Coût gold variable — géré dans main.gd (0 ou 5)
			3,     # 3 PM — sort signature
			true,  # Ligne de vue requise
			"40 dmg (60 sur forêt, coûte 5 Gold)"
		),
		# Sort 4 — Pluie de Flèches (touche R)
		# Zone 3x3, transforme les cases touchées en Forêt pendant 2 tours
		# Synergie forte avec le passif de l'Archer
		SortScript.creer(
			"archer_pluie",
			"Pluie de Flèches",
			30,    # 30 dégâts sur toutes les unités dans la zone
			5,     # Portée 5
			4,     # CD 4 tours
			3,     # Coût 3 Gold
			2,     # 2 PM — déjà coûteux en gold
			false, # Pas de ligne de vue
			"30 dmg zone 3x3 — cases → Forêt 2 tours (3 Gold)"
		),
	]
