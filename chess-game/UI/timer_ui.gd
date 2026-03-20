# =======================================================
# UI/timer_ui.gd
# -------------------------------------------------------
# Affiche le numéro de tour et le temps restant.
# Centré en haut de l'écran via timer_ui.tscn.
# Mis à jour à chaque frame via _process().
# Rouge sous 30 secondes.
# =======================================================
extends CanvasLayer

const COULEUR_NORMAL  : Color = Color(1.0, 1.0, 1.0)
const COULEUR_URGENCE : Color = Color(1.0, 0.2, 0.2)  # Rouge sous 30s
const SEUIL_URGENCE   : int   = 30                     # Secondes avant rouge
const FONT_SIZE_TOUR  : int   = 16
const FONT_SIZE_TEMPS : int   = 16

# Référence injectée par main.gd
var tour_manager : Node = null

@onready var _label_tour  : Label = $PanelContainer/HBoxContainer/LabelTour
@onready var _label_temps : Label = $PanelContainer/HBoxContainer/LabelTemps


func _ready() -> void:
	layer = 6
	_label_tour.add_theme_font_size_override("font_size", FONT_SIZE_TOUR)
	_label_temps.add_theme_font_size_override("font_size", FONT_SIZE_TEMPS)


func _process(_delta: float) -> void:
	if tour_manager == null:
		return

	# Numéro de tour global
	_label_tour.text = "Tour %d  —  " % tour_manager.tour_global

	# Temps restant depuis le Timer interne de TourManager
	var secondes : int = int(tour_manager._timer.time_left)
	var minutes  : int = secondes / 60
	var secs     : int = secondes % 60
	_label_temps.text = "%02d:%02d" % [minutes, secs]

	# Rouge si temps critique
	var couleur : Color = COULEUR_URGENCE if secondes < SEUIL_URGENCE else COULEUR_NORMAL
	_label_tour.add_theme_color_override("font_color", couleur)
	_label_temps.add_theme_color_override("font_color", couleur)
