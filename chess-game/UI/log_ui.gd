# log_ui.gd
# -----------------------------------------------
# LOG UI — Historique des actions visible en jeu
# Nœud enfant du CanvasLayer UI existant dans main.tscn
# Appelé depuis main.gd via ajouter(message, couleur)
# -----------------------------------------------
extends PanelContainer

# Nombre maximum de lignes affichées simultanément
# Les plus anciens sont supprimés automatiquement
const MAX_MESSAGES = 8

# Couleurs par joueur — alignées avec COULEURS_JOUEURS dans renderer.gd
const COULEUR_J1      = Color.YELLOW
const COULEUR_J2      = Color.CYAN
const COULEUR_J3      = Color.GREEN
const COULEUR_SYSTEME = Color.WHITE  # Changements de tour, morts, boutique...

@onready var conteneur_messages = $VBoxContainer/Messages

func _ready():
	# Différé pour avoir la taille réelle du viewport
	call_deferred("_repositionner")
	
# -----------------------------------------------
# ajouter — appelé par main.gd à chaque action
# message : texte à afficher
# couleur  : couleur du texte
# -----------------------------------------------
func ajouter(message: String, couleur: Color = COULEUR_SYSTEME):
	var label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", couleur)

	conteneur_messages.add_child(label)
	conteneur_messages.move_child(label, 0)

	# ✅ CORRECTION : on compte les enfants UNE FOIS
	# et on supprime le dernier directement — pas de while infini
	var count = conteneur_messages.get_child_count()
	if count > MAX_MESSAGES:
		var ancien = conteneur_messages.get_child(count - 1)
		conteneur_messages.remove_child(ancien)  # Retire immédiatement (pas queue_free)
		ancien.queue_free()                      # Libère la mémoire après

# -----------------------------------------------
# Repositionne le Log quand la fenêtre est redimensionnée
# -----------------------------------------------
func _notification(what):
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_repositionner()

func _repositionner():
	var taille = get_viewport().get_visible_rect().size
	set_position(Vector2(5, 5))
	set_size(Vector2(350, taille.y - 10))
