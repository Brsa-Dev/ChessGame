# =======================================================
# sort.gd
# -------------------------------------------------------
# Ressource de base pour tous les sorts du jeu.
#
#   - Champs d'un sort (id, portée, CD, coûts, ligne de vue)
#   - État du cooldown (disponible / en recharge)
#   - Créé via la fonction statique creer() dans les fichiers
#     xxx_sorts.gd — jamais instancié directement
#
# Une instance par sort par joueur — les sorts NE sont PAS partagés
# entre joueurs pour que chaque CD soit indépendant.
# =======================================================
class_name Sort
extends Resource


# =======================================================
# IDENTITÉ DU SORT
# =======================================================

# Identifiant unique — utilisé pour le dispatch dans sort_handler
# Format : "classe_nom" (ex: "guerrier_mur", "mage_gel")
var id           : String = ""

# Nom affiché dans le HUD et le log de combat
var nom          : String = ""

# Description courte affichée dans le HUD sous le nom
var description  : String = ""


# =======================================================
# STATS DU SORT
# =======================================================

# Dégâts bruts avant le bonus du lanceur (bonus_degats_sorts)
var degats       : int  = 0

# Portée maximale en cases (distance Manhattan)
# Cas spéciaux :
#   0 = portée illimitée (Tempête Arcanique)
#   0 = auto-ciblage sur soi-même (Rage, Lame Empoisonnée, Frénésie)
var portee       : int  = 0

# true = une case MUR ou VIDE entre le lanceur et la cible bloque le sort
# Vérifié via sort_handler._a_ligne_de_vue() (algorithme de Bresenham)
var ligne_de_vue : bool = false


# =======================================================
# COÛTS D'UTILISATION
# =======================================================

# PM déduits immédiatement à l'utilisation
var cout_pm      : int = 0

# Gold déduit immédiatement à l'utilisation
# Certains sorts ont un coût variable (Tempête Arcanique, Tir Ciblé)
# géré manuellement dans sort_handler avant _consommer_ressources()
var cout_gold    : int = 0


# =======================================================
# COOLDOWN
# -------------------------------------------------------
# Après utilisation, cooldown_actuel = cooldown_max.
# Décrémenté de 1 par tour dans joueur.debut_tour().
# Sort disponible quand cooldown_actuel = 0.
# =======================================================

# Nombre de tours de cooldown après utilisation
var cooldown_max    : int = 0

# Tours de cooldown restants — 0 = disponible, > 0 = en recharge
var cooldown_actuel : int = 0


# =======================================================
# API PUBLIQUE — Cooldown
# =======================================================

# -------------------------------------------------------
# Retourne true si le sort peut être utilisé ce tour
# -------------------------------------------------------
func est_disponible() -> bool:
	return cooldown_actuel <= 0


# -------------------------------------------------------
# Lance le cooldown — appelée par sort_handler._consommer_ressources()
# immédiatement après chaque utilisation réussie
# -------------------------------------------------------
func declencher_cooldown() -> void:
	cooldown_actuel = cooldown_max


# -------------------------------------------------------
# Réduit le cooldown d'un tour
# Appelée dans joueur.debut_tour() sur tous les sorts du joueur actif
# -------------------------------------------------------
func reduire_cooldown() -> void:
	if cooldown_actuel > 0:
		cooldown_actuel -= 1


# =======================================================
# CONSTRUCTEUR STATIQUE
# -------------------------------------------------------
# Seul moyen de créer un sort — utilisé dans tous les xxx_sorts.gd.
# L'ordre des paramètres suit la logique de lecture d'un sort :
# identité → combat → cooldown → coûts → contraintes
# =======================================================
static func creer(
	p_id          : String,
	p_nom         : String,
	p_degats      : int,
	p_portee      : int,
	p_cooldown    : int,
	p_cout_gold   : int,
	p_cout_pm     : int,
	p_ligne_vue   : bool,
	p_description : String
) -> Sort:
	var sort             := new()
	sort.id              = p_id
	sort.nom             = p_nom
	sort.degats          = p_degats
	sort.portee          = p_portee
	sort.cooldown_max    = p_cooldown
	sort.cout_gold       = p_cout_gold
	sort.cout_pm         = p_cout_pm
	sort.ligne_de_vue    = p_ligne_vue
	sort.description     = p_description
	return sort
