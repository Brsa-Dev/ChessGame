# =======================================================
# Classe/Sort/mage_sorts.gd
# -------------------------------------------------------
# Sorts du Mage — chargés dans mage.gd via _ready()
#
# Thème : contrôle + dégâts de zone + terrain
#   - Boule de Feu — dégâts directs rapides (CD 1)
#   - Gel — immobilisation 2 tours (contrôle)
#   - Météore — zone 3×3 + lave temporaire (effet différé 2 tours)
#   - Tempête Arcanique — dégâts sur TOUS les ennemis (5 Gold)
# =======================================================
extends Object

static func creer_sorts() -> Array[Sort]:
	const SortScript = preload("res://sort.gd")
	return [
		# Sort 1 — Boule de Feu (touche A)
		# Dégâts directs, CD court (1 tour).
		# Pas de ligne de vue — tir lobé.
		SortScript.creer(
			"mage_boule_feu",
			"Boule de Feu",
			20,    # 20 dégâts (+ bonus_degats_sorts)
			3,     # Portée 3
			1,     # CD 1 tour — sort de harcèlement
			0,
			1,     # 1 PM — peu coûteux
			false, # Pas de ligne de vue
			"20 dégâts (portée 3)"
		),
		# Sort 2 — Gel (touche Z)
		# Immobilise la cible 2 tours — aucun dégât.
		# Puissant pour bloquer avant un Météore ou une Tempête.
		SortScript.creer(
			"mage_gel",
			"Gel",
			0,     # Pas de dégâts
			4,     # Portée 4
			3,     # CD 3 tours
			0,
			2,     # 2 PM
			false,
			"Immobilise un ennemi 2 tours"
		),
		# Sort 3 — Météore (touche E)
		# Tombe dans 2 tours du lanceur — prévient l'ennemi visuellement.
		# Zone 3×3 → dégâts + cases transformées en Lave temporaire.
		# Les cases Lave disparaissent après DUREE_LAVE_METEORE tours.
		SortScript.creer(
			"mage_meteore",
			"Météore",
			25,    # 25 dégâts zone (+ bonus_degats_sorts)
			5,     # Portée 5
			2,     # CD 2 tours
			0,
			3,     # 3 PM — impact terrain majeur
			false,
			"25 dégâts zone 3×3 — tombe dans 2 tours"
		),
		# Sort 4 — Tempête Arcanique (touche R)
		# Cible automatiquement TOUS les ennemis vivants.
		# Réduit leur portée d'attaque de 2 en plus des dégâts.
		# Coût réduit par le Cristal de Mana (item de classe).
		SortScript.creer(
			"mage_tempete",
			"Tempête Arcanique",
			20,    # 20 dégâts par ennemi (+ bonus_degats_sorts)
			0,     # Portée illimitée — ciblage automatique
			4,     # CD 4 tours
			5,     # 5 Gold (réduit par cristal_mana)
			3,     # 3 PM
			true,  # Ligne de vue requise pour chaque ennemi
			"20 dégâts sur tous les ennemis + -2 portée (5 Gold)"
		),
	]
