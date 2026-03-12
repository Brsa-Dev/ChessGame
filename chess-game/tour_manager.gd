extends Node

# -----------------------------------------------
# TOUR MANAGER — Gestion des tours de jeu
# -----------------------------------------------

# Liste des joueurs dans l'ordre de jeu
var joueurs: Array = []

# Index du joueur dont c'est le tour
var index_joueur_actif: int = 0

# Numéro du tour global
# (s'incrémente quand tous les joueurs ont joué)
var tour_global: int = 1

# Durée d'un tour : 2min30 = 150 secondes
const DUREE_TOUR = 150.0

# Référence au Timer (nœud enfant dans la scène)
@onready var timer = $Timer

# Signaux — main.gd peut s'y connecter plus tard
signal tour_change(joueur_actif)
signal tour_global_termine(numero_tour)

# -----------------------------------------------
# Appelée par main.gd au démarrage
# Reçoit la liste des joueurs et tire au sort le premier
# -----------------------------------------------
func initialiser(liste_joueurs: Array):
	joueurs = liste_joueurs
	
	# Tirage au sort pour le premier joueur
	index_joueur_actif = randi_range(0, joueurs.size() - 1)
	print("=== Tirage au sort — Joueur ", index_joueur_actif + 1, " commence ! ===")
	
	# Démarre le timer du premier tour
	_demarrer_timer()
	
	emit_signal("tour_change", get_joueur_actif())

# -----------------------------------------------
# Retourne le joueur dont c'est le tour
# -----------------------------------------------
func get_joueur_actif() -> Node:
	return joueurs[index_joueur_actif]

# -----------------------------------------------
# Passe au joueur suivant
# Appelée par main.gd (bouton fin de tour ou timer)
# -----------------------------------------------
func passer_au_tour_suivant():
	# Index suivant en bouclant sur la liste
	index_joueur_actif = (index_joueur_actif + 1) % joueurs.size()
	
	# Si on revient au joueur 0 → tour global terminé
	if index_joueur_actif == 0:
		_fin_tour_global()
	
	# Recharge les PM du joueur actif
	get_joueur_actif().debut_tour()
	
	# Redémarre le timer
	_demarrer_timer()
	
	print("--- Tour ", tour_global, " — Joueur ", index_joueur_actif + 1, " joue ---")
	emit_signal("tour_change", get_joueur_actif())

# -----------------------------------------------
# Appelée quand tous les joueurs ont joué
# -----------------------------------------------
func _fin_tour_global():
	emit_signal("tour_global_termine", tour_global)
	tour_global += 1
	print("=== Tour global ", tour_global, " commence ===")

# -----------------------------------------------
# Démarre le timer pour ce tour
# -----------------------------------------------
func _demarrer_timer():
	timer.wait_time = DUREE_TOUR
	timer.start()

# -----------------------------------------------
# Appelée automatiquement quand le timer expire
# -----------------------------------------------
func _on_timer_timeout():
	print("⏱ Temps écoulé ! Joueur ", index_joueur_actif + 1, " passe son tour.")
	passer_au_tour_suivant()
