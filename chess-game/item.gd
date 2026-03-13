# item.gd
extends Resource

enum Usage { UNIQUE, PERMANENT }

var id: String
var nom: String
var prix: int
var usage: Usage
var description: String
var limite_achat: int = -1  # -1 = pas de limite

# Classe requise pour acheter cet item
# "" = commun (achetable par tous)
# "guerrier", "mage", "archer", "fripon"
var classe_requise: String = ""

static func creer(p_id, p_nom, p_prix, p_usage, p_description, p_limite = -1, p_classe = "") -> Resource:
	var item = new()
	item.id            = p_id
	item.nom           = p_nom
	item.prix          = p_prix
	item.usage         = p_usage
	item.description   = p_description
	item.limite_achat  = p_limite
	item.classe_requise = p_classe 
	return item

static func get_items_communs() -> Array:
	return [
		creer("potion_soin",        "Potion de Soin",        3, Usage.UNIQUE,    "Restaure 30 HP",1),
		creer("bottes_vitesse",     "Bottes de Vitesse",     4, Usage.PERMANENT, "+1 PM permanent",1),
		creer("amulette_resistance","Amulette de Résistance",5, Usage.PERMANENT, "-10% dégâts reçus",1),
		creer("bombe",              "Bombe",                 3, Usage.UNIQUE,    "20 dégâts en zone",1),
		creer("elixir_gold",        "Élixir de Gold",        2, Usage.UNIQUE,    "+8 Gold immédiat", 1),
	]

# -----------------------------------------------
# get_items_classe — Retourne les items spécifiques
# à une classe donnée.
# Appelée par shop_ui.gd pour filtrer l'affichage.
# -----------------------------------------------
static func get_items_classe(classe: String) -> Array:
	match classe:
		"guerrier": return _items_guerrier()
		"mage":     return _items_mage()
		"archer":   return _items_archer()
		"fripon":   return _items_fripon()
	return []

static func _items_guerrier() -> Array:
	return [
		creer("epee_renforcee",  "Épée Renforcée",    4, Usage.PERMANENT, "+10 attaque de base",               1, "guerrier"),
		creer("armure_lourde",   "Armure Lourde",      6, Usage.PERMANENT, "-20% dégâts reçus",                 1, "guerrier"),
		creer("pierre_rage",     "Pierre de Rage",     5, Usage.UNIQUE,    "Réduit le CD de Rage Berserker -1", 1, "guerrier"),
		creer("bandage",         "Bandage",            3, Usage.UNIQUE,    "Réduit les DoT reçus de 1 tour",    1, "guerrier"),
	]

static func _items_mage() -> Array:
	return [
		creer("baton_arcanique", "Bâton Arcanique",    5, Usage.PERMANENT, "+10 dégâts sur tous les sorts",     1, "mage"),
		creer("tome_glace",      "Tome de Glace",      4, Usage.UNIQUE,    "Réduit le CD de Gel de 1",          1, "mage"),
		creer("cristal_mana",    "Cristal de Mana",    5, Usage.PERMANENT, "Tempête Arcanique coûte -2 Gold",   1, "mage"),
		creer("robe_enchantee",  "Robe Enchantée",     4, Usage.PERMANENT, "+20 HP maximum",                    1, "mage"),
	]

static func _items_archer() -> Array:
	return [
		creer("arc_long",           "Arc Long",             5, Usage.PERMANENT, "+1 portée attaques et sorts",          1, "archer"),
		creer("fleches_empoisonnees","Flèches Empoisonnées", 4, Usage.PERMANENT, "Prochaine attaque → DoT 5/tour 3 tours",1, "archer"),
		creer("piege_ameliore",     "Piège Amélioré",       3, Usage.PERMANENT, "Piège immobilise 2 tours au lieu de 1", 1, "archer"),
		creer("cape_foret",         "Cape de Forêt",        5, Usage.PERMANENT, "Crée une case Forêt (2 charges)",      1, "archer"),
	]

static func _items_fripon() -> Array:
	return [
		creer("dague_aceree",      "Dague Acérée",          4, Usage.PERMANENT, "+5 attaque de base",                   1, "fripon"),
		creer("ceinture_pickpocket","Ceinture de Pickpocket",4, Usage.PERMANENT, "Vole 1 Gold par attaque de base",      1, "fripon"),
		creer("bottes_silencieuses","Bottes Silencieuses",   6, Usage.PERMANENT, "+2 PM pour toute la partie",           1, "fripon"),
		creer("potion_frenesie",   "Potion de Frénésie",    4, Usage.PERMANENT, "Frénésie coûte -1 Gold",               1, "fripon"),
	]
