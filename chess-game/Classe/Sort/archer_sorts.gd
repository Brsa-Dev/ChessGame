# =======================================================
# Classe/Sort/archer_sorts.gd
# -------------------------------------------------------
# Sorts de l'Archer — chargés dans archer.gd via _ready()
#
# Synergies passif :
#   - archer_fleche utilise attaque_portee (pas sort.portee)
#     pour bénéficier du bonus Forêt (+1 portée via entrer_foret)
#   - archer_tir_cible inflige des dégâts bonus si la cible
#     est sur une case Forêt (géré dans sort_handler)
# =======================================================
extends "res://joueur.gd"

static func creer_sorts() -> Array:
	const SortScript = preload("res://sort.gd")
	return [
		# Sort 1 — Flèche Rebondissante (touche A)
		# Portée lue depuis joueur.attaque_portee (pas sort.portee)
		# pour bénéficier du passif Forêt de l'Archer.
		# Rebond : cherche la cible la plus proche dans un rayon
		# de 2 cases autour de la cible initiale, ligne de vue requise
		# pour le rebond uniquement (pas pour le tir principal).
		SortScript.creer(
			"archer_fleche",
			"Flèche Rebondissante",
			20,    # 20 dégâts de base (30 en forêt via passif +10 attaque)
			3,     # Portée 3 de base (4 en forêt via attaque_portee +1)
			2,     # CD 2 tours
			0,     # Pas de coût gold
			3,     # 3 PM
			false, # Pas de ligne de vue pour le tir initial
			"20 dmg (30 forêt) + rebond rayon 2 cases (10 dmg) si ligne de vue"
		),
		# Sort 2 — Piège (touche Z)
		# Pose un piège invisible sur une case vide.
		# Déclenché quand un ennemi marche dessus.
		# La durée d'immobilisation passe à 2 tours avec le Piège Amélioré.
		SortScript.creer(
			"archer_piege",
			"Piège",
			10,    # 10 dégâts au déclenchement
			2,     # Portée 2
			3,     # CD 3 tours
			0,     # Pas de coût gold
			1,     # 1 PM
			false, # Pas de ligne de vue
			"Pose un piège invisible (10 dmg + immobilise 1 tour si déclenché)"
		),
		# Sort 3 — Tir Ciblé (touche E)
		# Ligne de vue requise. Dégâts doublés si la cible est en Forêt,
		# mais coûte 5 Gold dans ce cas (géré dans sort_handler).
		SortScript.creer(
			"archer_tir_cible",
			"Tir Ciblé",
			40,    # 40 dégâts de base (60 si cible sur forêt)
			5,     # Portée 5
			3,     # CD 3 tours
			0,     # Coût gold variable : 0 ou 5 selon la case cible
			3,     # 3 PM
			true,  # Ligne de vue requise
			"40 dmg (60 sur forêt, coûte 5 Gold)"
		),
		# Sort 4 — Pluie de Flèches (touche R)
		# Zone 3x3 autour de la case ciblée.
		# Inflige des dégâts à toutes les unités dans la zone
		# et transforme les cases touchées en Forêt pendant 2 tours.
		# Forte synergie avec le passif Forêt de l'Archer.
		SortScript.creer(
			"archer_pluie_fleches",
			"Pluie de Flèches",
			30,    # 30 dégâts sur toutes les unités dans la zone
			5,     # Portée 5
			4,     # CD 4 tours
			3,     # Coût 3 Gold
			2,     # 2 PM
			false, # Pas de ligne de vue
			"30 dmg zone 3x3 — cases → Forêt 2 tours (3 Gold)"
		),
	]
