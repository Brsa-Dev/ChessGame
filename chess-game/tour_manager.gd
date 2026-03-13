# =======================================================
# tour_manager.gd
# -------------------------------------------------------
# Gère le déroulement des tours de la partie :
#
#   - Ordre de jeu (tirage au sort au démarrage)
#   - Alternance des tours entre joueurs
#   - Comptage des tours globaux
#   - Timer par tour (2min30)
#   - Signaux vers main.gd (tour_change, boutique, etc.)
# =======================================================
extends Node

# -------------------------------------------------------
# Constantes — durée d'un tour
# -------------------------------------------------------
const DUREE_TOUR_SECONDES : float = 150.0  # 2 minutes 30

# -------------------------------------------------------
# Référence au Timer (nœud enfant dans la scène)
# -------------------------------------------------------
@onready var _timer : Timer = $Timer

# -------------------------------------------------------
# Liste des joueurs dans l'ordre de jeu
# Injectée par main.gd via initialiser()
# -------------------------------------------------------
var _joueurs : Array = []

# Index du joueur dont c'est actuellement le tour
var _index_joueur_actif : int = 0

# Nombre de joueurs ayant joué dans le tour global actuel
# Réinitialisé à 0 quand tous les joueurs ont joué
var _joueurs_ayant_joue : int = 0

# Numéro du tour global (incrémenté quand tous ont joué)
var tour_global : int = 1


# -------------------------------------------------------
# Signaux — écoutés par main.gd
# -------------------------------------------------------
signal tour_change(joueur_actif: Node)         # Nouveau joueur actif
signal tour_global_termine(numero_tour: int)   # Tous les joueurs ont joué
signal phase_boutique(numero_tour: int)        # Ouvre la boutique


# =======================================================
# INITIALISATION
# -------------------------------------------------------
# Appelée par main.gd dans _ready() AVANT tout appel
# à get_joueur_actif(). Tire au sort le premier joueur.
# =======================================================
func initialiser(liste_joueurs: Array) -> void:
	_joueurs            = liste_joueurs
	_index_joueur_actif = randi_range(0, _joueurs.size() - 1)
	print("🎲 Tirage au sort — %s commence !" % get_joueur_actif().name)
	_demarrer_timer()
	emit_signal("tour_change", get_joueur_actif())


# =======================================================
# ACCESSEURS
# =======================================================

# -------------------------------------------------------
# Retourne le joueur dont c'est le tour
# -------------------------------------------------------
func get_joueur_actif() -> Node:
	return _joueurs[_index_joueur_actif]


# =======================================================
# PASSAGE AU TOUR SUIVANT
# -------------------------------------------------------
# Appelée par main.gd (bouton Fin de Tour ou timer)
# =======================================================
func passer_au_tour_suivant() -> void:
	_joueurs_ayant_joue += 1

	# Quand tous les joueurs ont joué → tour global terminé
	if _joueurs_ayant_joue >= _joueurs.size():
		_joueurs_ayant_joue = 0
		_terminer_tour_global()

	# Passe au joueur suivant (rotation circulaire)
	_index_joueur_actif = (_index_joueur_actif + 1) % _joueurs.size()

	# Initialise le début de tour du nouveau joueur actif
	get_joueur_actif().debut_tour()

	# Redémarre le timer pour ce nouveau tour
	_demarrer_timer()

	print("--- Tour %d — %s joue ---" % [tour_global, get_joueur_actif().name])
	emit_signal("tour_change", get_joueur_actif())


# =======================================================
# TOUR GLOBAL
# =======================================================

# -------------------------------------------------------
# Appelée quand tous les joueurs ont joué.
# Émet les signaux de fin de tour global et de boutique.
# -------------------------------------------------------
func _terminer_tour_global() -> void:
	emit_signal("tour_global_termine", tour_global)
	emit_signal("phase_boutique", tour_global)
	tour_global += 1
	print("=== Tour global %d commence ===" % tour_global)


# =======================================================
# TIMER
# =======================================================

# -------------------------------------------------------
# Démarre le timer pour le tour courant
# -------------------------------------------------------
func _demarrer_timer() -> void:
	_timer.wait_time = DUREE_TOUR_SECONDES
	_timer.start()


# -------------------------------------------------------
# Appelée automatiquement quand le timer expire
# Le joueur actif passe son tour
# -------------------------------------------------------
func _on_timer_timeout() -> void:
	print("⏱️ Temps écoulé ! %s passe son tour." % get_joueur_actif().name)
	passer_au_tour_suivant()
