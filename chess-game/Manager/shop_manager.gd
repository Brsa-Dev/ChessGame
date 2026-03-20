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
# CONSTANTES — Catalogue
# =======================================================

const ItemScript = preload("res://item.gd")


# =======================================================
# CONSTANTES — Effets des items
# -------------------------------------------------------
# Valeurs appliquées dans appliquer_effet().
# Centralisées ici pour faciliter l'ajout ou le rééquilibrage
# sans chercher dans le corps des fonctions.
# =======================================================

# Communs
const BOTTES_VITESSE_BONUS_PM  : int   = 1
const AMULETTE_RESISTANCE      : float = 0.10
const ELIXIR_GOLD_GAIN         : int   = 8

# Guerrier
const EPEE_BONUS_ATTAQUE       : int   = 10
const ARMURE_RESISTANCE        : float = 0.20

# Mage
const BATON_BONUS_SORTS        : int   = 10
const CRISTAL_REDUCTION_TEMPETE: int   = 2
const ROBE_BONUS_HP            : int   = 20

# Archer
const ARC_BONUS_PORTEE         : int   = 1
const CAPE_FORET_CHARGES       : int   = 2

# Fripon
const DAGUE_BONUS_ATTAQUE      : int   = 5
const BOTTES_SILENCIEUSES_BONUS_PM : int = 2
const POTION_FRENESIE_REDUCTION    : int = 1


# =======================================================
# ÉTAT
# =======================================================

# Items communs actuellement disponibles en boutique
# Rechargé à chaque appel de ouvrir_boutique()
var stock  : Array[Item] = []

# Callback — injecté par main.gd
var on_log : Callable  # func(message, joueur)


# =======================================================
# API PUBLIQUE
# =======================================================

# -------------------------------------------------------
# Recharge le stock commun au début de chaque phase boutique.
# Les items de classe sont ajoutés dynamiquement dans get_stock_pour_joueur().
# -------------------------------------------------------
func ouvrir_boutique() -> void:
	stock = ItemScript.get_items_communs()


# -------------------------------------------------------
# Retourne true si le joueur peut acheter l'item.
# Vérifie le gold et la limite d'achat par partie.
# -------------------------------------------------------
func peut_acheter(joueur: Node, item: Item) -> bool:
	if joueur.gold < item.prix:
		return false

	# Limite d'achat — -1 = illimité
	if item.limite_achat != -1:
		var nb_achats : int = joueur.achats_par_item.get(item.id, 0)
		if nb_achats >= item.limite_achat:
			return false

	return true


# -------------------------------------------------------
# Effectue l'achat : déduit le gold, enregistre le suivi,
# ajoute l'item à l'inventaire et applique son effet.
# -------------------------------------------------------
func acheter(joueur: Node, item: Item) -> void:
	if not peut_acheter(joueur, item):
		return

	joueur.gold -= item.prix

	# Suivi du nombre d'achats par item (pour les limites)
	var nb_achats : int = joueur.achats_par_item.get(item.id, 0)
	joueur.achats_par_item[item.id] = nb_achats + 1

	# L'item est ajouté à l'inventaire avant l'effet
	# pour que inventory_ui.gd puisse l'afficher immédiatement
	joueur.inventaire.append(item)

	if on_log.is_valid():
		on_log.call("🛒 %s achète %s (-%d Gold)" % [
			joueur.name, item.nom, item.prix
		], joueur)
	appliquer_effet(joueur, item)


# -------------------------------------------------------
# Retourne les items visibles pour un joueur donné :
# items communs + items de sa classe uniquement.
# Appelée par shop_ui.gd pour construire les boutons.
# -------------------------------------------------------
func get_stock_pour_joueur(joueur: Node) -> Array[Item]:
	var items_classe : Array[Item] = ItemScript.get_items_classe(joueur.get_classe())
	return stock + items_classe


# =======================================================
# EFFETS DES ITEMS
# -------------------------------------------------------
# Appliqués immédiatement à l'achat pour les PERMANENT.
# Les UNIQUE utilisables manuellement (Bombe, Bandage, Flèches)
# sont gérés depuis inventory_ui → input_handler.
# =======================================================
func appliquer_effet(joueur: Node, item: Item) -> void:
	match item.id:

		# ---------------------------------------------------
		# ITEMS COMMUNS
		# ---------------------------------------------------

		"potion_soin":
			pass  # Pas d'effet à l'achat — utilisée manuellement depuis l'inventaire

		"bottes_vitesse":
			joueur.pm_max     += BOTTES_VITESSE_BONUS_PM
			joueur.pm_actuels += BOTTES_VITESSE_BONUS_PM  # Effet immédiat dans le tour en cours

		"amulette_resistance":
			joueur.resistance_degats += AMULETTE_RESISTANCE

		"bombe":
			pass  # Pas d'effet à l'achat — utilisée manuellement depuis l'inventaire

		"elixir_gold":
			joueur.gold += ELIXIR_GOLD_GAIN

		# ---------------------------------------------------
		# ITEMS GUERRIER
		# ---------------------------------------------------

		"epee_renforcee":
			joueur.attaque_degats += EPEE_BONUS_ATTAQUE

		"armure_lourde":
			joueur.resistance_degats += ARMURE_RESISTANCE

		"pierre_rage":
			# Réduit le CD actuel de Rage Berserker de 1 (effet immédiat)
			for sort in joueur.sorts:
				if sort.id == "guerrier_rage":
					sort.cooldown_actuel = max(0, sort.cooldown_actuel - 1)
					break

		"bandage":
			pass  # Pas d'effet à l'achat — utilisé manuellement depuis l'inventaire

		# ---------------------------------------------------
		# ITEMS MAGE
		# ---------------------------------------------------

		"baton_arcanique":
			joueur.bonus_degats_sorts += BATON_BONUS_SORTS

		"tome_glace":
			for sort in joueur.sorts:
				if sort.id == "mage_gel":
					sort.cooldown_actuel = max(0, sort.cooldown_actuel - 1)
					break

		"cristal_mana":
			# Réduit le coût gold de Tempête Arcanique (géré dans sort_handler)
			joueur.reduction_cout_tempete += CRISTAL_REDUCTION_TEMPETE

		"robe_enchantee":
			joueur.hp_max     += ROBE_BONUS_HP
			joueur.hp_actuels += ROBE_BONUS_HP

		# ---------------------------------------------------
		# ITEMS ARCHER
		# ---------------------------------------------------

		"arc_long":
			joueur.attaque_portee    += ARC_BONUS_PORTEE
			joueur.bonus_range_sorts += ARC_BONUS_PORTEE

		"fleches_empoisonnees":
			pass  # Pas d'effet à l'achat — activées manuellement depuis l'inventaire

		"piege_ameliore":
			joueur.piege_ameliore_actif = true

		"cape_foret":
			# Charges utilisables manuellement depuis l'inventaire
			joueur.cape_foret_charges = CAPE_FORET_CHARGES

		# ---------------------------------------------------
		# ITEMS FRIPON
		# ---------------------------------------------------

		"dague_aceree":
			joueur.attaque_degats += DAGUE_BONUS_ATTAQUE

		"ceinture_pickpocket":
			joueur.pickpocket_actif = true

		"bottes_silencieuses":
			joueur.pm_max     += BOTTES_SILENCIEUSES_BONUS_PM
			joueur.pm_actuels += BOTTES_SILENCIEUSES_BONUS_PM

		"potion_frenesie":
			# Réduit le coût gold de Frénésie (géré dans sort_handler)
			joueur.reduction_cout_frenesie += POTION_FRENESIE_REDUCTION
