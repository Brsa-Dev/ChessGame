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
	# Le stock est rechargé à chaque ouverture
	# Les items de classe sont chargés dynamiquement dans shop_ui.gd
	# selon la classe du joueur actif
	stock = ItemScript.get_items_communs()
	print("=== Boutique ouverte ! ", stock.size(), " items communs ===")

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

		# -----------------------------------------------
		# ITEMS GUERRIER
		# -----------------------------------------------
		"epee_renforcee":
			joueur.attaque_degats += 10
			print("⚔️ Épée Renforcée — attaque : ", joueur.attaque_degats)

		"armure_lourde":
			# Même système que l'Amulette — cumulable
			joueur.resistance_degats += 0.20
			print("🛡️ Armure Lourde — résistance : ", joueur.resistance_degats * 100, "%")

		"pierre_rage":
			# Réduit le CD actuel de Rage Berserker de 1
			# Si CD = 0, aucun effet (sort déjà disponible)
			for sort in joueur.sorts:
				if sort.id == "guerrier_rage":
					sort.cooldown_actuel = max(0, sort.cooldown_actuel - 1)
					print("⚔️ Pierre de Rage — CD Rage : ", sort.cooldown_actuel)
					break

		"bandage":
				print("🩹 Bandage ajouté à l'inventaire — à utiliser manuellement")

		# -----------------------------------------------
		# ITEMS MAGE
		# -----------------------------------------------
		"baton_arcanique":
			joueur.bonus_degats_sorts += 10
			print("🔮 Bâton Arcanique — bonus sorts : +", joueur.bonus_degats_sorts)

		"tome_glace":
			for sort in joueur.sorts:
				if sort.id == "mage_gel":
					sort.cooldown_actuel = max(0, sort.cooldown_actuel - 1)
					print("❄️ Tome de Glace — CD Gel : ", sort.cooldown_actuel)
					break

		"cristal_mana":
			# Réduction permanente du coût Gold de Tempête Arcanique
			joueur.reduction_cout_tempete += 2
			print("💎 Cristal de Mana — Tempête coûte ", 2 - joueur.reduction_cout_tempete, " Gold de moins")

		"robe_enchantee":
			joueur.hp_max     += 20
			joueur.hp_actuels += 20  # Effet immédiat aussi
			print("👘 Robe Enchantée — HP max : ", joueur.hp_max)

		# -----------------------------------------------
		# ITEMS ARCHER
		# -----------------------------------------------
		"arc_long":
			joueur.attaque_portee  += 1
			joueur.bonus_range_sorts += 1
			print("🏹 Arc Long — portée : ", joueur.attaque_portee)

		"fleches_empoisonnees":
			# Ajoutées à l'inventaire — activables manuellement via touche F
			print("🏹 Flèches Empoisonnées ajoutées à l'inventaire")

		"piege_ameliore":
			joueur.piege_ameliore_actif = true
			print("🪤 Piège Amélioré — immobilisation 2 tours")

		"cape_foret":
			joueur.cape_foret_charges = 2   # ← initialise les 2 charges à l'achat
			print("🌲 Cape de Forêt — 2 charges disponibles")
			# NE PAS incrémenter cape_foret_charges ici

		# -----------------------------------------------
		# ITEMS FRIPON
		# -----------------------------------------------
		"dague_aceree":
			joueur.attaque_degats += 5
			print("🗡️ Dague Acérée — attaque : ", joueur.attaque_degats)

		"ceinture_pickpocket":
			joueur.pickpocket_actif = true
			print("👜 Ceinture de Pickpocket activée")

		"bottes_silencieuses":
			joueur.pm_max     += 2
			joueur.pm_actuels += 2
			print("👢 Bottes Silencieuses — PM max : ", joueur.pm_max)

		"potion_frenesie":
			joueur.reduction_cout_frenesie += 1
			print("🍶 Potion de Frénésie — Frénésie coûte 1 Gold de moins")

# -----------------------------------------------
# get_stock_pour_joueur — Retourne les items
# visibles pour un joueur donné :
# items communs + items de sa classe
# -----------------------------------------------
func get_stock_pour_joueur(joueur: Node) -> Array:
	var classe = _get_classe(joueur)
	var items_classe = ItemScript.get_items_classe(classe)
	return stock + items_classe

# -----------------------------------------------
# _get_classe — Lit le script du joueur pour
# déterminer sa classe (même logique que hud_ui.gd)
# -----------------------------------------------
func _get_classe(joueur: Node) -> String:
	var path = joueur.get_script().resource_path
	if "fripon"   in path: return "fripon"
	if "mage"     in path: return "mage"
	if "guerrier" in path: return "guerrier"
	if "archer"   in path: return "archer"
	return ""
