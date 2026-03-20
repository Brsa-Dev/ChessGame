# =======================================================
# UI/tour_ui.gd
# -------------------------------------------------------
# Affiche quel joueur joue en ce moment.
# Centré en haut, sous le timer.
# Mis à jour via rafraichir() depuis main.gd.
# =======================================================
extends CanvasLayer

const FONT_SIZE        : int   = 13
const TAILLE_CERCLE    : int   = 16   # Taille du ColorRect couleur joueur
const COULEUR_J1       : Color = Color(1.0, 1.0, 0.0)
const COULEUR_J2       : Color = Color(0.0, 1.0, 1.0)
const COULEUR_J3       : Color = Color(0.0, 1.0, 0.0)
const COULEURS_JOUEURS : Array[Color] = [COULEUR_J1, COULEUR_J2, COULEUR_J3]
const COULEUR_TEXTE    : Color = Color(0.9, 0.9, 0.9)

@onready var _color_rect   : ColorRect = $PanelContainer/HBoxContainer/ColorRect
@onready var _label_joueur : Label     = $PanelContainer/HBoxContainer/LabelJoueur

var _joueurs : Array[Node] = []  # Injecté par main.gd


func _ready() -> void:
	layer = 6
	_color_rect.custom_minimum_size = Vector2(TAILLE_CERCLE, TAILLE_CERCLE)
	_label_joueur.add_theme_font_size_override("font_size", FONT_SIZE)
	_label_joueur.add_theme_color_override("font_color", COULEUR_TEXTE)


# -------------------------------------------------------
# Appelée par main.gd à chaque changement de tour.
# -------------------------------------------------------
func rafraichir(joueur_actif: Node) -> void:
	if joueur_actif == null:
		return

	var index   : int   = _joueurs.find(joueur_actif)
	var couleur : Color = COULEURS_JOUEURS[index] if index >= 0 else COULEUR_TEXTE

	_color_rect.color = couleur
	_label_joueur.text = "Tour de %s" % joueur_actif.name
	_label_joueur.add_theme_color_override("font_color", couleur)
