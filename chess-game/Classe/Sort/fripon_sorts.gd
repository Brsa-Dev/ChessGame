# =======================================================
# Classe/Sort/fripon_sorts.gd
# -------------------------------------------------------
# Sorts du Fripon — chargés dans fripon.gd via _ready()
#
# Thème : mobilité + combo + or
#   - Ruée — repositionnement + dégâts (rechargeable via attaques)
#   - Dérobade — marque différée explosant au prochain tour
#   - Lame Empoisonnée — état : prochaine attaque +10 dmg + DoT
#   - Frénésie — attaques illimitées à 0 PM pendant 1 tour
# =======================================================
extends Object

static func creer_sorts() -> Array[Sort]:
	const SortScript = preload("res://sort.gd")
	return [
		# Sort 1 — Ruée (touche A)
		# CD géré manuellement via ruee_disponible (pas le CD standard).
		# Se déverrouille après RUEE_ATTAQUES_REQUISES attaques de base.
		# Peut cibler une case vide (téléportation) ou un ennemi (+ dégâts).
		SortScript.creer(
			"fripon_ruee",
			"Ruée",
			5,     # 5 dégâts si ennemi ciblé
			4,     # Portée 4
			0,     # CD 0 — géré via fripon.ruee_disponible
			1,     # 1 Gold
			1,     # 1 PM
			false,
			"5 dmg + repositionnement (relançable après 3 attaques)"
		),
		# Sort 2 — Dérobade (touche Z)
		# Pose une marque sur l'ennemi ciblé.
		# La marque explose au DÉBUT du prochain tour du Fripon (20 dmg).
		# Synergie Lame : si lame_active, +10 dmg + DoT au moment de l'explosion.
		# L'explosion ne consomme pas a_attaque_ce_tour.
		SortScript.creer(
			"fripon_derobade",
			"Dérobade",
			0,     # 0 dégâts immédiats — tout est dans l'explosion différée
			3,     # Portée 3
			2,     # CD 2 tours
			0,
			2,     # 2 PM
			true,  # Ligne de vue requise
			"Marque un ennemi — explose au prochain tour (20 dmg)"
		),
		# Sort 3 — Lame Empoisonnée (touche E)
		# Active lame_active sur le Fripon — aucune cible externe.
		# La prochaine attaque de base (y compris via passif déplacement)
		# inflige +10 dmg + DoT 5/tour pendant 3 tours.
		# lame_active est consommé dans fripon.attaquer() après utilisation.
		SortScript.creer(
			"fripon_lame",
			"Lame Empoisonnée",
			0,     # 0 dégâts immédiats — état activé sur soi-même
			0,     # Portée 0 — auto-ciblage
			2,     # CD 2 tours
			0,
			1,     # 1 PM
			false,
			"Active état : prochaine attaque → +10 dmg + DoT (5/tour 3 tours)"
		),
		# Sort 4 — Frénésie (touche R)
		# Toutes les attaques de base ce tour coûtent 0 PM.
		# a_attaque_ce_tour est QUAND MÊME respecté (pas d'attaques infinies).
		# Coût réduit par la Potion de Frénésie (item de classe).
		SortScript.creer(
			"fripon_frenesie",
			"Frénésie",
			0,     # Pas de dégâts directs
			0,     # Sur soi-même
			4,     # CD 4 tours
			3,     # 3 Gold (réduit par potion_frenesie)
			2,     # 2 PM
			false,
			"Attaques à 0 PM pendant 1 tour (3 Gold)"
		),
	]
