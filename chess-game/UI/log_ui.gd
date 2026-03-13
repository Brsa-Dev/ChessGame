# =======================================================
# UI/log_ui.gd
# -------------------------------------------------------
# Historique des actions — affiché en haut à gauche.
#
#   - Affiche les MAX_MESSAGES derniers messages
#   - Les messages les plus récents arrivent en haut
#   - Chaque joueur a sa propre couleur de texte
#
# Appelé via ajouter(message, couleur) depuis main.gd.
# =======================================================
extends PanelContainer


# =======================================================
# CONSTANTES
# =======================================================

const MAX_MESSAGES : int = 8  # Nombre de messages affichés simultanément


# =======================================================
# COULEURS DES MESSAGES
# -------------------------------------------------------
# Alignées avec COULEURS_JOUEURS dans renderer.gd.
# COULEUR_SYSTEME pour les messages de jeu (tours, morts, boutique).
# =======================================================
const COULEUR_J1      : Color = Color.YELLOW
const COULEUR_J2      : Color = Color.CYAN
const COULEUR_J3      : Color = Color.GREEN
const COULEUR_SYSTEME : Color = Color.WHITE


# =======================================================
# RÉFÉRENCES
# =======================================================

@onready var _conteneur_messages : VBoxContainer = $VBoxContainer/Messages


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	# Différé pour avoir la taille réelle du viewport
	call_deferred("_repositionner")


# =======================================================
# API PUBLIQUE
# =======================================================

# -------------------------------------------------------
# Ajoute un message en haut du log.
# Si le log dépasse MAX_MESSAGES, l'entrée la plus ancienne est supprimée.
# -------------------------------------------------------
func ajouter(message: String, couleur: Color = COULEUR_SYSTEME) -> void:
	var label : Label = Label.new()
	label.text             = message
	label.autowrap_mode    = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", couleur)

	_conteneur_messages.add_child(label)
	_conteneur_messages.move_child(label, 0)  # Place en tête de liste

	# Supprime le message le plus ancien si la limite est dépassée
	var nb : int = _conteneur_messages.get_child_count()
	if nb > MAX_MESSAGES:
		var ancien : Label = _conteneur_messages.get_child(nb - 1)
		_conteneur_messages.remove_child(ancien)
		ancien.queue_free()


# =======================================================
# POSITIONNEMENT
# =======================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_repositionner()


func _repositionner() -> void:
	var taille : Vector2 = get_viewport().get_visible_rect().size
	set_position(Vector2(5, 5))
	set_size(Vector2(350, taille.y - 10))
