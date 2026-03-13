# -----------------------------------------------
# SORTS DU FRIPON
# Chargés et gérés par fripon.gd
# -----------------------------------------------
extends "res://joueur.gd"

static func creer_sorts() -> Array:
	const SortScript = preload("res://sort.gd")
	return [
		# Sort 1 — Ruée (touche A)
		# CD = 0 — la disponibilité est gérée via ruee_disponible dans fripon.gd
		# (relançable après 3 attaques de base depuis la dernière utilisation)
		SortScript.creer(
			"fripon_ruee",
			"Ruée",
			5,     # 5 dégâts
			4,     # Portée 4
			0,     # CD 0 — géré manuellement
			1,     # 1 Gold
			1,     # 1 PM
			false,
			"5 dmg + repositionnement (relançable après 3 attaques)"
		),
		# Sort 2 — Dérobade (touche Z)
		# 0 dégâts immédiats — marque la cible
		# Explose au DÉBUT du prochain tour du Fripon pour 10 dmg
		# L'explosion synergise avec Lame Empoisonnée et compteur Ruée
		# mais NE consomme PAS a_attaque_ce_tour
		SortScript.creer(
			"fripon_derobade",
			"Dérobade",
			0,
			3,     # Portée 3
			2,     # CD 2 tours
			0,
			2,     # 2 PM
			true,  # Ligne de vue requise
			"Marque un ennemi — explose au prochain tour (10 dmg)"
		),
		# Sort 3 — Lame Empoisonnée (touche E)
		# Active lame_active sur le Fripon
		# La prochaine attaque de base (y compris la 2ème via passif) applique le DoT
		SortScript.creer(
	"fripon_lame",
	"Lame Empoisonnée",
	0,     # 0 dégâts immédiats — c'est un état, pas une attaque
	0,     # Range 0 — sur soi-même
	2,
	0,
	1,
	false,
    "Active état : prochaine attaque → +10 dmg + DoT (5/tour 3 tours)"
),
		# Sort 4 — Frénésie (touche R)
		# Active frenesie_active — dure jusqu'à la fin du tour
		# Attaques illimitées à 0 PM (a_attaque_ce_tour ignoré)
		SortScript.creer(
			"fripon_frenesie",
			"Frénésie",
			0,
			0,     # Sur soi-même
			4,     # CD 4 tours
			3,     # 3 Gold
			2,     # 2 PM
			false,
			"Attaques illimitées à 0 PM pendant 1 tour (3 Gold)"
		),
	]
