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
# SIGNAUX
# =======================================================

signal tour_change(joueur_actif: Node)        # Joueur actif mis à jour
signal tour_global_termine(numero_tour: int)  # Tous les joueurs ont joué
signal phase_boutique(numero_tour: int)       # Déclenche l'ouverture de la boutique


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

var _joueurs            : Array[Node] = []  # Liste des joueurs dans l'ordre de jeu
var _index_joueur_actif : int         = 0   # Index du joueur dont c'est le tour

# Nombre de joueurs ayant terminé leur tour dans le cycle actuel.
# Remis à 0 quand tous les joueurs ont joué (= 1 tour global terminé).
var _joueurs_ayant_joue : int = 0

# Incrémenté à chaque fois que tous les joueurs ont joué
var tour_global : int = 1


# =======================================================
# INITIALISATION
# -------------------------------------------------------
# Appelée par main.gd dans _ready() AVANT get_joueur_actif().
# Tire au sort le joueur qui commence.
# -------------------------------------------------------
func initialiser(liste_joueurs: Array[Node]) -> void:
	_joueurs            = liste_joueurs
	_index_joueur_actif = randi_range(0, _joueurs.size() - 1)
	_demarrer_timer()
	tour_change.emit(get_joueur_actif())


# =======================================================
# API PUBLIQUE
# =======================================================

# -------------------------------------------------------
# Retourne le joueur dont c'est actuellement le tour.
# -------------------------------------------------------
func get_joueur_actif() -> Node:
	return _joueurs[_index_joueur_actif]


# -------------------------------------------------------
# Passe la main au joueur suivant.
# Appelée par main.gd (bouton Fin de Tour ou timer expiré).
# -------------------------------------------------------
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

	tour_change.emit(get_joueur_actif())


# =======================================================
# HELPERS PRIVÉS
# =======================================================

# -------------------------------------------------------
# Déclenche la fin de tour global : événements + boutique.
# -------------------------------------------------------
func _terminer_tour_global() -> void:
	tour_global_termine.emit(tour_global)
	phase_boutique.emit(tour_global)
	tour_global += 1


func _demarrer_timer() -> void:
	_timer.wait_time = DUREE_TOUR_SECONDES
	_timer.start()


# -------------------------------------------------------
# Appelée automatiquement par Godot quand le timer expire.
# -------------------------------------------------------
func _on_timer_timeout() -> void:
	passer_au_tour_suivant()
