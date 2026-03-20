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
extends CanvasLayer


# =======================================================
# CONSTANTES
# =======================================================

const MAX_MESSAGES : int = 5

# Couleurs par joueur (alignées avec renderer.gd)
const COULEUR_J1 : Color = Color.YELLOW
const COULEUR_J2 : Color = Color.CYAN
const COULEUR_J3 : Color = Color.GREEN

# Couleur par défaut (aucun joueur fourni)
const COULEUR_SYSTEME   : Color = Color(0.85, 0.85, 0.85)


# =======================================================
# RÉFÉRENCES — Injectées par main.gd
# =======================================================

var joueurs : Array[Node] = []  # Nécessaire pour déduire la couleur joueur

@onready var _conteneur_messages : VBoxContainer = $PanelContainer/VBoxContainer/Messages


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	layer = 5
	var panel : PanelContainer = $PanelContainer
	if panel == null:
		push_error("LogUI — PanelContainer introuvable")
		return

	# Taille et position fixes en haut à gauche
	panel.set_position(Vector2(8, 8))
	panel.set_custom_minimum_size(Vector2(270, 30))

	# Fond semi-transparent
	var style := StyleBoxFlat.new()
	style.bg_color              = Color(0.05, 0.05, 0.10, 0.88)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 8.0
	style.content_margin_right  = 8.0
	style.content_margin_top    = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	# Applique une taille min sur le conteneur Messages
	# pour qu'il soit visible même vide
	var messages : VBoxContainer = $PanelContainer/VBoxContainer/Messages
	if messages != null:
		messages.set_custom_minimum_size(Vector2(250, 0))


# =======================================================
# API PUBLIQUE
# =======================================================

# -------------------------------------------------------
# Ajoute un message en tête du log.
# Couleur déterminée par joueur (si fourni) ou par catégorie.
# -------------------------------------------------------
func ajouter(message: String, joueur: Node = null) -> void:
	var couleur := _get_couleur(joueur)

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

func _get_couleur(joueur: Node) -> Color:
	if joueur != null:
		var idx : int = joueurs.find(joueur)
		match idx:
			0: return COULEUR_J1
			1: return COULEUR_J2
			2: return COULEUR_J3
	return COULEUR_SYSTEME


# =======================================================
# POSITIONNEMENT
# =======================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_repositionner()


func _repositionner() -> void:
	var panel : PanelContainer = $PanelContainer
	if panel == null:
		return
	panel.set_position(Vector2(8, 8))
