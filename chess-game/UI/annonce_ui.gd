# =======================================================
# UI/annonce_ui.gd
# -------------------------------------------------------
# Affiche une annonce temporaire au centre de l'écran.
# Disparaît automatiquement après DUREE_AFFICHAGE secondes.
# Utilisé pour : sorts importants, événements, morts, victoire.
# =======================================================
extends CanvasLayer

const DUREE_AFFICHAGE   : float = 2.5   # Secondes avant disparition
const FONT_SIZE         : int   = 18
const COULEUR_DEFAUT    : Color = Color(1.0,  1.0,  1.0)
const COULEUR_MORT      : Color = Color(1.0,  0.25, 0.25)
const COULEUR_EVENEMENT : Color = Color(1.0,  0.85, 0.0)
const COULEUR_VICTOIRE  : Color = Color(0.3,  1.0,  0.4)

@onready var _panel : PanelContainer = $PanelContainer
@onready var _label : Label          = $PanelContainer/LabelAnnonce

var _timer_affichage : float = 0.0  # Temps restant avant disparition


func _ready() -> void:
	layer = 20  # Par-dessus tout le reste
	_panel.visible = false
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_timer_affichage -= delta
	if _timer_affichage <= 0.0:
		_panel.visible = false


# -------------------------------------------------------
# Affiche une annonce pendant DUREE_AFFICHAGE secondes.
# couleur : optionnel — utilise COULEUR_DEFAUT si non fourni.
# -------------------------------------------------------
func afficher(message: String, couleur: Color = COULEUR_DEFAUT) -> void:
	_label.text = message
	_label.add_theme_color_override("font_color", couleur)
	_timer_affichage = DUREE_AFFICHAGE
	_panel.visible   = true
