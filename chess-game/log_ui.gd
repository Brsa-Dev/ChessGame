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

	# Message le plus récent EN HAUT
	conteneur_messages.add_child(label)
	conteneur_messages.move_child(label, 0)

	# Supprime les messages excédentaires (les plus anciens = en bas)
	while conteneur_messages.get_child_count() > MAX_MESSAGES:
		var ancien = conteneur_messages.get_child(conteneur_messages.get_child_count() - 1)
		ancien.queue_free()
