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
		# Dévastateur en forêt grâce au passif :
		#   → attaque_portee passe de 3 à 4 via entrer_foret()
		#   → attaque_degats passe de 20 à 30 via entrer_foret()
		# La portée réelle est toujours lue depuis joueur.attaque_portee
		# dans main.gd (_utiliser_sort) et renderer.gd (_dessiner_cases_sort)
		# Rebond : cherche un ennemi dans un rayon de 2 cases autour de
		# la cible initiale, annulé si pas de ligne de vue
		SortScript.creer(
			"archer_fleche",
			"Flèche Rebondissante",
			20,    # 20 dégâts de base (30 en forêt via passif +10 attaque)
			3,     # Portée 3 de base (4 en forêt via attaque_portee +1)
			2,     # CD 2 tours  ← CORRECTION (était 1)
			0,     # Pas de coût gold
			3,     # 3 PM — coût identique à une attaque de base + rebond bonus
			false, # Pas de ligne de vue pour le TIR INITIAL
			"20 dmg (30 forêt) + rebond rayon 2 cases (10/15 dmg) si ligne de vue"
		),
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
