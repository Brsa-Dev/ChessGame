# =======================================================
# sort.gd
# -------------------------------------------------------
# Ressource de base pour tous les sorts du jeu.
# Chaque sort est créé via la fonction statique creer().
# Les classes filles instancient leurs sorts dans
# leurs fichiers xxx_sorts.gd respectifs.
# =======================================================
extends Resource

# -------------------------------------------------------
# Identifiant unique du sort — utilisé pour le dispatch
# dans sort_handler.gd (ex: "guerrier_mur", "mage_gel")
# -------------------------------------------------------
var id          : String = ""

# Nom affiché dans le HUD et le log
var nom         : String = ""

# Dégâts infligés (avant bonus du lanceur)
var degats      : int    = 0

# Portée en cases (distance Manhattan)
# 0 = portée illimitée ou auto-ciblage (ex: Rage, Lame)
var portee      : int    = 0

# Nombre de tours de cooldown après utilisation
var cooldown_max    : int = 0

# Tours de cooldown restants (0 = disponible)
var cooldown_actuel : int = 0

# Coût en Gold pour utiliser le sort
var cout_gold   : int    = 0

# Coût en PM pour utiliser le sort
var cout_pm     : int    = 0

# Indique si une ligne de vue est requise pour cibler
var ligne_de_vue : bool  = false

# Description affichée dans l'interface
var description  : String = ""


# =======================================================
# ÉTAT DU COOLDOWN
# =======================================================

# -------------------------------------------------------
# Retourne true si le sort peut être utilisé ce tour
# -------------------------------------------------------
func est_disponible() -> bool:
	return cooldown_actuel <= 0


# -------------------------------------------------------
# Déclenche le cooldown après utilisation
# -------------------------------------------------------
func declencher_cooldown() -> void:
	cooldown_actuel = cooldown_max


# -------------------------------------------------------
# Réduit le cooldown d'un tour (appelé dans debut_tour)
# -------------------------------------------------------
func reduire_cooldown() -> void:
	if cooldown_actuel > 0:
		cooldown_actuel -= 1


# =======================================================
# CONSTRUCTEUR STATIQUE
# -------------------------------------------------------
# Utilisé par tous les xxx_sorts.gd pour créer les sorts.
# Centralise la création pour éviter l'oubli de champs.
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
) -> Resource:
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
