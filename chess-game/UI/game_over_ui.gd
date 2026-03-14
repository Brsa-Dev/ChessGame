# =======================================================
# UI/game_over_ui.gd
# =======================================================
extends CanvasLayer

@onready var _label_titre : Label = $CenterContainer/VBoxContainer/LabelTitre

# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	# Force le masquage au démarrage — le CanvasLayer est visible
	# par défaut dans Godot, ce qui ferait réapparaître l'écran
	# immédiatement après un reload_current_scene().
	# Les boutons sont connectés directement dans l'éditeur (game_over_ui.tscn),
	# donc on ne les connecte PAS ici pour éviter le double appel.
	visible = false


# =======================================================
# API PUBLIQUE — Appelée par main.gd
# =======================================================
func afficher(vainqueur: Node) -> void:
	_label_titre.text = "🏆 %s gagne la partie !" % vainqueur.name
	visible = true


# =======================================================
# CALLBACKS — Connectés via l'éditeur dans game_over_ui.tscn
# =======================================================

func _on_rejouer() -> void:
	get_tree().reload_current_scene()


func _on_quitter() -> void:
	get_tree().quit()
