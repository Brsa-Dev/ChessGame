# =======================================================
# item.gd
# -------------------------------------------------------
# Ressource de base pour tous les items de la boutique.
#
#   - Définit les champs d'un item (id, prix, classe, effet)
#   - Catalogue statique des items communs + items de classe
#   - Créé via la fonction statique creer()
#
# Les effets des items sont appliqués dans shop_manager.appliquer_effet().
# =======================================================
class_name Item
extends Resource


# =======================================================
# TYPES
# =======================================================

# UNIQUE   → consommé à l'utilisation (Potion, Bombe, Bandage)
# PERMANENT → effet passif permanent (Bottes, Amulette, etc.)
enum Usage { UNIQUE, PERMANENT }


# =======================================================
# CHAMPS D'UN ITEM
# =======================================================

var id            : String = ""   # Identifiant unique — matche les cases dans shop_manager
var nom           : String = ""   # Affiché dans la boutique et l'inventaire
var prix          : int    = 0    # Coût en Gold
var usage         : Usage  = Usage.UNIQUE
var description   : String = ""   # Court texte explicatif dans l'UI

# -1 = aucune limite d'achat
# > 0 = nombre maximum d'achats par joueur par partie
var limite_achat  : int    = -1

# "" = item commun, accessible à toutes les classes
# "guerrier" / "mage" / "archer" / "fripon" = item de classe
var classe_requise: String = ""


# =======================================================
# CONSTRUCTEUR STATIQUE
# =======================================================

static func creer(
	p_id      : String,
	p_nom     : String,
	p_prix    : int,
	p_usage   : Usage,
	p_desc    : String,
	p_limite  : int    = -1,
	p_classe  : String = ""
) -> Item:
	var item            := new()
	item.id              = p_id
	item.nom             = p_nom
	item.prix            = p_prix
	item.usage           = p_usage
	item.description     = p_desc
	item.limite_achat    = p_limite
	item.classe_requise  = p_classe
	return item


# =======================================================
# CATALOGUE — Items communs
# -------------------------------------------------------
# Disponibles pour TOUTES les classes à chaque tour de boutique.
# Limite 1 par joueur par partie pour éviter les stacks abusifs.
# =======================================================
static func get_items_communs() -> Array[Item]:
	return [
		creer("potion_soin",         "Potion de Soin",         3, Usage.UNIQUE,    "Restaure 30 HP",           1),
		creer("bottes_vitesse",      "Bottes de Vitesse",      4, Usage.PERMANENT, "+1 PM permanent",          1),
		creer("amulette_resistance", "Amulette de Résistance", 5, Usage.PERMANENT, "-10% dégâts reçus",        1),
		creer("bombe",               "Bombe",                  3, Usage.UNIQUE,    "20 dégâts en zone",        1),
		creer("elixir_gold",         "Élixir de Gold",         2, Usage.UNIQUE,    "+8 Gold immédiat",         1),
	]


# =======================================================
# CATALOGUE — Items de classe
# -------------------------------------------------------
# Filtrés par classe dans shop_ui.gd et shop_manager.gd.
# Chaque classe a 4 items uniques qui synergisent avec ses sorts.
# =======================================================
static func get_items_classe(classe: String) -> Array[Item]:
	match classe:
		"guerrier": return _items_guerrier()
		"mage":     return _items_mage()
		"archer":   return _items_archer()
		"fripon":   return _items_fripon()
	return []


# -------------------------------------------------------
# Guerrier — tank, dégâts élevés, Rage
# -------------------------------------------------------
static func _items_guerrier() -> Array[Item]:
	return [
		creer("epee_renforcee",  "Épée Renforcée",    4, Usage.PERMANENT, "+10 attaque de base",               1, "guerrier"),
		creer("armure_lourde",   "Armure Lourde",     6, Usage.PERMANENT, "-20% dégâts reçus",                 1, "guerrier"),
		creer("pierre_rage",     "Pierre de Rage",    5, Usage.UNIQUE,    "Réduit le CD de Rage Berserker -1", 1, "guerrier"),
		creer("bandage",         "Bandage",           3, Usage.UNIQUE,    "Réduit les DoT reçus de 1 tour",    1, "guerrier"),
	]


# -------------------------------------------------------
# Mage — contrôle, sorts puissants, Tempête
# -------------------------------------------------------
static func _items_mage() -> Array[Item]:
	return [
		creer("baton_arcanique", "Bâton Arcanique",   5, Usage.PERMANENT, "+10 dégâts sur tous les sorts",    1, "mage"),
		creer("tome_glace",      "Tome de Glace",     4, Usage.UNIQUE,    "Réduit le CD de Gel de 1",         1, "mage"),
		creer("cristal_mana",    "Cristal de Mana",   5, Usage.PERMANENT, "Tempête Arcanique coûte -2 Gold",  1, "mage"),
		creer("robe_enchantee",  "Robe Enchantée",    4, Usage.PERMANENT, "+20 HP maximum",                   1, "mage"),
	]


# -------------------------------------------------------
# Archer — mobilité, pièges, passif Forêt
# -------------------------------------------------------
static func _items_archer() -> Array[Item]:
	return [
		creer("arc_long",            "Arc Long",             5, Usage.PERMANENT, "+1 portée attaques et sorts",           1, "archer"),
		creer("fleches_empoisonnees", "Flèches Empoisonnées", 4, Usage.PERMANENT, "Prochaine attaque → DoT 5/tour 3 tours", 1, "archer"),
		creer("piege_ameliore",      "Piège Amélioré",       3, Usage.PERMANENT, "Piège immobilise 2 tours au lieu de 1",  1, "archer"),
		creer("cape_foret",          "Cape de Forêt",        5, Usage.PERMANENT, "Crée une case Forêt (2 charges)",        1, "archer"),
	]


# -------------------------------------------------------
# Fripon — or, combo, mobilité
# -------------------------------------------------------
static func _items_fripon() -> Array[Item]:
	return [
		creer("dague_aceree",       "Dague Acérée",           4, Usage.PERMANENT, "+5 attaque de base",              1, "fripon"),
		creer("ceinture_pickpocket", "Ceinture de Pickpocket", 4, Usage.PERMANENT, "Vole 1 Gold par attaque de base", 1, "fripon"),
		creer("bottes_silencieuses", "Bottes Silencieuses",    6, Usage.PERMANENT, "+2 PM pour toute la partie",      1, "fripon"),
		creer("potion_frenesie",    "Potion de Frénésie",     4, Usage.PERMANENT, "Frénésie coûte -1 Gold",          1, "fripon"),
	]
