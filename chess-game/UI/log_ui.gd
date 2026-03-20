# =======================================================
# UI/log_ui.gd
# -------------------------------------------------------
# Historique des actions — affiché en haut à gauche.
#
#   - Catégories sémantiques (SYSTEME, COMBAT, SORT…)
#   - Couleur par joueur si joueur != null
#   - Couleur par catégorie sinon
#   - MAX_MESSAGES derniers messages conservés
#
# Appelé via ajouter(message, categorie, joueur) depuis main.gd.
# =======================================================
class_name LogUI
extends PanelContainer


# =======================================================
# CATÉGORIES
# =======================================================
enum Categorie {
	SYSTEME,    # Tour, début/fin, général
	SORT,       # Sorts lancés, attaques, combat
	ETAT,       # Effets de statut — pièges, DoT, immobilisation
	EVENEMENT,  # Événements de plateau
	MORT,       # Éliminations, fin de partie
	ACHAT,      # Achats boutique, items utilisés
}


# =======================================================
# CONSTANTES
# =======================================================

const MAX_MESSAGES : int = 5

# Couleurs par joueur (alignées avec renderer.gd)
const COULEUR_J1 : Color = Color.YELLOW
const COULEUR_J2 : Color = Color.CYAN
const COULEUR_J3 : Color = Color.GREEN

# Couleurs par catégorie (si aucun joueur fourni)
const COULEUR_SYSTEME   : Color = Color(0.85, 0.85, 0.85)
const COULEUR_SORT      : Color = Color(0.75, 0.4,  1.0)
const COULEUR_ETAT      : Color = Color(0.0,  0.85, 0.65)
const COULEUR_EVENEMENT : Color = Color(0.0,  0.85, 0.85)
const COULEUR_MORT      : Color = Color(1.0,  0.25, 0.25)
const COULEUR_ACHAT     : Color = Color(1.0,  0.85, 0.0)


# =======================================================
# RÉFÉRENCES — Injectées par main.gd
# =======================================================

var joueurs : Array = []  # Nécessaire pour déduire la couleur joueur

@onready var _conteneur_messages : VBoxContainer = $VBoxContainer/Messages


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	call_deferred("_repositionner")


# =======================================================
# API PUBLIQUE
# =======================================================

# -------------------------------------------------------
# Ajoute un message en tête du log.
# Couleur déterminée par joueur (si fourni) ou par catégorie.
# -------------------------------------------------------
func ajouter(message: String, categorie: Categorie = Categorie.SYSTEME, joueur: Node = null) -> void:
	var couleur := _get_couleur(categorie, joueur)

	var label := Label.new()
	label.text          = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", couleur)

	_conteneur_messages.add_child(label)
	_conteneur_messages.move_child(label, 0)

	var nb : int = _conteneur_messages.get_child_count()
	if nb > MAX_MESSAGES:
		var ancien : Label = _conteneur_messages.get_child(nb - 1)
		_conteneur_messages.remove_child(ancien)
		ancien.queue_free()


# =======================================================
# HELPERS
# =======================================================

func _get_couleur(categorie: Categorie, joueur: Node) -> Color:
	# Joueur identifié → couleur joueur prioritaire
	if joueur != null:
		var idx : int = joueurs.find(joueur)
		match idx:
			0: return COULEUR_J1
			1: return COULEUR_J2
			2: return COULEUR_J3
	# Sinon couleur par catégorie
	match categorie:
		Categorie.SORT:      return COULEUR_SORT
		Categorie.ETAT:      return COULEUR_ETAT
		Categorie.EVENEMENT: return COULEUR_EVENEMENT
		Categorie.MORT:      return COULEUR_MORT
		Categorie.ACHAT:     return COULEUR_ACHAT
	return COULEUR_SYSTEME


# =======================================================
# POSITIONNEMENT
# =======================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_repositionner()


func _repositionner() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	set_position(Vector2(5, 5))
	# Largeur fixe — la hauteur s'adapte au nombre de messages (fit_content)
	set_custom_minimum_size(Vector2(280, 0))
