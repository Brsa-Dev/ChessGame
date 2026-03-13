# =======================================================
# Manager/shop_manager.gd
# -------------------------------------------------------
# Logique de la boutique — NE gère PAS l'affichage.
#
#   - Charge le stock d'items à chaque ouverture
#   - Valide les achats (gold, limites)
#   - Applique les effets des items sur les joueurs
#   - Filtre le stock par classe du joueur
#
# L'affichage est géré par shop_ui.gd.
# Les items sont définis dans item.gd.
# =======================================================
extends Node


# =======================================================
# RESSOURCES
# =======================================================

const ItemScript = preload("res://item.gd")


# =======================================================
# ÉTAT
# =======================================================

# Items communs actuellement disponibles en boutique
# Rechargé à chaque appel de ouvrir_boutique()
var stock : Array = []


# =======================================================
# LIFECYCLE
# =======================================================

# -------------------------------------------------------
# Recharge le stock commun au début de chaque phase boutique.
# Les items de classe sont ajoutés dynamiquement dans get_stock_pour_joueur().
# -------------------------------------------------------
func ouvrir_boutique() -> void:
	stock = ItemScript.get_items_communs()
	print("=== Boutique ouverte ! %d items communs ===" % stock.size())


# =======================================================
# ACHAT
# =======================================================

# -------------------------------------------------------
# Retourne true si le joueur peut acheter l'item.
# Vérifie le gold et la limite d'achat par partie.
# -------------------------------------------------------
func peut_acheter(joueur: Node, item: Resource) -> bool:
	if joueur.gold < item.prix:
		print("Pas assez de Gold ! (%d/%d)" % [joueur.gold, item.prix])
		return false

	# Limite d'achat — -1 = illimité
	if item.limite_achat != -1:
		var nb_achats : int = joueur.achats_par_item.get(item.id, 0)
		if nb_achats >= item.limite_achat:
			print("Limite d'achat atteinte pour : %s" % item.nom)
			return false

	return true


# -------------------------------------------------------
# Effectue l'achat : déduit le gold, enregistre le suivi,
# ajoute l'item à l'inventaire et applique son effet.
# -------------------------------------------------------
func acheter(joueur: Node, item: Resource) -> void:
	if not peut_acheter(joueur, item):
		return

	joueur.gold -= item.prix

	# Suivi du nombre d'achats par item (pour les limites)
	var nb_achats : int = joueur.achats_par_item.get(item.id, 0)
	joueur.achats_par_item[item.id] = nb_achats + 1

	# L'item est ajouté à l'inventaire avant l'effet
	# pour que inventory_ui.gd puisse l'afficher immédiatement
	joueur.inventaire.append(item)

	print("%s achète : %s — Gold restant : %d" % [joueur.name, item.nom, joueur.gold])
	appliquer_effet(joueur, item)


# =======================================================
# EFFETS DES ITEMS
# -------------------------------------------------------
# Appliqués immédiatement à l'achat pour les PERMANENT.
# Les UNIQUE utilisables manuellement (Bombe, Bandage, Flèches)
# sont gérés depuis inventory_ui → input_handler.
# =======================================================
func appliquer_effet(joueur: Node, item: Resource) -> void:
	match item.id:

		# ---------------------------------------------------
		# ITEMS COMMUNS
		# ---------------------------------------------------

		"potion_soin":
			joueur.hp_actuels = min(joueur.hp_actuels + 30, joueur.hp_max)
			print("💊 Potion de Soin — HP : %d/%d" % [joueur.hp_actuels, joueur.hp_max])

		"bottes_vitesse":
			joueur.pm_max    += 1
			joueur.pm_actuels += 1  # Effet immédiat dans le tour en cours
			print("👢 Bottes de Vitesse — PM max : %d" % joueur.pm_max)

		"amulette_resistance":
			joueur.resistance_degats += 0.10
			print("🔮 Amulette — Résistance : %.0f%%" % (joueur.resistance_degats * 100))

		"bombe":
			# Pas d'effet à l'achat — utilisée manuellement depuis l'inventaire
			print("💣 Bombe ajoutée à l'inventaire")

		"elixir_gold":
			joueur.gold += 8
			print("✨ Élixir de Gold — Gold : %d" % joueur.gold)

		# ---------------------------------------------------
		# ITEMS GUERRIER
		# ---------------------------------------------------

		"epee_renforcee":
			joueur.attaque_degats += 10
			print("⚔️ Épée Renforcée — attaque : %d" % joueur.attaque_degats)

		"armure_lourde":
			joueur.resistance_degats += 0.20
			print("🛡️ Armure Lourde — résistance : %.0f%%" % (joueur.resistance_degats * 100))

		"pierre_rage":
			# Réduit le CD actuel de Rage Berserker de 1 (effet immédiat)
			for sort in joueur.sorts:
				if sort.id == "guerrier_rage":
					sort.cooldown_actuel = max(0, sort.cooldown_actuel - 1)
					print("⚔️ Pierre de Rage — CD Rage : %d" % sort.cooldown_actuel)
					break

		"bandage":
			# Pas d'effet à l'achat — utilisé manuellement depuis l'inventaire
			print("🩹 Bandage ajouté à l'inventaire")

		# ---------------------------------------------------
		# ITEMS MAGE
		# ---------------------------------------------------

		"baton_arcanique":
			joueur.bonus_degats_sorts += 10
			print("🔮 Bâton Arcanique — bonus sorts : +%d" % joueur.bonus_degats_sorts)

		"tome_glace":
			for sort in joueur.sorts:
				if sort.id == "mage_gel":
					sort.cooldown_actuel = max(0, sort.cooldown_actuel - 1)
					print("❄️ Tome de Glace — CD Gel : %d" % sort.cooldown_actuel)
					break

		"cristal_mana":
			# Réduit le coût gold de Tempête Arcanique (géré dans sort_handler)
			joueur.reduction_cout_tempete += 2
			print("💎 Cristal de Mana — Tempête coûte -%d Gold" % joueur.reduction_cout_tempete)

		"robe_enchantee":
			joueur.hp_max     += 20
			joueur.hp_actuels += 20
			print("👘 Robe Enchantée — HP max : %d" % joueur.hp_max)

		# ---------------------------------------------------
		# ITEMS ARCHER
		# ---------------------------------------------------

		"arc_long":
			joueur.attaque_portee    += 1
			joueur.bonus_range_sorts += 1
			print("🏹 Arc Long — portée : %d" % joueur.attaque_portee)

		"fleches_empoisonnees":
			# Pas d'effet à l'achat — activées manuellement depuis l'inventaire
			print("🏹 Flèches Empoisonnées ajoutées à l'inventaire")

		"piege_ameliore":
			joueur.piege_ameliore_actif = true
			print("🪤 Piège Amélioré — immobilisation 2 tours")

		"cape_foret":
			# 2 charges utilisables manuellement depuis l'inventaire
			joueur.cape_foret_charges = 2
			print("🌲 Cape de Forêt — 2 charges disponibles")

		# ---------------------------------------------------
		# ITEMS FRIPON
		# ---------------------------------------------------

		"dague_aceree":
			joueur.attaque_degats += 5
			print("🗡️ Dague Acérée — attaque : %d" % joueur.attaque_degats)

		"ceinture_pickpocket":
			joueur.pickpocket_actif = true
			print("👜 Ceinture de Pickpocket activée")

		"bottes_silencieuses":
			joueur.pm_max     += 2
			joueur.pm_actuels += 2
			print("👢 Bottes Silencieuses — PM max : %d" % joueur.pm_max)

		"potion_frenesie":
			# Réduit le coût gold de Frénésie (géré dans sort_handler)
			joueur.reduction_cout_frenesie += 1
			print("🍶 Potion de Frénésie — Frénésie coûte -%d Gold" % joueur.reduction_cout_frenesie)


# =======================================================
# STOCK FILTRÉ
# =======================================================

# -------------------------------------------------------
# Retourne les items visibles pour un joueur donné :
# items communs + items de sa classe uniquement.
# Appelée par shop_ui.gd pour construire les boutons.
# -------------------------------------------------------
func get_stock_pour_joueur(joueur: Node) -> Array:
	var classe       : String = _get_classe(joueur)
	var items_classe : Array  = ItemScript.get_items_classe(classe)
	return stock + items_classe


# -------------------------------------------------------
# Détermine la classe d'un joueur en lisant le resource_path
# de son script — même logique que hud_ui._get_nom_classe()
# -------------------------------------------------------
func _get_classe(joueur: Node) -> String:
	var path : String = joueur.get_script().resource_path
	if "fripon"   in path: return "fripon"
	if "mage"     in path: return "mage"
	if "guerrier" in path: return "guerrier"
	if "archer"   in path: return "archer"
	return ""
