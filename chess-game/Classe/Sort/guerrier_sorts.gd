# =======================================================
# Classe/Sort/guerrier_sorts.gd
# -------------------------------------------------------
# Sorts du Guerrier — chargés dans guerrier.gd via _ready()
#
# Thème : contrôle du terrain + tanking
#   - Mur (utilitaire) — bloque les passages
#   - Hache Empoisonnée — dégâts + DoT
#   - Coup de Bouclier — dégâts + repousse (+ impact mur)
#   - Rage Berserker — buff offensif/défensif 2 tours
# =======================================================
extends Object

static func creer_sorts() -> Array[Sort]:
	const SortScript = preload("res://sort.gd")
	return [
		# Sort 1 — Mur (touche A)
		# Crée une case MUR sur une case cible pendant 2 tours.
		# Peut bloquer des passages stratégiques ou piéger un ennemi.
		# Pas de dégâts, portée 3, coût 2 PM.
		SortScript.creer(
			"guerrier_mur",
			"Mur",
			0,     # Pas de dégâts
			3,     # Portée 3
			2,     # CD 2 tours
			0,     # Pas de coût gold
			2,     # 2 PM
			false, # Pas de ligne de vue
			"Crée une case Mur (dure 2 tours)"
		),
		# Sort 2 — Hache Empoisonnée (touche Z)
		# 5 dégâts immédiats + DoT 5/tour pendant 3 tours.
		# Ligne de vue requise (arme de lancer).
		SortScript.creer(
			"guerrier_hache",
			"Hache Empoisonnée",
			5,     # 5 dégâts immédiats
			3,     # Portée 3
			2,     # CD 2 tours
			0,
			2,     # 2 PM
			true,  # Ligne de vue requise
			"5 dégâts + 5/tour pendant 3 tours"
		),
		# Sort 3 — Coup de Bouclier (touche E)
		# 30 dégâts + repousse la cible de 2 cases.
		# Si la cible heurte un MUR : +10 dégâts d'impact.
		SortScript.creer(
			"guerrier_bouclier",
			"Coup de Bouclier",
			30,    # 30 dégâts
			1,     # Corps-à-corps uniquement
			3,     # CD 3 tours
			0,
			2,     # 2 PM
			false,
			"30 dégâts + repousse 2 cases (impact mur : +10 dmg)"
		),
		# Sort 4 — Rage Berserker (touche R)
		# Coûte 3 PM mais rend +2 PM → coût net 1 PM.
		# x2 dégâts + immunité aux dégâts pendant 2 tours.
		# Le boost d'attaque est retiré à la fin de la Rage (guerrier.gd).
		SortScript.creer(
			"guerrier_rage",
			"Rage Berserker",
			0,     # Pas de dégâts directs
			0,     # Sur soi-même
			4,     # CD 4 tours
			0,
			3,     # 3 PM (-2 PM rendus via activer_rage() → net 1 PM)
			false,
			"x2 attaque, +2 PM, immunité dégâts (2 tours)"
		),
	]
