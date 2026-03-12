# shop_manager.gd
# -----------------------------------------------
# SHOP MANAGER — Logique de la boutique
# S'occupe du stock, des achats et des effets
# Ne gère PAS l'affichage (c'est shop_ui.gd)
# -----------------------------------------------
extends Node

# Référence au script item.gd pour créer le catalogue
const ItemScript = preload("res://item.gd")

# Stock actuel de la boutique (tableau d'items)
var stock: Array = []

# -----------------------------------------------
# Appelée par tour_manager.gd en début de phase boutique
# Recharge le stock avec les 5 items communs
# -----------------------------------------------
func ouvrir_boutique():
	stock = ItemScript.get_items_communs()
	print("=== Boutique ouverte ! ", stock.size(), " items disponibles ===")

# -----------------------------------------------
# Vérifie si un joueur peut acheter un item
# Retourne true si l'achat est possible
# -----------------------------------------------
func peut_acheter(joueur: Node, item: Resource) -> bool:
	# Vérification 1 — le joueur a assez de gold
	if joueur.gold < item.prix:
		print("Pas assez de Gold ! (", joueur.gold, "/", item.prix, ")")
		return false
	
	# Vérification 2 — limite d'achat par partie (ex: Élixir de Gold)
	if item.limite_achat != -1:
		# On récupère le nombre d'achats déjà effectués pour cet item
		var nb_achats = joueur.achats_par_item.get(item.id, 0)
		if nb_achats >= item.limite_achat:
			print("Limite d'achat atteinte pour : ", item.nom)
			return false
	
	return true

# -----------------------------------------------
# Effectue l'achat : déduit le gold, enregistre
# l'achat, et applique l'effet de l'item
# -----------------------------------------------
func acheter(joueur: Node, item: Resource):
	if not peut_acheter(joueur, item):
		return
	
	# On déduit le prix
	joueur.gold -= item.prix
	
	# On enregistre l'achat dans le suivi du joueur
	# (indispensable pour la limite de l'Élixir de Gold)
	var nb_achats = joueur.achats_par_item.get(item.id, 0)
	joueur.achats_par_item[item.id] = nb_achats + 1
	
	# Pour les items permanents, on les ajoute à l'inventaire
	# Pour les items à usage unique, on les ajoute aussi
	# (ils seront consommés à l'utilisation)
	joueur.inventaire.append(item)
	
	print(joueur.name, " a acheté : ", item.nom, " — Gold restant : ", joueur.gold)
	
	# On applique l'effet immédiatement si c'est UNIQUE
	# (Potion, Élixir, Bombe sont appliqués à l'achat pour simplifier)
	# Les PERMANENT sont appliqués à l'achat aussi (effet immédiat)
	appliquer_effet(joueur, item)

# -----------------------------------------------
# Applique l'effet d'un item sur un joueur
# C'est ici qu'on branche chaque item à sa logique
# -----------------------------------------------
func appliquer_effet(joueur: Node, item: Resource):
	match item.id:
		
		"potion_soin":
			# Restaure 30 HP sans dépasser le maximum
			joueur.hp_actuels = min(joueur.hp_actuels + 30, joueur.hp_max)
			print("Potion de Soin — HP : ", joueur.hp_actuels, "/", joueur.hp_max)
		
		"bottes_vitesse":
			# +1 PM maximum pour toute la partie
			joueur.pm_max += 1
			joueur.pm_actuels += 1  # Prend effet immédiatement
			print("Bottes de Vitesse — PM max : ", joueur.pm_max)
		
		"amulette_resistance":
			# -10% dégâts reçus — on stocke le flag sur le joueur
			# La réduction sera appliquée dans joueur.recevoir_degats()
			joueur.resistance_degats += 0.10
			print("Amulette de Résistance — Réduction : ", joueur.resistance_degats * 100, "%")
		
		"bombe":
			# La bombe n'est PAS appliquée à l'achat
			# Elle sera utilisée manuellement depuis l'inventaire
			# On ne fait rien ici — elle reste dans l'inventaire
			print("Bombe ajoutée à l'inventaire — à utiliser manuellement")
		
		"elixir_gold":
			# +8 Gold immédiat
			joueur.gold += 8
			print("Élixir de Gold — Gold : ", joueur.gold)
