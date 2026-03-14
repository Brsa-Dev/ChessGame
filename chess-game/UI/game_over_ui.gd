# =======================================================
# UI/game_over_ui.gd
# -------------------------------------------------------
# Écran de fin de partie.
# La structure visuelle est dans game_over_ui.tscn —
# ce script ne gère que la logique (affichage + boutons).
# =======================================================
extends CanvasLayer


# -------------------------------------------------------
# Références aux nœuds de la scène — assignées
# automatiquement grâce aux chemins dans main.tscn
# -------------------------------------------------------
@onready var _label_titre  : Label  = $CenterContainer/VBoxContainer/LabelTitre
@onready var _btn_rejouer  : Button = $CenterContainer/VBoxContainer/BoutonRejouer
@onready var _btn_quitter  : Button = $CenterContainer/VBoxContainer/BoutonQuitter


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	# Connecte les boutons à leurs callbacks
	_btn_rejouer.pressed.connect(_on_rejouer)
	_btn_quitter.pressed.connect(_on_quitter)


# =======================================================
# API PUBLIQUE
# -------------------------------------------------------
# Appelée par main.gd quand un vainqueur est désigné.
# =======================================================
func afficher(vainqueur: Node) -> void:
	_label_titre.text = "🏆 %s gagne la partie !" % vainqueur.name
	visible = true


# =======================================================
# CALLBACKS BOUTONS
# =======================================================

# -------------------------------------------------------
# Recharge toute la scène — remet TOUT à zéro.
# -------------------------------------------------------
func _on_rejouer() -> void:
	get_tree().reload_current_scene()


# -------------------------------------------------------
# Ferme l'application proprement.
# -------------------------------------------------------
func _on_quitter() -> void:
	get_tree().quit()
