# item.gd
extends Resource

enum Usage { UNIQUE, PERMANENT }

var id: String
var nom: String
var prix: int
var usage: Usage
var description: String
var limite_achat: int = -1  # -1 = pas de limite

static func creer(p_id, p_nom, p_prix, p_usage, p_description, p_limite = -1):
	var item = new()
	item.id = p_id
	item.nom = p_nom
	item.prix = p_prix
	item.usage = p_usage
	item.description = p_description
	item.limite_achat = p_limite
	return item

static func get_items_communs() -> Array:
	return [
		creer("potion_soin",        "Potion de Soin",        3, Usage.UNIQUE,    "Restaure 30 HP"),
		creer("bottes_vitesse",     "Bottes de Vitesse",     4, Usage.PERMANENT, "+1 PM permanent"),
		creer("amulette_resistance","Amulette de Résistance",5, Usage.PERMANENT, "-10% dégâts reçus"),
		creer("bombe",              "Bombe",                 3, Usage.UNIQUE,    "20 dégâts en zone"),
		creer("elixir_gold",        "Élixir de Gold",        2, Usage.UNIQUE,    "+8 Gold immédiat", 1),
	]
