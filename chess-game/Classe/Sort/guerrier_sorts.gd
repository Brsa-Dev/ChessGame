# -----------------------------------------------
# SORTS DU GUERRIER
# Chargés et gérés par guerrier.gd
# -----------------------------------------------
extends "res://joueur.gd"

static func creer_sorts() -> Array:
	const SortScript = preload("res://sort.gd")
	return [
		# Sort 1 — Mur (touche A)
		# Utilitaire — 2 PM (pose un obstacle, pas de dégâts)
		SortScript.creer(
			"guerrier_mur",
			"Mur",
			0,     # Pas de dégâts
			3,     # Portée 3
			2,     # CD 2 tours
			0,     # Pas de coût gold
			2,     # ← Coût 2 PM
			false, # Pas de ligne de vue
			"Crée une case Mur (dure 2 tours)"
		),
		# Sort 2 — Hache Empoisonnée (touche Z)
		# Dégâts + DoT — 2 PM
		SortScript.creer(
			"guerrier_hache",
			"Hache Empoisonnée",
			5,     # 5 dégâts immédiats
			3,     # Portée 3
			2,     # CD 2 tours
			0,     # Pas de coût gold
			2,     # ← Coût 2 PM
			true,  # Ligne de vue requise
			"5 dégâts + 5/tour pendant 3 tours"
		),
		# Sort 3 — Coup de Bouclier (touche E)
		# Gros dégâts + repousse — 2 PM
		SortScript.creer(
			"guerrier_bouclier",
			"Coup de Bouclier",
			30,    # 30 dégâts
			1,     # Corps à corps
			3,     # CD 3 tours
			0,     # Pas de coût gold
			2,     # ← Coût 2 PM
			false,
			"30 dégâts + repousse de 2 cases"
		),
		# Sort 4 — Rage Berserker (touche R)
		# Buff très puissant (+2 PM rendu) — coûte 3 PM à l'activation
		SortScript.creer(
			"guerrier_rage",
			"Rage Berserker",
			0,     # Pas de dégâts directs
			0,     # Sur soi-même
			4,     # CD 4 tours
			0,     # Pas de coût gold
			3,     # ← Coût 3 PM (rend +2 PM via activer_rage())
			false,
			"x2 attaque, +2 PM, immunité (2 tours)"
		),
	]
