# =======================================================
# Manager/tour_manager.gd
# -------------------------------------------------------
# Gère le déroulement des tours de la partie :
#
#   - Ordre de jeu (tirage au sort au démarrage)
#   - Alternance des tours entre joueurs
#   - Comptage des tours globaux
#   - Timer par tour (2min30) — passe le tour si le temps expire
#   - Signaux vers main.gd (tour_change, boutique, tour global)
# =======================================================
extends Node


# =======================================================
# CONSTANTES
# =======================================================

const DUREE_TOUR_SECONDES : float = 150.0  # 2 minutes 30 par tour


# =======================================================
# RÉFÉRENCES
# =======================================================

@onready var _timer : Timer = $Timer


# =======================================================
# ÉTAT
# =======================================================

var _joueurs            : Array = []  # Liste des joueurs dans l'ordre de jeu
var _index_joueur_actif : int   = 0   # Index du joueur dont c'est le tour

# Nombre de joueurs ayant terminé leur tour dans le cycle actuel.
# Remis à 0 quand tous les joueurs ont joué (= 1 tour global terminé).
var _joueurs_ayant_joue : int = 0

# Incrémenté à chaque fois que tous les joueurs ont joué
var tour_global : int = 1


# =======================================================
# SIGNAUX
# =======================================================

signal tour_change(joueur_actif: Node)        # Joueur actif mis à jour
signal tour_global_termine(numero_tour: int)  # Tous les joueurs ont joué
signal phase_boutique(numero_tour: int)       # Déclenche l'ouverture de la boutique


# =======================================================
# INITIALISATION
# -------------------------------------------------------
# Appelée par main.gd dans _ready() AVANT get_joueur_actif().
# Tire au sort le joueur qui commence.
# =======================================================
func initialiser(liste_joueurs: Array) -> void:
	_joueurs            = liste_joueurs
	_index_joueur_actif = randi_range(0, _joueurs.size() - 1)
	print("🎲 Tirage au sort — %s commence !" % get_joueur_actif().name)
	_demarrer_timer()
	emit_signal("tour_change", get_joueur_actif())


# =======================================================
# ACCESSEUR
# =======================================================

func get_joueur_actif() -> Node:
	return _joueurs[_index_joueur_actif]


# =======================================================
# PASSAGE AU TOUR SUIVANT
# -------------------------------------------------------
# Appelée par main.gd (bouton Fin de Tour ou timer expiré).
# =======================================================
func passer_au_tour_suivant() -> void:
	_joueurs_ayant_joue += 1

	# Tour global terminé quand tous les joueurs ont joué
	if _joueurs_ayant_joue >= _joueurs.size():
		_joueurs_ayant_joue = 0
		_terminer_tour_global()

	# Rotation circulaire — revient à 0 après le dernier joueur
	_index_joueur_actif = (_index_joueur_actif + 1) % _joueurs.size()

	get_joueur_actif().debut_tour()
	_demarrer_timer()

	print("--- Tour %d — %s joue ---" % [tour_global, get_joueur_actif().name])
	emit_signal("tour_change", get_joueur_actif())


# =======================================================
# TOUR GLOBAL
# =======================================================

# -------------------------------------------------------
# Déclenche la fin de tour global : événements + boutique.
# -------------------------------------------------------
func _terminer_tour_global() -> void:
	emit_signal("tour_global_termine", tour_global)
	emit_signal("phase_boutique", tour_global)
	tour_global += 1
	print("=== Tour global %d commence ===" % tour_global)


# =======================================================
# TIMER
# =======================================================

func _demarrer_timer() -> void:
	_timer.wait_time = DUREE_TOUR_SECONDES
	_timer.start()


# -------------------------------------------------------
# Appelée automatiquement par Godot quand le timer expire
# -------------------------------------------------------
func _on_timer_timeout() -> void:
	print("⏱️ Temps écoulé ! %s passe son tour." % get_joueur_actif().name)
	passer_au_tour_suivant()
