 ###############################################################################
#
# Live Bug Tracer
# v2.1 (06/03/2012)   ©2012 MenzAgitat
#
# IRC: irc.epiknet.org  #boulets / #eggdrop
#
# Mes scripts sont téléchargeables sur http://www.eggdrop.fr
#
 ###############################################################################

#
# Description :
#
# Live Bug Tracer est une boîte à outils de déboguage. Ce script s'adresse aux
# développeurs Tcl, mais aussi à l'utilisateur lambda qui y trouvera plusieurs
# fonctionnalités simples d'utilisation et potentiellement très utiles.
#
# Les retours du débogueur s'affichent en partyline; vous devez donc vous y
# connecter sans quoi vous ne verrez rien.
#
#
# Fonctionnalités :
#
#	- Affichage (et log) automatique du backtrace si votre eggdrop rencontre une
#		erreur. En cas d'erreurs redondantes, seule la première occurrence est
#		affichée. Plus besoin d'avoir activé la commande .set en partyline pour
#		pouvoir afficher le backtrace d'une erreur, plus besoin non plus d'être là
#		au bon moment ni d'être hyper rapide pour taper .set errorInfo après qu'une
#		erreur se soit produite. Exit des prises de tête pour traquer un bug qui se
#		produit une fois par mois et pour lequel on n'est jamais là au bon moment
#		pour observer ce qui s'est passé.
#	- Différenciation erreur catchée / non catchée et possibilité de n'afficher
#		que les unes, les autres, ou les deux.
#	- Système anti-boucle infinie permettant de détecter / interrompre / afficher
#		les types courants de boucles infinies. Un eggdrop qui cesse de répondre,
#		consomme beaucoup de temps processeur et quitte en ping timeout vient
#		vraisemblablement d'exécuter une boucle infinie.
#	- Surveillance des lectures / écritures / suppression d'une variable statique.
#	- Surveillance des lectures / écritures / suppression d'une variable
#		temporaire dans une procédure (n'existant que durant l'exécution de la
#		procédure).
#	- Surveillance des appels / retours / suppression / renommage d'une procédure.
#	- Surveillance des appels / retours / suppression / renommage d'une commande.
# - Traçage de l'exécution d'une procédure ligne par ligne.
#
#
# Commandes :
#
# .autobacktrace <argument(s)>
#		Permet de gérer le backtrace automatique des erreurs.
#		Arguments acceptés :
#			+/-errors
#				Active/désactive le backtrace automatique des erreurs non-catchées.
#			+/-catch
#				Active/désactive le backtrace automatique des erreurs catchées.
#			status
#				Affiche le statut du backtrace automatique.
# .loopfuse <on/off/status>
#		Permet d'activer/désactiver la protection anti-boucle infinie, ou d'afficher
#		son statut.
# .watch <$variable/procédure/commande> [off]
#		Commence ou cesse la surveillance d'une variable statique, d'une procédure
#		ou d'une commande.
# .watch <$variable> in <procédure> [off]
#		Commence ou cesse la surveillance d'une variable temporaire dans la
#		procédure spécifiée. Vous ne pouvez avoir qu'une seule surveillance de ce
#		type à la fois.
# .trace <procédure> [off]
#		Commence ou cesse le traçage d'une procédure.
#		Dans les lignes affichées lors d'un traçage de procédure, "rec" indique la
#		profondeur de récursion et "lvl" le niveau de pile.
# .debuglist
#		Affiche tous les trace actifs posés par Live Bug Tracer. Certains trace
#		peuvent être suivis de la mention "(latent)", ce qui signifie qu'ils ne
#		sont actifs que durant l'exécution d'une certaine procédure.
# .detachdebuggers
#		Cesse tous les traçages/surveillances que vous avez pu mettre au moyen des
#		commandes .trace ou .watch.
#
# Remarque : toutes les commandes sont disponibles en 2 versions : publique et
# partyline.
#
# 
# Remerciements : ealexp (pour les nombreuses idées), Artix.
#

#
# Changelog :
#
# 1.0
#		- 1ère version
# 2.0
#		- Trop de nouveautés et de changements pour tous les énumérer, la v1.0
#			possédait pour toute fonctionnalité d'afficher le backtrace des erreurs
#			en temps réel.
#		- Passage sous licence Creative Commons
# 2.1    par ZarTek-Creole ( https://github.com/ZarTek-Creole )
#		- Ajout de la posibilité de redirigers les message vers un salon
#			voir le praramettre : variable default_channel_destionation
#

#
# Licence
#
#		Cette création est mise à disposition selon le Contrat
#		Attribution-NonCommercial-ShareAlike 3.0 Unported disponible en ligne
#		http://creativecommons.org/licenses/by-nc-sa/3.0/ ou par courrier postal à
#		Creative Commons, 171 Second Street, Suite 300, San Francisco, California
#		94105, USA.
#		Vous pouvez également consulter la version française ici :
#		http://creativecommons.org/licenses/by-nc-sa/3.0/deed.fr
#

if {[::tcl::info::commands ::LiveBugTracer::uninstall] eq "::LiveBugTracer::uninstall"} { ::LiveBugTracer::uninstall }
# Note pour les programmeurs :
# Dans la version 1.6.19 d'Eggdrop, le numéro de version affiché par .vbottree et [numversion] est incorrect; il affiche 1061800 ou 1061801, ce qui correspond à la version 1.6.18. On utilise donc une autre technique pour vérifier le numéro de version.
if { [join [split [::tcl::string::range [lindex $version 0] 0 5] "."] ""] < 1620 } { putloglev o * "\00304\[Live Bug Tracer - Erreur\]\003 La version de votre Eggdrop est \00304[set ::version]\003; Live Bug Tracer ne fonctionnera correctement que sur les Eggdrops version 1.6.20 ou supérieure." ; return }
if { [::tcl::info::tclversion] < 8.5 } { putloglev o * "\00304\[Live Bug Tracer - Erreur\]\003 Live Bug Tracer nécessite que Tcl 8.5 (ou plus) soit installé pour fonctionner. Votre version actuelle de Tcl est \00304[set ::tcl_version]\003." ; return }
package require Tcl 8.5
namespace eval LiveBugTracer {



 ###############################################################################
### Configuration
 ###############################################################################

	## Le backtrace automatique des erreurs doit-il être activé par défaut ?
	# (1 = oui / 0 = non)
	variable default_autobacktrace_status 1

	## L'affichage des erreurs catchées doit-il être activé par défaut ?
	# (1 = oui / 0 = non)
	variable default_autobacktrace_catch_status 0

	## La protection anti-boucle infinie doit-elle être activée par défaut ?
	# Les commandes "à risque" sont alors remplacées par des procédures ayant
	# une fonctionnalité équivalente, mais pourvues d'un "fusible" afin
	# d'interrompre une boucle infinie potentielle.
	# Soyez conscient que ces procédures s'exécutent moins rapidement que les
	# commandes d'origine, et bien que ça ne soit pas très sensible, vous ne
	# devriez pas laisser cette protection activée en permanence à moins d'avoir
	# une raison valable de le faire.
	variable default_anti_infiniteloop_status 0

	## Après combien de secondes la protection anti-boucle infinie doit-elle
	# considérer une boucle comme étant infinie ? Passé ce délai, la boucle
	# sera interrompue et la ligne responsable affichée.
	# Ne définissez pas une valeur trop basse, certaines boucles peuvent
	# naturellement mettre plusieurs secondes à être traitées.
	variable assume_infinite_loop_after 5

	## Si vous utilisez PublicTcl (script du même auteur, à télécharger
	# séparément) et sachant que toute commande que vous tapez par son biais est
	# automatiquement catchée, souhaitez-vous que Live Bug Tracer ne considère pas
	# les erreurs éventuellement produites comme étant catchées afin de les
	# afficher normalement ?
	# (1 = oui / 0 = non)
	variable dont_consider_PublicTcl_errors_as_catched 1

	## Salon de destination des messages (en plus qu'en partyline)
	# mettre "#votre_salon" et pour desactiver laisser vide en metant ""
    # A savoir: Vous pouvez également mettre votre pseudonyme pour avoir en privée
	variable default_channel_destionation ""

	## Si certains des scripts que vous utilisez utilisent des "trace", ceux-ci
	# risquent de polluer le traçage des procédures (commande .trace).
	# Vous pouvez définir ici une liste de procédures de callback connues qui
	# seront alors exclues.
	variable known_tracers {::LiveBugTracer::errorInfo_callback ::LiveBugTracer::catch_callback ::motus::debug_catch_delayer}


	###
	##	COMMANDES ET AUTORISATIONS
	#

	## Préfixe des commandes publiques
	variable pub_command_prefix "."
	# Remarque : le préfixe des commandes de partyline est toujours "."

	## Autorisations requises pour utiliser les commandes de ce script
	variable debugging_auth "n|n"
	
	## Commande pour activer/désactiver le backtrace automatique des erreurs
	# (surveillance en temps réel de la variable $::errorInfo)
	variable autobacktrace_cmd "autobacktrace"

	## Commande pour surveiller les appels/modifications/suppression/retours
	# d'une variable, d'une procédure ou d'une commande, 
	variable watch_cmd "watch"

	## Commande pour tracer pas à pas l'exécution une procédure
	variable trace_cmd "trace"

	## Commande pour afficher une liste de tous les traçages et surveillances en
	# cours
	variable list_traces_cmd "debuglist"

	## Commande pour arrêter tous les traçages / surveillances en cours
	# (seulement ceux que vous avez posé vous-même avec Live Bug Tracer)
	variable clean_traces_cmd "detachdebuggers"

	## Commande pour activer/désactiver la protection anti-boucle infinie.
	variable anti_infiniteloop_cmd "loopfuse"

    ## Commande pour activer/désactiver l'envoi vers un salon.
	variable destination_cmd "destination"


	###
	##	VISUEL
	#

	## Longueur maximale d'une ligne affichable.
	# Si l'affichage de certaines lignes est tronqué, réduisez cette valeur.
	variable max_line_length 435

	## Longueur maximale des valeurs : détermine le nombre maximum de caractères à
	# afficher pour les lignes de code, le contenu des variables, etc...
	# Lorsqu'une telle valeur est tronquée, un symbole sera ajouté à la fin pour
	# le signaler (voir option truncate_symbol).
	variable max_data_length 300

	## Filtrer tous les styles visuels comme les couleurs, gras, etc ?
	# (1 = oui / 0 = non)
	# Veuillez noter que les couleurs améliorent la lisibilité des retours du
	# débogueur. 
	variable no_visual_styles 0
	
	## Préfixe des messages de Live Bug Tracer
	variable default_prefix "\00307\[LBT\]\003 "

	## Préfixe des lignes d'information affichées par les callbacks
	variable callback_prefix "\00307\[LBT\]\003 "

	## Style visuel utilisé pour mettre en évidence du texte dans les messages de
	# Live Bug Tracer
	variable highlight_color "\00314"

	## Symbole visuel indiquant qu'une valeur a été tronquée
	variable truncate_symbol "\003(...)"

	## Préfixe d'une erreur non-catchée
	variable error_main_prefix "\00305--\003\00304--\003->"

	## Préfixe d'une ligne de backtrace d'erreur non-catchée
	variable error_backtrace_prefix "\00314--\003\00315--\003->"

	## Préfixe d'une erreur catchée
	variable catched_error_main_prefix "\00306--\003\00313--\003->"

	## Préfixe d'une ligne de backtrace d'erreur catchée
	variable catched_error_backtrace_prefix "\00314--\003\00315--\003->"

	## Style visuel utilisé pour afficher le backtrace des erreurs
	variable backtrace_color "\00314"

	## Style visuel utilisé pour un code d'erreur indiquant une erreur
	variable wrong_errorcode_color "\00304"
	
	## Style visuel utilisé pour un code d'erreur n'indiquant pas d'erreur
	variable right_errorcode_color "\00303"

	## Style visuel indiquant l'appel d'une procédure en cours de traçage
	variable trace_proc_call_color "\00303"

	## Style visuel indiquant le retour d'une procédure en cours de traçage
	variable trace_proc_return_color "\00305"

	## Style visuel des séparateurs dans le traçage ligne par ligne d'une
	# procédure
	variable trace_separator_color "\00307"

	## Style visuel des commandes exécutées dans le traçage ligne par ligne d'une
	# procédure
	variable trace_cmd_color "\00314"

	## Séparateur de fin de traçage
	variable trace_end_symbol [::tcl::string::repeat "\00302-\00312-" 18]

	## Style visuel indiquant la lecture d'une variable surveillée
	variable watch_var_read_color "\00302"

	## Style visuel indiquant l'écriture d'une variable surveillée
	variable watch_var_write_color "\00303"

	## Style visuel indiquant la suppression d'une variable surveillée
	variable watch_var_unset_color "\00305"

	## Préfixe indiquant la valeur précédente d'une variable surveillée qui a été
	# modifiée
	variable watch_var_in_prefix "\00310>\003"

	## Préfixe indiquant la valeur actuelle d'une variable surveillée qui a été
	# modifiée
	variable watch_var_out_prefix "\00310<\003"

	## Style visuel indiquant l'appel d'une procédure surveillée
	variable watch_proc_call_color "\00303"

	## Style visuel indiquant le retour d'une procédure surveillée
	variable watch_proc_return_color "\00305"

	## Style visuel indiquant l'appel d'une commande surveillée
	variable watch_cmd_call_color "\00303"

	## Style visuel indiquant le retour d'une commande surveillée
	variable watch_cmd_return_color "\00305"
	


 ###############################################################################
### Fin de la configuration
 ###############################################################################



	 #############################################################################
	### Initialisation
	 #############################################################################
	variable scriptname "Live Bug Tracer"
	variable version "2.1.20220528"
	variable autobacktrace_status $default_autobacktrace_status
	variable autobacktrace_catched_errors $default_autobacktrace_catch_status
	variable anti_infiniteloop_status $default_anti_infiniteloop_status
	if { ${default_channel_destionation} == "" } { 
        variable destination_status 0
        variable channel_destionation ""
    } else { 
        variable destination_status 1 
        variable channel_destionation ${default_channel_destionation}
    }
	variable running_traces {}
	variable latent_traces {}
	set ::LiveBugTracer::trace_is_running 0
	variable removable_tracers {\
		::LiveBugTracer::var_read_watch_call ::LiveBugTracer::var_write_watch_call ::LiveBugTracer::var_unset_watch_call\
		::LiveBugTracer::varinproc_read_watch_call ::LiveBugTracer::varinproc_write_watch_call ::LiveBugTracer::varinproc_unset_watch_call\
		::LiveBugTracer::enter_proc_watch_call ::LiveBugTracer::leave_proc_watch_call ::LiveBugTracer::delete_proc_watch_call ::LiveBugTracer::rename_proc_watch_call\
		::LiveBugTracer::enter_cmd_watch_call ::LiveBugTracer::leave_cmd_watch_call ::LiveBugTracer::delete_cmd_watch_call ::LiveBugTracer::rename_cmd_watch_call\
		::LiveBugTracer::enter_trace_call ::LiveBugTracer::leave_trace_call ::LiveBugTracer::delete_trace_call ::LiveBugTracer::rename_trace_call ::LiveBugTracer::enterstep_trace_call\
		::LiveBugTracer::stop_varinproc_watch_call ::LiveBugTracer::transfer_varinproc_watch_call ::LiveBugTracer::sent_message\
	}
	set known_tracers [concat $removable_tracers $known_tracers]
	if { ![::tcl::info::exists ::errorInfo] } { set ::errorInfo {} }
	proc uninstall {args} {
		putlog "Désallocation des ressources de [set ::LiveBugTracer::scriptname]..."
		foreach binding [lsearch -inline -all -regexp [binds *[set ns [::tcl::string::range [namespace current] 2 end]]*] " (::)?$ns"] {
			unbind [lindex $binding 0] [lindex $binding 1] [lindex $binding 2] [lindex $binding 4]
		}
		::LiveBugTracer::clean_all_traces - - - - - uninstall
		if { $::LiveBugTracer::anti_infiniteloop_status } { ::LiveBugTracer::loopfuse - - 0 }
		uplevel #0 [list trace remove variable ::errorInfo write ::LiveBugTracer::errorInfo_callback]
		uplevel #0 [list trace remove execution catch leave ::LiveBugTracer::catch_callback]
		namespace delete ::LiveBugTracer
	}
}

 ###############################################################################
### Activation / désactivation du backtrace automatique des erreurs
 ###############################################################################
proc ::LiveBugTracer::pub_activate_deactivate {nick host hand chan arg} {
	::LiveBugTracer::activate_deactivate $nick $host $hand $chan - $arg
}
proc ::LiveBugTracer::dcc_activate_deactivate {hand idx arg} {
	::LiveBugTracer::activate_deactivate [set nick [hand2nick $hand]] [getchanhost $nick] $hand - $idx $arg
}
proc ::LiveBugTracer::activate_deactivate {nick host hand chan idx arg} {
	set log 0
	if { [set arg [::tcl::string::tolower $arg]] eq "" } {
		set message "\037Syntaxe\037 : [::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::autobacktrace_cmd] \00314<\003argument(s)\00314>\003 \00307|\003 permet de gérer le backtrace automatique des erreurs."
	} else {
		set invalid_argument 0 ; set some_valid_arguments 0 ; set status_has_changed 0
		foreach argument [split $arg] {
			switch -- $argument {
				+errors {
					set ::LiveBugTracer::autobacktrace_status 1
					set some_valid_arguments 1 ; set status_has_changed 1
				}
				-errors {
					set ::LiveBugTracer::autobacktrace_status 0
					set some_valid_arguments 1 ; set status_has_changed 1
				}
				+catch {
					set ::LiveBugTracer::autobacktrace_catched_errors 1
					set some_valid_arguments 1 ; set status_has_changed 1
				}
				-catch {
					set ::LiveBugTracer::autobacktrace_catched_errors 0
					set some_valid_arguments 1 ; set status_has_changed 1
				}
				status { set some_valid_arguments 1 }
				default { set invalid_argument 1 }
			}
		}
		if { $invalid_argument && !$some_valid_arguments } {
			set message "Argument invalide. Les arguments acceptés sont \002\00314<\003+\00314/\003-\00314>\003errors\002 (active / désactive le backtrace automatique en cas d'erreur non-catchée), \002\00314<\003+\00314/\003-\00314>\003catch\002 (active / désactive le backtrace automatique en cas d'erreur catchée) et \002status\002 affiche le statut du backtrace automatique."
		} else {
			set message "Statut du backtrace automatique en cas d'erreur :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::flagstate $::LiveBugTracer::autobacktrace_status]errors  [::LiveBugTracer::flagstate $::LiveBugTracer::autobacktrace_catched_errors]catch\003"
			set log 1
		}
		if { ($status_has_changed) && ([::tcl::info::exists ::LiveBugTracer::last_error]) } { unset ::LiveBugTracer::last_error }
	}
	::LiveBugTracer::output_message $chan $idx $log $message
}
 ###############################################################################
### Activation / désactivation de l'envois des message vers un salon
 ###############################################################################
proc ::LiveBugTracer::pub_destination {nick host hand chan arg} {
	::LiveBugTracer::activate_deactivate_destination $nick $host $hand $chan - $arg
}
proc ::LiveBugTracer::dcc_destination {hand idx arg} {
	::LiveBugTracer::activate_deactivate_destination [set nick [hand2nick $hand]] [getchanhost $nick] $hand - $idx $arg
}
proc ::LiveBugTracer::activate_deactivate_destination {nick host hand chan idx arg} {
	set log 0
    if { $arg eq "off" } {
		if { !$::LiveBugTracer::destination_status } {
			set message "La sortie vers le salon est déjà désactivé."
		} else {
			set ::LiveBugTracer::destination_status 0
			set ::LiveBugTracer::channel_destination ""
			set message "La sortie vers un salon est maintenant désactivé."
			set log 1
		}
	} elseif { $arg eq "status" } {
		if { !$::LiveBugTracer::destination_status } {
            set message "La sortie vers un salon est désactivé."
		} else {
			set message "La sortie vers un salon est activée vers ${::LiveBugTracer::channel_destination}."
		}
	} elseif { [set arg [::tcl::string::tolower $arg]] != "" } {
		if { $::LiveBugTracer::destination_status } {
			set message "La sortie vers un salon est activée vers ${::LiveBugTracer::channel_destination}."
		} else {
			set ::LiveBugTracer::destination_status 1
            set ::LiveBugTracer::channel_destination $arg
			set message "La sortie est activée vers ${::LiveBugTracer::channel_destination}."
			set log 1
		}
	} else {
		set message "\037Syntaxe\037 : [::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::destination_cmd] \00314<\003#nom_de_salon\00314/\003off\00314/\003status\00314>\003 \00307|\003 permet de gérer l'envois des sorties vers un salon spécifique."
	}
	::LiveBugTracer::output_message $chan $idx $log $message
}

 ###############################################################################
### Activation / désactivation de la protection anti-boucle infinie
 ###############################################################################
proc ::LiveBugTracer::pub_loopfuse {nick host hand chan arg} {
	::LiveBugTracer::activate_deactivate_loopfuse $nick $host $hand $chan - $arg
}
proc ::LiveBugTracer::dcc_loopfuse {hand idx arg} {
	::LiveBugTracer::activate_deactivate_loopfuse [set nick [hand2nick $hand]] [getchanhost $nick] $hand - $idx $arg
}
proc ::LiveBugTracer::activate_deactivate_loopfuse {nick host hand chan idx arg} {
	set log 0
	if { [set arg [::tcl::string::tolower $arg]] eq "on" } {
		if { $::LiveBugTracer::anti_infiniteloop_status } {
			set message "La protection anti-boucle infinie est déjà activée."
		} else {
			set ::LiveBugTracer::anti_infiniteloop_status 1
			::LiveBugTracer::loopfuse $chan $idx 1
			set message "La protection anti-boucle infinie est activée."
			set log 1
		}
	} elseif { $arg eq "off" } {
		if { !$::LiveBugTracer::anti_infiniteloop_status } {
			set message "La protection anti-boucle infinie est déjà désactivée."
		} else {
			set ::LiveBugTracer::anti_infiniteloop_status 0
			::LiveBugTracer::loopfuse $chan $idx 0
			set message "La protection anti-boucle infinie est désactivée."
			set log 1
		}
	} elseif { $arg eq "status" } {
		if { $::LiveBugTracer::anti_infiniteloop_status } {
			set message "La protection anti-boucle infinie est activée."
		} else {
			set message "La protection anti-boucle infinie est désactivée."
		}
	} else {
		set message "\037Syntaxe\037 : [::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::anti_infiniteloop_cmd] \00314<\003on\00314/\003off\00314/\003status\00314>\003 \00307|\003 permet de gérer la protection anti-boucle infinie."
	}
	::LiveBugTracer::output_message $chan $idx $log $message
}
proc ::LiveBugTracer::loopfuse {chan idx arg} {
	# activation de la protection anti-infinite loop
	if { $arg } {
		if { [::tcl::info::commands ::for_LBT_bak] eq "" } {
			rename ::for ::for_LBT_bak
		} else {
			set message "Conflit lors du renommage de la commande for en for_LBT_bak. Une commande ou procédure portant ce nom existe déjà."
			::LiveBugTracer::output_message $chan $idx 1 $message
			return
		}
		if { [::tcl::info::commands ::while_LBT_bak] eq ""} {
			rename ::while ::while_LBT_bak
		} else {
			set message "Conflit lors du renommage de la commande while en while_LBT_bak. Une commande ou procédure portant ce nom existe déjà."
			::LiveBugTracer::output_message $chan $idx 1 $message
			return
		}
		uplevel #0 {
			proc ::for {start test next command} {
				set timeout [::tcl::clock::seconds]
				incr timeout $::LiveBugTracer::assume_infinite_loop_after
				set command "if { \[::tcl::clock::seconds] > $timeout } { error \"\[set ::LiveBugTracer::default_prefix\]Boucle infinie probable détectée (temps d'exécution >[set ::LiveBugTracer::assume_infinite_loop_after]s) dans \[::LiveBugTracer::handle_infinite_loop for\]\" ; return } ; $command"
				set errorcode [catch { uplevel [list for_LBT_bak $start $test $next $command] } result]
				return -code $errorcode $result
			}
			proc ::while {test command} {
				set timeout [::tcl::clock::seconds]
				incr timeout $::LiveBugTracer::assume_infinite_loop_after

				set errorcode [catch { uplevel [list while_LBT_bak $test "if { \[::tcl::clock::seconds] > $timeout} { error \"\[set ::LiveBugTracer::default_prefix\]Boucle infinie probable détectée (temps d'exécution >[set ::LiveBugTracer::assume_infinite_loop_after]s) dans \[::LiveBugTracer::handle_infinite_loop while\]\" ; return } ; $command"] } result]
				return -code $errorcode $result
			}
		}
	# désactivation de la protection anti-infinite loop
	} else {
		if { [::tcl::info::commands ::for_LBT_bak] ne "" } {
			rename ::for ""
			rename ::for_LBT_bak ::for
		} else {
			set message "Erreur lors de la restauration de la commande for d'origine : la commande for_LBT_bak n'a pas été trouvée."
			::LiveBugTracer::output_message $chan $idx 1 $message
			return
		}
		if { [::tcl::info::commands ::while_LBT_bak] ne "" } {
			rename ::while ""
			rename ::while_LBT_bak ::while
		} else {
			set message "Erreur lors de la restauration de la commande while d'origine : la commande while_LBT_bak n'a pas été trouvée."
			::LiveBugTracer::output_message $chan $idx 1 $message
			return
		}
	}
}

 ###############################################################################
### Retourne un affichage détaillé au cas où un infinite loop a été détecté
 ###############################################################################
proc ::LiveBugTracer::handle_infinite_loop {type} {
	array set frame [::tcl::info::frame [expr {[::tcl::info::frame] - 5}]]
	if { $frame(type) eq "source" } {
		set output "[lindex [split $frame(file) "/"] end] ligne [set frame(line)] :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length [regsub -all {\n} $frame(cmd) " "]]"
	} else {
		set output "la commande :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length [regsub -all {\n} $frame(cmd) " "]]"
	}
	::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - "[set ::LiveBugTracer::default_prefix]Boucle infinie probable détectée (temps d'exécution >[set ::LiveBugTracer::assume_infinite_loop_after]s) dans [set output]"]
	return $output
}

 ###############################################################################
### Retourne - ou + selon que la valeur fournie vaut 0 ou 1
 ###############################################################################
proc ::LiveBugTracer::flagstate {value} {
	if { !$value } { return "-" } { return "+" }
}

 ###############################################################################
### Procédure de callback appelée lorsque la variable $::errorInfo est modifiée
 ###############################################################################
proc ::LiveBugTracer::errorInfo_callback {args} {
	# Temporisation : sans ce délai, le backtrace n'a pas pu se faire et la
	# variable $errorInfo ne contient que l'erreur. Un délai de 1 suffirait, mais
	# on laisse ainsi le temps au script de différencier une erreur catchée d'une
	# erreur non catchée.
	after 100 {::LiveBugTracer::backtrace_error 1}
}

 ###############################################################################
### Procédure de callback appelée lorsque la commande catch est utilisée
 ###############################################################################
proc ::LiveBugTracer::catch_callback {command errorcode result operation} {
	if { $result } { 
		array set frame [::tcl::info::frame [expr {[::tcl::info::frame] - 3}]]
		# on définit une exception pour PublicTcl (script du même auteur à
		# télécharger séparément) afin que les erreurs générées par son biais
		# s'affichent, indépendamment du fait qu'on affiche ou non les erreurs
		# catchées.
		if { ($::LiveBugTracer::dont_consider_PublicTcl_errors_as_catched) && ([lindex $frame(cmd) 0] eq "::publicTcl::tcl_command") } {
			after 1 {::LiveBugTracer::backtrace_error 1}
		} else {
			after 0 {::LiveBugTracer::backtrace_error 0}
		}
	}
}

 ###############################################################################
### Affichage de $::errorInfo si son contenu a changé
### type peut valoir 0 si le changement a été provoqué par une erreur catchée,
### ou 1 s'il a été provoqué par une erreur franche.
 ###############################################################################
proc ::LiveBugTracer::backtrace_error {type {args {}}} {
	# Si l'erreur est la même que la précédente, on ne l'affiche pas
	if { ([::tcl::info::exists ::LiveBugTracer::last_error]) && ($::LiveBugTracer::last_error eq $::errorInfo) } {
		return
	}
	variable last_error $::errorInfo
	if { (!$type && !$::LiveBugTracer::autobacktrace_catched_errors) || ($type && !$::LiveBugTracer::autobacktrace_status) } {
		return
	} else {
		if { $type } {
			set main_prefix $::LiveBugTracer::error_main_prefix
			set backtrace_prefix $::LiveBugTracer::error_backtrace_prefix
		} else {
			set main_prefix $::LiveBugTracer::catched_error_main_prefix
			set backtrace_prefix $::LiveBugTracer::catched_error_backtrace_prefix
		}
		set output [split $::errorInfo "\n"]
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - "[set main_prefix][set ::LiveBugTracer::backtrace_color] [lindex $output 0]\003"]
		foreach line [lrange $output 1 end] {
			::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - "[set backtrace_prefix][set ::LiveBugTracer::backtrace_color] $line\003"]
		}
	}
}

 ###############################################################################
### Surveillance d'une variable / commande / procédure au moyen de .watch
 ###############################################################################
proc ::LiveBugTracer::pub_watch {nick host hand chan arg} {
	::LiveBugTracer::watch $nick $host $hand $chan - $arg
}
proc ::LiveBugTracer::dcc_watch {hand idx arg} {
	::LiveBugTracer::watch [set nick [hand2nick $hand]] [getchanhost $nick] $hand - $idx $arg
}
proc ::LiveBugTracer::watch {nick host hand chan idx arg} {
	lassign $arg raw_target command raw_in_proc command2
	set log 0
	if { $arg eq "" } {
		set message "\037Syntaxe\037 : [::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::watch_cmd] \00314<\003\$variable\00314/\003procédure\00314/\003commande\00314> \[\003off\00314\]\003 \00307|\003 commence ou cesse la surveillance d'une variable statique, d'une procédure ou d'une commande."
		set message2 "\037Syntaxe\037 : [::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::watch_cmd] \00314<\003\$variable\00314>\003 in \00314<\003procédure\00314> \[\003off\00314\]\003 \00307|\003 commence ou cesse la surveillance d'une variable temporaire dans la procédure spécifiée."
	# La cible est une variable
	} elseif { ![::tcl::string::first "\$" $raw_target] } {
		regsub {^\$?(::)?} $raw_target "::" target
		regsub {^(::)?} $raw_in_proc "::" in_proc
		if { ([regexp {^(::.*)::} $target dummy target_namespace]) && (![namespace exists $target_namespace]) } {
			set message "Le namespace[set ::LiveBugTracer::highlight_color] [set target_namespace]\003 n'existe pas."
		} elseif { $target eq "::errorInfo" } {
			set message "Un système de surveillance dédié à la variable \$::errorInfo est prévu dans [set ::LiveBugTracer::scriptname]. Utilisez la commande \002[::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::autobacktrace_cmd]\002 pour activer ou désactiver le backtrace automatique des erreurs."
		} else {
			# .watch item off
			if { $command eq "off" } {
				if { [lsearch -exact [uplevel #0 [list trace info variable $target]] "read ::LiveBugTracer::var_read_watch_call"] ne -1 } {
					uplevel #0 [list trace remove variable $target read ::LiveBugTracer::var_read_watch_call]
					set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type var target $target tracetype read call ::LiveBugTracer::var_read_watch_call]]] $index]
					uplevel #0 [list trace remove variable $target write ::LiveBugTracer::var_write_watch_call]
					set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type var target $target tracetype write call ::LiveBugTracer::var_write_watch_call]]] $index]
					uplevel #0 [list trace remove variable $target unset ::LiveBugTracer::var_unset_watch_call]
					set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type var target $target tracetype unset call ::LiveBugTracer::var_unset_watch_call]]] $index]
					if { [::tcl::info::exists ::LiveBugTracer::shadow($target)] } { unset ::LiveBugTracer::shadow($target) }
					set message "Surveillance désactivée sur la variable[set ::LiveBugTracer::highlight_color] [set raw_target]\003."
					set log 1
				} else {
					set message "La variable[set ::LiveBugTracer::highlight_color] [set raw_target]\003 n'est pas surveillée."
				}
			# .watch $variable in ....
			} elseif { $command eq "in" } {
				regsub {^::} $target "" target
				# la procédure in_proc n'existe pas
				if { [::tcl::info::procs $in_proc] eq "" } {
					if { [::tcl::info::commands $in_proc] ne "" } {
						set message "La procédure[set ::LiveBugTracer::highlight_color] [set in_proc]\003 n'existe pas;[set ::LiveBugTracer::highlight_color] [set raw_in_proc]\003 est une commande."
					} else {
						set message "La procédure[set ::LiveBugTracer::highlight_color] [set in_proc]\003 n'existe pas."
					}
				# la procédure in_proc existe
				} else {
					# .watch $variable in in_proc off
					if { $command2 eq "off" } {
						if { [lsearch -exact $::LiveBugTracer::latent_traces [list [list type var target $target tracetype read call ::LiveBugTracer::varinproc_read_watch_call] $in_proc]] > -1 } {
							if { [::tcl::info::procs [set in_proc]_LBT_bak] ne "" } {
								set ::LiveBugTracer::latent_traces [lreplace $::LiveBugTracer::latent_traces [set index [lsearch -exact -index 0 $::LiveBugTracer::latent_traces [list type var target $target tracetype read call ::LiveBugTracer::varinproc_read_watch_call]]] $index]
								set ::LiveBugTracer::latent_traces [lreplace $::LiveBugTracer::latent_traces [set index [lsearch -exact -index 0 $::LiveBugTracer::latent_traces [list type var target $target tracetype write call ::LiveBugTracer::varinproc_write_watch_call]]] $index]
								set ::LiveBugTracer::latent_traces [lreplace $::LiveBugTracer::latent_traces [set index [lsearch -exact -index 0 $::LiveBugTracer::latent_traces [list type var target $target tracetype unset call ::LiveBugTracer::varinproc_unset_watch_call]]] $index]
								uplevel #0 [list trace remove command $in_proc delete ::LiveBugTracer::stop_varinproc_watch_call]
								set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $in_proc tracetype delete call ::LiveBugTracer::stop_varinproc_watch_call]]] $index]
								uplevel #0 [list trace remove command $in_proc rename ::LiveBugTracer::transfer_varinproc_watch_call]
								set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $in_proc tracetype rename call ::LiveBugTracer::transfer_varinproc_watch_call]]] $index]
								rename $in_proc ""
								rename "[set in_proc]_LBT_bak" $in_proc
								set message "Surveillance désactivée sur la variable temporaire[set ::LiveBugTracer::highlight_color] [set raw_target]\003 dans la procédure[set ::LiveBugTracer::highlight_color] [set in_proc]\003."
								set log 1
							} else {
								set message "Erreur lors de la restauration de la procédure d'origine : la procédure [set in_proc]_LBT_bak n'a pas été trouvée."
							}
						} else {
							set message "La variable temporaire[set ::LiveBugTracer::highlight_color] [set target]\003 dans la procédure[set ::LiveBugTracer::highlight_color] [set in_proc]\003 n'est pas surveillée."
						}
					# .watch $variable in in_proc
					} else {
						# une surveillance de ce type est déjà en cours et on ne peut en avoir
						# deux à la fois.
						if { $::LiveBugTracer::latent_traces eq "" } {
							if { [::tcl::info::procs [set in_proc]_LBT_bak] eq "" } {
								set injected_code "
									trace add variable $target read ::LiveBugTracer::varinproc_read_watch_call
									trace add variable $target write ::LiveBugTracer::varinproc_write_watch_call
									# dans la ligne suivante, laisser le point virgule où il se trouve et ne surtout pas l'espacer
									trace add variable $target unset ::LiveBugTracer::varinproc_unset_watch_call;
								"
								set modified_proc_body [concat $injected_code [::tcl::info::body $in_proc] "; after 0 { return }"]
								# on crée une copie de sauvegarde de la proc originale avant de
								# la modifier afin de pouvoir la restaurer ensuite
								proc [set in_proc]_LBT_bak [::tcl::info::args $in_proc] [::tcl::info::body $in_proc]
								#	on reconstruit la proc avec le code injecté
								proc $in_proc [::tcl::info::args $in_proc] $modified_proc_body
								lappend ::LiveBugTracer::latent_traces [list [list type var target $target tracetype read call ::LiveBugTracer::varinproc_read_watch_call] $in_proc]
								lappend ::LiveBugTracer::latent_traces [list [list type var target $target tracetype write call ::LiveBugTracer::varinproc_write_watch_call] $in_proc]
								lappend ::LiveBugTracer::latent_traces [list [list type var target $target tracetype unset call ::LiveBugTracer::varinproc_unset_watch_call] $in_proc]
								# on met une surveillance sur la proc $in_proc pour être prévenu
								#	si elle est modifiée/supprimée/renommée
								uplevel #0 [list trace add command $in_proc delete ::LiveBugTracer::stop_varinproc_watch_call]
								lappend ::LiveBugTracer::running_traces [list type cmd target $in_proc tracetype delete call ::LiveBugTracer::stop_varinproc_watch_call]
								uplevel #0 [list trace add command $in_proc rename ::LiveBugTracer::transfer_varinproc_watch_call]
								lappend ::LiveBugTracer::running_traces [list type cmd target $in_proc tracetype rename call ::LiveBugTracer::transfer_varinproc_watch_call]
								set message "Surveillance activée sur la variable temporaire[set ::LiveBugTracer::highlight_color] [set raw_target]\003 dans la procédure[set ::LiveBugTracer::highlight_color] [set in_proc]\003."
								set log 1
							} else {
								set message "La variable temporaire[set ::LiveBugTracer::highlight_color] [set raw_target]\003 dans la procédure[set ::LiveBugTracer::highlight_color] [set in_proc]\003 est déjà surveillée."
							}
						} else {
							array set buffer_array [lindex $::LiveBugTracer::latent_traces 0 0]
							set watched_procname [lindex $::LiveBugTracer::latent_traces 0 1]
							set message "Une surveillance de ce type est déjà en cours sur la variable[set ::LiveBugTracer::highlight_color] \$[set buffer_array(target)]\003 dans la procédure[set ::LiveBugTracer::highlight_color] [set watched_procname]\003. Vous ne pouvez activer qu'une seule surveillance de ce type à la fois."
						}
					}
				}
			# .watch item
			} else {
				if { [lsearch -exact [uplevel #0 [list trace info variable $target]] "read ::LiveBugTracer::var_read_watch_call"] == -1 } {
					# on garde une copie de l'ancienne valeur des variables afin de pouvoir l'afficher
					if { [::tcl::info::exists $target] } {
						if { [array exists $target] } {
							set ::LiveBugTracer::shadow($target) [array get $target]
						} else {
							if { [set actual_value [set [set target]]] eq "" } { set actual_value "\"\"" }
							set ::LiveBugTracer::shadow($target) $actual_value
						}
					}
					uplevel #0 [list trace add variable $target read ::LiveBugTracer::var_read_watch_call]
					lappend ::LiveBugTracer::running_traces [list type var target $target tracetype read call ::LiveBugTracer::var_read_watch_call]
					uplevel #0 [list trace add variable $target write ::LiveBugTracer::var_write_watch_call]
					lappend ::LiveBugTracer::running_traces [list type var target $target tracetype write call ::LiveBugTracer::var_write_watch_call]
					uplevel #0 [list trace add variable $target unset ::LiveBugTracer::var_unset_watch_call]
					lappend ::LiveBugTracer::running_traces [list type var target $target tracetype unset call ::LiveBugTracer::var_unset_watch_call]
					set message "Surveillance activée sur la variable[set ::LiveBugTracer::highlight_color] [set raw_target]\003."
					set log 1
				} else {
					set message "La variable[set ::LiveBugTracer::highlight_color] [set raw_target]\003 est déjà surveillée."
				}
			}
		}
	# La cible est une commande
	} elseif {
		([::tcl::info::procs [if { [::tcl::string::first "::" $raw_target] } { set target "::[set raw_target]" } { set target $raw_target }]] eq "")
		&& ([::tcl::info::commands $target] ne "")
	} then {
		regsub {^::} $target "" target
		if { $command ne "off" } {
			if { [lsearch -exact [uplevel #0 [list trace info execution $target]] "enter ::LiveBugTracer::enter_cmd_watch_call"] == -1 } {
				uplevel #0 [list trace add execution $target enter ::LiveBugTracer::enter_cmd_watch_call]
				lappend ::LiveBugTracer::running_traces [list type exe target $target tracetype enter call ::LiveBugTracer::enter_cmd_watch_call]
				uplevel #0 [list trace add execution $target leave ::LiveBugTracer::leave_cmd_watch_call]
				lappend ::LiveBugTracer::running_traces [list type exe target $target tracetype leave call ::LiveBugTracer::leave_cmd_watch_call]
				uplevel #0 [list trace add command $target delete ::LiveBugTracer::delete_cmd_watch_call]
				lappend ::LiveBugTracer::running_traces [list type cmd target $target tracetype delete call ::LiveBugTracer::delete_cmd_watch_call]
				uplevel #0 [list trace add command $target rename ::LiveBugTracer::rename_cmd_watch_call]
				lappend ::LiveBugTracer::running_traces [list type cmd target $target tracetype rename call ::LiveBugTracer::rename_cmd_watch_call]
				set message "Surveillance activée sur la commande[set ::LiveBugTracer::highlight_color] [set raw_target]\003."
				set log 1
			} else {
				set message "La commande[set ::LiveBugTracer::highlight_color] [set raw_target]\003 est déjà surveillée."
			}
		} else {
			if { [lsearch -exact [uplevel #0 [list trace info execution $target]] "enter ::LiveBugTracer::enter_cmd_watch_call"] ne -1 } {
				uplevel #0 [list trace remove execution $target enter ::LiveBugTracer::enter_cmd_watch_call]
				set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $target tracetype enter call ::LiveBugTracer::enter_cmd_watch_call]]] $index]
				uplevel #0 [list trace remove execution $target leave ::LiveBugTracer::leave_cmd_watch_call]
				set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $target tracetype leave call ::LiveBugTracer::leave_cmd_watch_call]]] $index]
				uplevel #0 [list trace remove command $target delete ::LiveBugTracer::delete_cmd_watch_call]
				set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $target tracetype delete call ::LiveBugTracer::delete_cmd_watch_call]]] $index]
				uplevel #0 [list trace remove command $target rename ::LiveBugTracer::rename_cmd_watch_call]
				set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $target tracetype rename call ::LiveBugTracer::rename_cmd_watch_call]]] $index]
				set message "Surveillance désactivée sur la commande[set ::LiveBugTracer::highlight_color] [set raw_target]\003."
				set log 1
			} else {
				set message "La commande[set ::LiveBugTracer::highlight_color] [set raw_target]\003 n'est pas surveillée."
			}
		}
	# La cible est une procédure
	} else {
		if { [::tcl::info::procs $target] eq "" } {
			set message "La procédure[set ::LiveBugTracer::highlight_color] [set target]\003 n'existe pas."
		} elseif { $command ne "off" } {
				if { ([lsearch -exact [uplevel #0 [list trace info execution $target]] "enter ::LiveBugTracer::enter_proc_watch_call"] == -1)
					&& ([lsearch -exact [uplevel #0 [list trace info execution $target]] "enterstep ::LiveBugTracer::enterstep_trace_call"] == -1)
				} then {
				uplevel #0 [list trace add execution $target enter ::LiveBugTracer::enter_proc_watch_call]
				lappend ::LiveBugTracer::running_traces [list type exe target $target tracetype enter call ::LiveBugTracer::enter_proc_watch_call]
				uplevel #0 [list trace add execution $target leave ::LiveBugTracer::leave_proc_watch_call]
				lappend ::LiveBugTracer::running_traces [list type exe target $target tracetype leave call ::LiveBugTracer::leave_proc_watch_call]
				uplevel #0 [list trace add command $target delete ::LiveBugTracer::delete_proc_watch_call]
				lappend ::LiveBugTracer::running_traces [list type cmd target $target tracetype delete call ::LiveBugTracer::delete_proc_watch_call]
				uplevel #0 [list trace add command $target rename ::LiveBugTracer::rename_proc_watch_call]
				lappend ::LiveBugTracer::running_traces [list type cmd target $target tracetype rename call ::LiveBugTracer::rename_proc_watch_call]
				set message "Surveillance activée sur la procédure[set ::LiveBugTracer::highlight_color] [set target]\003."
				set log 1
			} else {
				if { [lsearch -exact [uplevel #0 [list trace info execution $target]] "enterstep ::LiveBugTracer::enterstep_trace_call"] != -1 } {
					set message "La procédure[set ::LiveBugTracer::highlight_color] [set target]\003 est déjà en cours de traçage. Vous devez d'abord taper \002[::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::trace_cmd] $target off\002 avant de pouvoir démarrer une surveillance simple."
				} else {
					set message "La procédure[set ::LiveBugTracer::highlight_color] [set target]\003 est déjà surveillée."
				}
			}
		} else {
			if { [lsearch -exact [uplevel #0 [list trace info execution $target]] "enter ::LiveBugTracer::enter_proc_watch_call"] ne -1 } {
				if { [lsearch -exact [uplevel #0 [list trace info execution $target]] "enterstep ::LiveBugTracer::enterstep_trace_call"] == -1 } {
					uplevel #0 [list trace remove execution $target enter ::LiveBugTracer::enter_proc_watch_call]
					set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $target tracetype enter call ::LiveBugTracer::enter_proc_watch_call]]] $index]
					uplevel #0 [list trace remove execution $target leave ::LiveBugTracer::leave_proc_watch_call]
					set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $target tracetype leave call ::LiveBugTracer::leave_proc_watch_call]]] $index]
					uplevel #0 [list trace remove command $target delete ::LiveBugTracer::delete_proc_watch_call]
					set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $target tracetype delete call ::LiveBugTracer::delete_proc_watch_call]]] $index]
					uplevel #0 [list trace remove command $target rename ::LiveBugTracer::rename_proc_watch_call]
					set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $target tracetype rename call ::LiveBugTracer::rename_proc_watch_call]]] $index]
					set message "Surveillance désactivée sur la procédure[set ::LiveBugTracer::highlight_color] [set target]\003."
					set log 1
				} else {
					set message "La procédure[set ::LiveBugTracer::highlight_color] [set target]\003 est en cours de traçage. Vous devez utiliser la commande \002[::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::trace_cmd] $target off\002 si vous voulez l'arrêter."
				}
			} else {
				set message "La procédure[set ::LiveBugTracer::highlight_color] [set target]\003 n'est pas surveillée."
			}
		}
	}
	::LiveBugTracer::output_message $chan $idx $log $message
	if { [::tcl::info::exists message2] } { ::LiveBugTracer::output_message $chan $idx $log $message2 }
}

 ###############################################################################
### Appelé lorsqu'une procédure dans laquelle on surveille une variable
### temporaire est modifiée ou supprimée.
 ###############################################################################
proc ::LiveBugTracer::stop_varinproc_watch_call {oldname newname operation} {
	set varname [lindex [lsearch -exact -inline -index 1 $::LiveBugTracer::latent_traces $oldname] 0 3]
	uplevel #0 [if { [::tcl::info::procs "[set oldname]_LBT_bak"] ne "" } { rename "[set oldname]_LBT_bak" "" }]
	set ::LiveBugTracer::latent_traces [lreplace $::LiveBugTracer::latent_traces [set index [lsearch -exact -index 0 $::LiveBugTracer::latent_traces [list type var target $varname tracetype read call ::LiveBugTracer::varinproc_read_watch_call]]] $index]
	set ::LiveBugTracer::latent_traces [lreplace $::LiveBugTracer::latent_traces [set index [lsearch -exact -index 0 $::LiveBugTracer::latent_traces [list type var target $varname tracetype write call ::LiveBugTracer::varinproc_write_watch_call]]] $index]
	set ::LiveBugTracer::latent_traces [lreplace $::LiveBugTracer::latent_traces [set index [lsearch -exact -index 0 $::LiveBugTracer::latent_traces [list type var target $varname tracetype unset call ::LiveBugTracer::varinproc_unset_watch_call]]] $index]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype delete call ::LiveBugTracer::stop_varinproc_watch_call]]] $index]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype rename call ::LiveBugTracer::transfer_varinproc_watch_call]]] $index]
	::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - "[set ::LiveBugTracer::default_prefix]La surveillance des variables temporaires de la procédure[set ::LiveBugTracer::highlight_color] [set oldname]\003 a été désactivée suite à sa modification ou à sa suppression."]
}	

 ###############################################################################
### Appelé lorsqu'une procédure dans laquelle on surveille une variable
### temporaire est renommée.
 ###############################################################################
proc ::LiveBugTracer::transfer_varinproc_watch_call {oldname newname operation} {
	set varname [lindex [lsearch -exact -inline -index 1 $::LiveBugTracer::latent_traces $oldname] 0 3]
	set ::LiveBugTracer::latent_traces [lreplace $::LiveBugTracer::latent_traces [set index [lsearch -exact -index 0 $::LiveBugTracer::latent_traces [list type var target $varname tracetype read call ::LiveBugTracer::varinproc_read_watch_call]]] $index [list [list type var target $varname tracetype read call ::LiveBugTracer::varinproc_read_watch_call] $newname]]
	set ::LiveBugTracer::latent_traces [lreplace $::LiveBugTracer::latent_traces [set index [lsearch -exact -index 0 $::LiveBugTracer::latent_traces [list type var target $varname tracetype write call ::LiveBugTracer::varinproc_write_watch_call]]] $index [list [list type var target $varname tracetype write call ::LiveBugTracer::varinproc_write_watch_call] $newname]]
	set ::LiveBugTracer::latent_traces [lreplace $::LiveBugTracer::latent_traces [set index [lsearch -exact -index 0 $::LiveBugTracer::latent_traces [list type var target $varname tracetype unset call ::LiveBugTracer::varinproc_unset_watch_call]]] $index [list [list type var target $varname tracetype unset call ::LiveBugTracer::varinproc_unset_watch_call] $newname]]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype delete call ::LiveBugTracer::stop_varinproc_watch_call]]] $index [list type cmd target $newname tracetype delete call ::LiveBugTracer::stop_varinproc_watch_call]]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype rename call ::LiveBugTracer::transfer_varinproc_watch_call]]] $index [list type cmd target $newname tracetype rename call ::LiveBugTracer::transfer_varinproc_watch_call]]
	::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - "[set ::LiveBugTracer::default_prefix]La procédure[set ::LiveBugTracer::highlight_color] [set oldname]\003 a été renommée en[set ::LiveBugTracer::highlight_color] [set newname]\003. Ses variables temporaires restent surveillées."]
}


 ###############################################################################
### Appelé lorsqu'une variable statique en cours de surveillance est lue.
 ###############################################################################
proc ::LiveBugTracer::var_read_watch_call {varname element operation} {
	set level [expr {[::tcl::info::level] - 1}]
	if { $level > 0 } {
		regsub -all {\n} [::tcl::info::level $level] " " invoked_from
	} else {
		set invoked_from "::"
	}
	if { [lindex [split $invoked_from] 0] eq "::LiveBugTracer::var_write_watch_call" } { return }
	# on complète le nom de la variable (namespace local ou namespace global ?)
	set varname [uplevel #[set level] [list namespace which -variable $varname]]
	if { $element eq "" } {
		if { [array exists $varname] } {
			set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_read_color]\[read \$[set varname]\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length [array get [set varname]]]"
		} else {
			if { [::tcl::info::exists $varname] } {
				set value [set [set varname]]
			} else {
				set value "\003N/A"
			}
			set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_read_color]\[read \$[set varname]\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $value]"
		}
	} else {
		set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_read_color]\[read \$[set varname]([set element])\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length [set [set varname]($element)]]"
	}
	foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - $line]
	}
}

 ###############################################################################
### Appelé lorsqu'une variable temporaire en cours de surveillance est lue.
 ###############################################################################
proc ::LiveBugTracer::varinproc_read_watch_call {varname element operation} {
	set get_var_value_code "uplevel 1 { set [set varname] }"
	set get_array_value_code "uplevel 1 { array get [set varname] }"
	set get_array_element_value_code "uplevel 1 { set [set varname]([set element]) }"
	set enquire_array_exists "uplevel 1 { array exists [set varname] }"
	set enquire_var_exists "uplevel 1 { ::tcl::info::exists [set varname] }"
	set level [expr {[::tcl::info::level] - 1}]
	regsub -all {\n} [::tcl::info::level $level] " " invoked_from
	if { [lindex [split $invoked_from] 0] eq "::LiveBugTracer::var_write_watch_call" } { return }
	if { $element eq "" } {
		if { [eval $enquire_array_exists] } {
			set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_read_color]\[read \$[set varname]\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length [eval $get_array_value_code]]"
		} else {
			if { [eval $enquire_var_exists] } {
				set value [eval $get_var_value_code]
			} else {
				set value "\003N/A"
			}
			set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_read_color]\[read \$[set varname]\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $value]"
		}
	} else {
		set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_read_color]\[read \$[set varname]([set element])\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length [eval $get_array_element_value_code]]"
	}
	foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - $line]
	}
}

 ###############################################################################
### Appelé lorsqu'une variable statique en cours de surveillance est modifiée.
 ###############################################################################
proc ::LiveBugTracer::var_write_watch_call {varname element operation} {
	set level [expr {[::tcl::info::level] - 1}]
	if { $level > 0 } {
		regsub -all {\n} [::tcl::info::level $level] " " invoked_from
	} else {
		set invoked_from "::"
	}
	# on complète le nom de la variable (namespace local ou namespace global ?)
	set varname [uplevel #[set level] [list namespace which -variable $varname]]
	if { [array exists $varname] } {
		if { [set actual_value [array get $varname]] eq "" } { set actual_value "\{\}" }
		if { [::tcl::info::exists ::LiveBugTracer::shadow($varname)] } {
			array set buffer_array [set ::LiveBugTracer::shadow($varname)]
		}
		if { ![::tcl::info::exists buffer_array($element)] } {
			set previous_value "\003N/A"
		} else {
			set previous_value [set buffer_array([set element])]
		}
		set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_write_color]\[write \$[set varname]([set element])\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $previous_value]\n[set ::LiveBugTracer::watch_var_out_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length [set [set varname]([set element])]]"
	} else {
		if { [set actual_value [set [set varname]]] eq "" } { set actual_value "\"\"" }
		if { ![::tcl::info::exists ::LiveBugTracer::shadow($varname)] } {
			set previous_value "\003N/A"
		} else {
			set previous_value [set ::LiveBugTracer::shadow($varname)]
		}
		set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_write_color]\[write \$[set varname]\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $previous_value]\n[set ::LiveBugTracer::watch_var_out_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $actual_value]"
	}
	foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - $line]
	}
	set ::LiveBugTracer::shadow($varname) $actual_value
}

 ###############################################################################
### Appelé lorsqu'une variable temporaire en cours de surveillance est modifiée.
 ###############################################################################
proc ::LiveBugTracer::varinproc_write_watch_call {varname element operation} {
	set get_var_value_code "uplevel 1 { set [set varname] }"
	set get_array_value_code "uplevel 1 { array get [set varname] }"
	set get_array_element_value_code "uplevel 1 { set [set varname]([set element]) }"
	set enquire_array_exists "uplevel 1 { array exists [set varname] }"
	set level [expr {[::tcl::info::level] - 1}]
	regsub -all {\n} [::tcl::info::level $level] " " invoked_from
	# la variable est un array
	if { [eval $enquire_array_exists] } {
		if { [set actual_value [eval $get_array_value_code]] eq "" } { set actual_value "\{\}" }
		if { [::tcl::info::exists ::LiveBugTracer::shadow($varname)] } {
			array set buffer_array [set ::LiveBugTracer::shadow($varname)]
		}
		if { ![::tcl::info::exists buffer_array($element)] } {
			set previous_value "\003N/A"
		} else {
			set previous_value [set buffer_array([set element])]
		}
		set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_write_color]\[write \$[set varname]([set element])\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $previous_value]\n[set ::LiveBugTracer::watch_var_out_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length [eval $get_array_element_value_code]]"
	# la variable est scalaire
	} else {
		if { [set actual_value [eval $get_var_value_code]] eq "" } { set actual_value "\"\"" }
		if { ![::tcl::info::exists ::LiveBugTracer::shadow($varname)] } {
			set previous_value "\003N/A"
		} else {
			set previous_value [set ::LiveBugTracer::shadow($varname)]
		}
		set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_write_color]\[write \$[set varname]\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $previous_value]\n[set ::LiveBugTracer::watch_var_out_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $actual_value]"
	}
	foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - $line]
	}
	set ::LiveBugTracer::shadow($varname) $actual_value
}

 ###############################################################################
### Appelé lorsqu'une variable statique en cours de surveillance est unset.
 ###############################################################################
proc ::LiveBugTracer::var_unset_watch_call {varname element operation} {
	set level [expr {[::tcl::info::level] - 1}]
	if { $level > 0 } {
		regsub -all {\n} [::tcl::info::level $level] " " invoked_from
	} else {
		set invoked_from "::"
	}
	# on complète le nom de la variable (namespace local ou namespace global ?)
	if { [set temp_varname [uplevel #[set level] [list namespace which -variable $varname]]] ne "" } {
		set varname $temp_varname
	}
	# la variable est scalaire ou de type array et a été unset
	if { $element eq "" } {
		set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type var target [set varname] tracetype read call ::LiveBugTracer::var_read_watch_call]]] $index]
		set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type var target [set varname] tracetype write call ::LiveBugTracer::var_write_watch_call]]] $index]
		set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type var target [set varname] tracetype unset call ::LiveBugTracer::var_unset_watch_call]]] $index]
		if { [::tcl::info::exists ::LiveBugTracer::shadow($varname)] } {
			set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_unset_color]\[unset \$[set varname]\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $::LiveBugTracer::shadow($varname)]\n[set ::LiveBugTracer::watch_var_out_prefix]"
			unset ::LiveBugTracer::shadow($varname)
		} else {
			set output ""
		}
		set trace_off 1
	# la variable est un élément d'array
	} else {
		if { [::tcl::info::exists ::LiveBugTracer::shadow($varname)] } {
			array set buffer_array [set ::LiveBugTracer::shadow($varname)]
			set previous_value $buffer_array($element)
			unset buffer_array($element)
			set ::LiveBugTracer::shadow($varname) [array get buffer_array]
			set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_unset_color]\[unset \$[set varname]([set element])\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $previous_value]\n[set ::LiveBugTracer::watch_var_out_prefix]"
		} else {
			set output ""
		}
		set trace_off 0
	}
	if { $output ne "" } {
		foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
			::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - $line]
		}
	}
	if { $trace_off } {
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - "[set ::LiveBugTracer::default_prefix]Surveillance désactivée sur la variable [set ::LiveBugTracer::highlight_color]\$[set varname]\003."]
	}
}

 ###############################################################################
### Appelé lorsqu'une variable temporaire en cours de surveillance est unset.
 ###############################################################################
proc ::LiveBugTracer::varinproc_unset_watch_call {varname element operation} {
	set level [expr {[::tcl::info::level] - 1}]
	if { $level > 0 } {
		regsub -all {\n} [::tcl::info::level $level] " " invoked_from
	} else {
		set invoked_from "::"
	}
	# on complète le nom de la variable (namespace local ou namespace global ?)
	if { [set temp_varname [uplevel #[set level] [list namespace which -variable $varname]]] ne "" } {
		set varname $temp_varname
	}
	# la variable est scalaire ou de type array et a été unset
	if { $element eq "" } {
		if { [::tcl::info::exists ::LiveBugTracer::shadow($varname)] } {
			set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_unset_color]\[unset \$[set varname]\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $::LiveBugTracer::shadow($varname)]\n[set ::LiveBugTracer::watch_var_out_prefix]"
			unset ::LiveBugTracer::shadow($varname)
		# si la variable n'a pas existé, on n'affiche rien.
		} else {
			return
		}
	# la variable est un élément d'array
	} else {
		if { [::tcl::info::exists ::LiveBugTracer::shadow($varname)] } {
			array set buffer_array [set ::LiveBugTracer::shadow($varname)]
			set previous_value $buffer_array($element)
			unset buffer_array($element)
			set ::LiveBugTracer::shadow($varname) [array get buffer_array]
			set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_var_unset_color]\[unset \$[set varname]([set element])\]\003 contexte :[set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $invoked_from]\n[set ::LiveBugTracer::watch_var_in_prefix][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $previous_value]\n[set ::LiveBugTracer::watch_var_out_prefix]"
		# si la variable n'a pas existé, on n'affiche rien.
		} else {
			return
		}
	}
	foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - $line]
	}
}

 ###############################################################################
### Appelé lorsqu'une commande en cours de surveillance est appelée
### (entrée)
 ###############################################################################
proc ::LiveBugTracer::enter_cmd_watch_call {command operation} {
	set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_cmd_call_color]\[enter [lindex $command 0]\][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length [regsub -all {\n} $command " "]]"
	foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - $line]
	}
}

 ###############################################################################
### Appelé lorsqu'une commande en cours de surveillance est appelée
### (sortie)
 ###############################################################################
proc ::LiveBugTracer::leave_cmd_watch_call {command errorcode result operation} {
	if { $errorcode ne "0" } {
		set errorcode "[set ::LiveBugTracer::wrong_errorcode_color]\002\002[set errorcode]\003"
	} else {
		set errorcode "[set ::LiveBugTracer::right_errorcode_color]\002\002[set errorcode]\003"
	}
	set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_cmd_return_color]\[leave [lindex $command 0]\]\003 \037code d'erreur\037 : [set errorcode]  [set ::LiveBugTracer::trace_separator_color]|\003  \037retour\037 : [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $result]"
	foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - $line]
	}
}

 ###############################################################################
### Appelé lorsqu'une commande en cours de surveillance est supprimée
 ###############################################################################
proc ::LiveBugTracer::delete_cmd_watch_call {oldname newname operation} {
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype enter call ::LiveBugTracer::enter_cmd_watch_call]]] $index]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype leave call ::LiveBugTracer::leave_cmd_watch_call]]] $index]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype delete call ::LiveBugTracer::delete_cmd_watch_call]]] $index]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype rename call ::LiveBugTracer::rename_cmd_watch_call]]] $index]
	::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - "[set ::LiveBugTracer::default_prefix]Surveillance désactivée sur la commande[set ::LiveBugTracer::highlight_color] [set oldname]\003 suite à sa suppression."]
}

 ###############################################################################
### Appelé lorsqu'une commande en cours de surveillance est renommée
 ###############################################################################
proc ::LiveBugTracer::rename_cmd_watch_call {oldname newname operation} {
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype enter call ::LiveBugTracer::enter_cmd_watch_call]]] $index [list type cmd target $newname tracetype enter call ::LiveBugTracer::enter_cmd_watch_call]]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype leave call ::LiveBugTracer::leave_cmd_watch_call]]] $index [list type cmd target $newname tracetype leave call ::LiveBugTracer::leave_cmd_watch_call]]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype delete call ::LiveBugTracer::delete_cmd_watch_call]]] $index [list type cmd target $newname tracetype delete call ::LiveBugTracer::delete_cmd_watch_call]]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype rename call ::LiveBugTracer::rename_cmd_watch_call]]] $index [list type cmd target $newname tracetype rename call ::LiveBugTracer::rename_cmd_watch_call]]
	::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - "[set ::LiveBugTracer::default_prefix]La commande[set ::LiveBugTracer::highlight_color] [set oldname]\003 a été renommée en[set ::LiveBugTracer::highlight_color] [set newname]\003 et reste surveillée. Notez que[set ::LiveBugTracer::highlight_color] [set oldname]\003 n'est maintenant plus surveillée."]
}

 ###############################################################################
### Appelé lorsqu'une procédure en cours de surveillance est appelée (entrée)
 ###############################################################################
proc ::LiveBugTracer::enter_proc_watch_call {command operation} {
	set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_proc_call_color]\[enter [lindex $command 0]\][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length [regsub -all {\n} $command " "]]"
	foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - $line]
	}
}

 ###############################################################################
### Appelé lorsqu'une procédure en cours de surveillance est appelée (sortie)
 ###############################################################################
proc ::LiveBugTracer::leave_proc_watch_call {command errorcode result operation} {
	if { $errorcode ne "0" } {
		set errorcode "[set ::LiveBugTracer::wrong_errorcode_color]\002\002[set errorcode]\003"
	} else {
		set errorcode "[set ::LiveBugTracer::right_errorcode_color]\002\002[set errorcode]\003"
	}
	set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::watch_proc_return_color]\[leave [lindex $command 0]\]\003 \037code d'erreur\037 : [set errorcode]  [set ::LiveBugTracer::trace_separator_color]|\003  \037retour\037 : [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $result]"
	foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - $line]
	}
}

 ###############################################################################
### Appelé lorsqu'une procédure en cours de surveillance est modifiée
### ou supprimée
 ###############################################################################
proc ::LiveBugTracer::delete_proc_watch_call {oldname newname operation} {
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $oldname tracetype enter call ::LiveBugTracer::enter_proc_watch_call]]] $index]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $oldname tracetype leave call ::LiveBugTracer::leave_proc_watch_call]]] $index]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype delete call ::LiveBugTracer::delete_proc_watch_call]]] $index]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype rename call ::LiveBugTracer::rename_proc_watch_call]]] $index]
	::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - "[set ::LiveBugTracer::default_prefix]Surveillance désactivée sur la procédure[set ::LiveBugTracer::highlight_color] [set oldname]\003 suite à sa modification ou à sa suppression."]
}

 ###############################################################################
### Appelé lorsqu'une procédure en cours de surveillance est renomée
 ###############################################################################
proc ::LiveBugTracer::rename_proc_watch_call {oldname newname operation} {
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $oldname tracetype enter call ::LiveBugTracer::enter_proc_watch_call]]] $index [list type exe target $newname tracetype enter call ::LiveBugTracer::enter_proc_watch_call]]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $oldname tracetype leave call ::LiveBugTracer::leave_proc_watch_call]]] $index [list type exe target $newname tracetype leave call ::LiveBugTracer::leave_proc_watch_call]]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype delete call ::LiveBugTracer::delete_proc_watch_call]]] $index [list type cmd target $newname tracetype delete call ::LiveBugTracer::delete_proc_watch_call]]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype rename call ::LiveBugTracer::rename_proc_watch_call]]] $index [list type cmd target $newname tracetype rename call ::LiveBugTracer::rename_proc_watch_call]]
	::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - "[set ::LiveBugTracer::default_prefix]La procédure[set ::LiveBugTracer::highlight_color] [set oldname]\003 a été renommée en[set ::LiveBugTracer::highlight_color] [set newname]\003 et reste surveillée. Notez que[set ::LiveBugTracer::highlight_color] [set oldname]\003 n'est maintenant plus surveillée."]
}

 ###############################################################################
### Traçage d'une procédure au moyen de .trace
 ###############################################################################
proc ::LiveBugTracer::pub_trace {nick host hand chan arg} {
	::LiveBugTracer::trace_proc $nick $host $hand $chan - $arg
}
proc ::LiveBugTracer::dcc_trace {hand idx arg} {
	::LiveBugTracer::trace_proc [set nick [hand2nick $hand]] [getchanhost $nick] $hand - $idx $arg
}
proc ::LiveBugTracer::trace_proc {nick host hand chan idx arg} {
	lassign $arg raw_target command
	set log 0
	if { $arg eq "" } {
		set message "\037Syntaxe\037 : [::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::trace_cmd] \00314<\003procédure\00314> \[\003off\00314]\003 \00307|\003 commence ou cesse le traçage d'une procédure."
	} else {
		if { ![::tcl::string::first "\$" $raw_target] } {
			set message "Vous ne pouvez pas tracer l'exécution d'une variable, utilisez plutôt la commande \002[::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::watch_cmd]\002"
		} else {
			if { [::tcl::string::first "::" $raw_target] } { set target "::[set raw_target]" } else { set target $raw_target }
			if { [::tcl::info::procs $target] eq "" } {
				if { [::tcl::info::commands $target] eq "" } {
					set message "La procédure[set ::LiveBugTracer::highlight_color] [set target]\003 n'existe pas."
				} else {
					set message "La procédure[set ::LiveBugTracer::highlight_color] [set target]\003 n'existe pas;[set ::LiveBugTracer::highlight_color] [set raw_target]\003 est une commande, vous ne pouvez donc pas tracer son exécution. Utilisez plutôt la commande \002[::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::watch_cmd]\002"
				}
			} elseif { $command ne "off" } {
				if { ([lsearch -exact [uplevel #0 [list trace info execution $target]] "enterstep ::LiveBugTracer::enterstep_trace_call"] == -1)
					&& ([lsearch -exact [uplevel #0 [list trace info execution $target]] "enter ::LiveBugTracer::enter_proc_watch_call"] == -1)
				} then {
					uplevel #0 [list trace add execution $target enter ::LiveBugTracer::enter_trace_call]
					lappend ::LiveBugTracer::running_traces [list type exe target $target tracetype enter call ::LiveBugTracer::enter_trace_call]
					uplevel #0 [list trace add execution $target leave ::LiveBugTracer::leave_trace_call]
					lappend ::LiveBugTracer::running_traces [list type exe target $target tracetype leave call ::LiveBugTracer::leave_trace_call]
					uplevel #0 [list trace add execution $target enterstep ::LiveBugTracer::enterstep_trace_call]
					lappend ::LiveBugTracer::running_traces [list type exe target $target tracetype enterstep call ::LiveBugTracer::enterstep_trace_call]
					uplevel #0 [list trace add command $target delete ::LiveBugTracer::delete_trace_call]
					lappend ::LiveBugTracer::running_traces [list type cmd target $target tracetype delete call ::LiveBugTracer::delete_trace_call]
					uplevel #0 [list trace add command $target rename ::LiveBugTracer::rename_trace_call]
					lappend ::LiveBugTracer::running_traces [list type cmd target $target tracetype rename call ::LiveBugTracer::rename_trace_call]
					set message "Traçage activé sur la procédure[set ::LiveBugTracer::highlight_color] [set target]\003."
					set log 1
				} else {
					if { [lsearch -exact [uplevel #0 [list trace info execution $target]] "enterstep ::LiveBugTracer::enterstep_trace_call"] != -1 } {
						set message "La procédure[set ::LiveBugTracer::highlight_color] [set target]\003 est déjà en cours de traçage."
					} else {
						set message "La procédure[set ::LiveBugTracer::highlight_color] [set target]\003 est déjà en cours de surveillance simple. Vous devez d'abord taper \002[::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::watch_cmd] $target off\002 avant de pouvoir en tracer l'exécution."
					}
				}
			} else {
				if { [lsearch -exact [uplevel #0 [list trace info execution $target]] "enterstep ::LiveBugTracer::enterstep_trace_call"] != -1 } {
					uplevel #0 [list trace remove execution $target enter ::LiveBugTracer::enter_trace_call]
					set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $target tracetype enter call ::LiveBugTracer::enter_trace_call]]] $index]
					uplevel #0 [list trace remove execution $target leave ::LiveBugTracer::leave_trace_call]
					set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $target tracetype leave call ::LiveBugTracer::leave_trace_call]]] $index]
					uplevel #0 [list trace remove execution $target enterstep ::LiveBugTracer::enterstep_trace_call]
					set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $target tracetype enterstep call ::LiveBugTracer::enterstep_trace_call]]] $index]
					uplevel #0 [list trace remove command $target delete ::LiveBugTracer::delete_trace_call]
					set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $target tracetype delete call ::LiveBugTracer::delete_trace_call]]] $index]
					uplevel #0 [list trace remove command $target rename ::LiveBugTracer::rename_trace_call]
					set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $target tracetype rename call ::LiveBugTracer::rename_trace_call]]] $index]
					set message "Traçage désactivé sur la procédure[set ::LiveBugTracer::highlight_color] [set target]\003."
					set log 1
				} else { 
					if { [lsearch -exact [uplevel #0 [list trace info execution $target]] "enter ::LiveBugTracer::enter_proc_watch_call"] != -1 } {
						set message "La procédure[set ::LiveBugTracer::highlight_color] [set target]\003 est en cours de surveillance simple. Vous devez d'abord utiliser \002[::LiveBugTracer::auto_command_prefix $chan][set ::LiveBugTracer::watch_cmd] $target off\002 pour l'arrêter avant de pouvoir tracer l'exécution de la procédure."
					} else {
						set message "Aucun traçage n'est en cours sur la procédure[set ::LiveBugTracer::highlight_color] [set target]\003."
					}
				}
			}
		}
	}
	::LiveBugTracer::output_message $chan $idx $log $message
}

 ###############################################################################
### Appelé lorsqu'une procédure en cours de traçage (.trace) est appelée
### (entrée)
 ###############################################################################
proc ::LiveBugTracer::enter_trace_call {command operation} {
	set ::LiveBugTracer::running_trace_history([md5 [set procname [lindex $command 0]]]) {}
	set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::trace_proc_call_color]\[enter [set procname]\][set ::LiveBugTracer::highlight_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length [regsub -all {\n} $command " "]]"
	foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - $line]
	}
}

 ###############################################################################
### Appelé lorsqu'une procédure en cours de traçage (.trace) est appelée
### (sortie)
 ###############################################################################
proc ::LiveBugTracer::leave_trace_call {command errorcode result operation} {
	set ::LiveBugTracer::running_trace_history([md5 [set procname [lindex $command 0]]]) {}
	if { $errorcode ne "0" } {
		set errorcode "[set ::LiveBugTracer::wrong_errorcode_color]\002\002[set errorcode]\003"
	} else {
		set errorcode "[set ::LiveBugTracer::right_errorcode_color]\002\002[set errorcode]\003"
	}
	set output "[set ::LiveBugTracer::callback_prefix][set ::LiveBugTracer::trace_proc_return_color]\[leave [set procname]\]\003 \037code d'erreur\037 : [set errorcode]  [set ::LiveBugTracer::trace_separator_color]|\003  \037retour\037 : [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $result]"
	foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
		::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - $line]
	}
}

 ###############################################################################
### Appelé lorsqu'une procédure en cours de traçage (.trace) est modifiée ou
### supprimée
 ###############################################################################
proc ::LiveBugTracer::delete_trace_call {oldname newname operation} {
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $oldname tracetype enter call ::LiveBugTracer::enter_trace_call]]] $index]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $oldname tracetype leave call ::LiveBugTracer::leave_trace_call]]] $index]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $oldname tracetype enterstep call ::LiveBugTracer::enterstep_trace_call]]] $index]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype delete call ::LiveBugTracer::delete_trace_call]]] $index]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype rename call ::LiveBugTracer::rename_trace_call]]] $index]
	::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - "[set ::LiveBugTracer::default_prefix]Traçage désactivé sur la procédure[set ::LiveBugTracer::highlight_color] [set oldname]\003 suite à sa modification ou à sa suppression."]
}

 ###############################################################################
### Appelé lorsqu'une procédure en cours de traçage (.trace) est renommée
 ###############################################################################
proc ::LiveBugTracer::rename_trace_call {oldname newname operation} {
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $oldname tracetype enter call ::LiveBugTracer::enter_trace_call]]] $index [list type exe target $newname tracetype enter call ::LiveBugTracer::enter_trace_call]]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $oldname tracetype leave call ::LiveBugTracer::leave_trace_call]]] $index [list type exe target $newname tracetype leave call ::LiveBugTracer::leave_trace_call]]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type exe target $oldname tracetype enterstep call ::LiveBugTracer::enterstep_trace_call]]] $index [list type exe target $newname tracetype enterstep call ::LiveBugTracer::enterstep_trace_call]]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype delete call ::LiveBugTracer::delete_trace_call]]] $index [list type cmd target $newname tracetype delete call ::LiveBugTracer::delete_trace_call]]
	set ::LiveBugTracer::running_traces [lreplace $::LiveBugTracer::running_traces [set index [lsearch -exact $::LiveBugTracer::running_traces [list type cmd target $oldname tracetype rename call ::LiveBugTracer::rename_trace_call]]] $index [list type cmd target $newname tracetype rename call ::LiveBugTracer::rename_trace_call]]
	::LiveBugTracer::sent_message [::LiveBugTracer::filter_styles - "[set ::LiveBugTracer::default_prefix]La procédure[set ::LiveBugTracer::highlight_color] [set oldname]\003 a été renommée en[set ::LiveBugTracer::highlight_color] [set newname]\003 et reste tracée. Notez que[set ::LiveBugTracer::highlight_color] [set oldname]\003 n'est maintenant plus tracée."]
}

 ###############################################################################
### Appelé pour chaque commande d'une procédure qui est tracée
### rec = profondeur de récursion
### lvl = niveau de pile
 ###############################################################################
proc ::LiveBugTracer::enterstep_trace_call {command operation} {
	array set frame [::tcl::info::frame [set frame_number [expr {[::tcl::info::frame] - 3}]]]
	if { ($frame(proc) eq "") || ([uplevel #0 [list trace info execution $frame(proc)]] eq "") } {
		return
	} elseif { !$::LiveBugTracer::trace_is_running } {
		set ::LiveBugTracer::trace_is_running 1
		after 0 ::LiveBugTracer::end_trace
	}
	if { $frame(type) eq "source" } {
		set script [lindex [split $frame(file) "/"] end]
	} else {
		set script ""
	}
	# On élimine les lignes de code inhérentes aux callbacks connus et aux trace
	# injectés, sans quoi ils apparaîtront dans le traçage.
	if { ([lindex [split [set code [regsub -all {\n} $frame(cmd) " "]]] 0] in $::LiveBugTracer::known_tracers)
		|| ([::tcl::string::match "trace add variable * read ::LiveBugTracer::varinproc_read_watch_call" $code])
		|| ([::tcl::string::match "trace add variable * write ::LiveBugTracer::varinproc_write_watch_call" $code])
		|| ([::tcl::string::match "trace add variable * unset ::LiveBugTracer::varinproc_unset_watch_call" $code])
	} then {
		return
	} else {
		set hash [md5 $frame(proc)]
		if { ![::tcl::info::exists ::LiveBugTracer::running_trace_history($hash)] } { set ::LiveBugTracer::running_trace_history($hash) {} }
		# si la ligne a déjà été affichée on l'ignore, sinon on l'affiche
		# (le fonctionnement de trace génère des doublons qu'on n'affiche pas
		# afin d'avoir une meilleure lisibilité)
		if { ([set index [lsearch -exact -index 0 $::LiveBugTracer::running_trace_history($hash) $code]] == -1)
			|| (($index != -1)
			&& ([lindex $::LiveBugTracer::running_trace_history($hash) $index 2] ne [list $script $frame(line)]))
		} then {
			if { $frame(type) eq "source" } {
				set output "\017rec:[set frame_number] [set ::LiveBugTracer::trace_separator_color]|\003 lvl:[::tcl::info::level] [set ::LiveBugTracer::trace_separator_color]|\003 [set script] ligne [set frame(line)] [set ::LiveBugTracer::trace_separator_color]|[set ::LiveBugTracer::trace_cmd_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $code]"
			} else {
				set output "\017rec:[set frame_number] [set ::LiveBugTracer::trace_separator_color]|\003 lvl:[::tcl::info::level] [set ::LiveBugTracer::trace_separator_color]|\003 type:[set frame(type)] [set ::LiveBugTracer::trace_separator_color]|[set ::LiveBugTracer::trace_cmd_color] [::LiveBugTracer::truncate_line $::LiveBugTracer::max_data_length $code]"
			}
			foreach line [::LiveBugTracer::split_line $::LiveBugTracer::max_line_length $output] {
				putlog [::LiveBugTracer::filter_styles - $line]
			}
			lappend ::LiveBugTracer::running_trace_history($hash) [list $code $frame_number [list $script $frame(line)]]
		}
	}
}

 ###############################################################################
### Réinitialisation des variables temporaires utiles au traçage des procédures
 ###############################################################################
proc ::LiveBugTracer::end_trace {} {
	set ::LiveBugTracer::trace_is_running 0
	array unset ::LiveBugTracer::running_trace_history
	putlog [::LiveBugTracer::filter_styles - $::LiveBugTracer::trace_end_symbol]
}

 ###############################################################################
### Affichage de tous les "trace" actifs
 ###############################################################################
proc ::LiveBugTracer::pub_show_traces {nick host hand chan arg} {
	::LiveBugTracer::show_traces $nick $host $hand $chan - $arg
}
proc ::LiveBugTracer::dcc_show_traces {hand idx arg} {
	::LiveBugTracer::show_traces [set nick [hand2nick $hand]] [getchanhost $nick] $hand - $idx $arg
}
proc ::LiveBugTracer::show_traces {nick host hand chan idx arg} {
	if { ($::LiveBugTracer::running_traces ne {}) || ($::LiveBugTracer::latent_traces ne {}) } {
		foreach single_trace_data $::LiveBugTracer::running_traces {
			array set single_trace $single_trace_data
			set message "\[[set single_trace(type)]\][set ::LiveBugTracer::highlight_color] [set single_trace(target)]\003 ([set single_trace(tracetype)])->[set ::LiveBugTracer::highlight_color] [set single_trace(call)]"
			::LiveBugTracer::output_message $chan $idx 0 $message
		}
		foreach single_trace_data $::LiveBugTracer::latent_traces {
			array set single_trace [lindex $single_trace_data 0]
			set message "\[[set single_trace(type)]\][set ::LiveBugTracer::highlight_color] [set single_trace(target)]\003 ([set single_trace(tracetype)])->[set ::LiveBugTracer::highlight_color] [set single_trace(call)]\003  (latent)"
			::LiveBugTracer::output_message $chan $idx 0 $message
		}
	} else {
		set message "Aucun point de traçage / surveillance n'a été trouvé."
		::LiveBugTracer::output_message $chan $idx 0 $message
	}
}

 ###############################################################################
### Nettoyage de tous les "trace" posés par Live Bug Tracer
 ###############################################################################
proc ::LiveBugTracer::pub_clean_all_traces {nick host hand chan arg} {
	::LiveBugTracer::clean_all_traces $nick $host $hand $chan - -
}
proc ::LiveBugTracer::dcc_clean_all_traces {hand idx arg} {
	::LiveBugTracer::clean_all_traces [set nick [hand2nick $hand]] [getchanhost $nick] $hand - $idx -
}
proc ::LiveBugTracer::clean_all_traces {nick host hand chan idx arg} {
	set counter 0
	foreach single_trace_data $::LiveBugTracer::running_traces {
		array set single_trace $single_trace_data
		if { [lsearch $::LiveBugTracer::removable_tracers $single_trace(call)] != -1 } {
			incr counter 1
			if { $single_trace(type) eq "exe" } {
				uplevel #0 [list trace remove execution $single_trace(target) $single_trace(tracetype) $single_trace(call)]
			} elseif { $single_trace(type) eq "cmd" } {
				uplevel #0 [list trace remove command $single_trace(target) $single_trace(tracetype) $single_trace(call)]
			} elseif { $single_trace(type) eq "var" } {
				uplevel #0 [list trace remove variable $single_trace(target) $single_trace(tracetype) $single_trace(call)]
			}
		}
	}
	set ::LiveBugTracer::running_traces {}
	if { $::LiveBugTracer::latent_traces ne "" } {
		set watched_procname [lindex $::LiveBugTracer::latent_traces 0 1]
		uplevel #0 [if { [::tcl::info::procs "[set watched_procname]_LBT_bak"] ne "" } { rename $watched_procname "" ; rename "[set watched_procname]_LBT_bak" $watched_procname }]
		# la surveillance d'une variable temporaire dans une proc crée 3 trace
		# latents. On incrémente donc le compteur de trace enlevés de 3.
		incr counter 3
	}
	set ::LiveBugTracer::latent_traces {}
	if { $arg ne "uninstall" } {
		if { !$counter } {
			set message "Aucun point de traçage / surveillance n'a été trouvé."
			set log 0
		} else {
			set message "[set counter] points de traçage / surveillance ont été arrêtés."
			set log 1
		}
		::LiveBugTracer::output_message $chan $idx $log $message
	}
}

 ###############################################################################
### Affichage des messages
 ###############################################################################
proc ::LiveBugTracer::output_message {chan idx log message} {
	if { $message eq "" } {
		return
	} else {
		set output [::LiveBugTracer::filter_styles $chan "[set ::LiveBugTracer::default_prefix][set message]"]
		if { $chan ne "-" } {
			putquick "PRIVMSG $chan :[set output]"
			if { $log } {
				::LiveBugTracer::sent_message $output
			}
		} elseif { $log } {
			::LiveBugTracer::sent_message $output
		} else {
			putdcc $idx $output
		}
	}
}

 ###############################################################################
### Filtrage des codes de couleur/gras/soulignement si le mode +c est détecté
### sur le chan, ou si le mode monochrome est activé manuellement
 ###############################################################################
proc ::LiveBugTracer::filter_styles {chan data} {
	if { ($::LiveBugTracer::no_visual_styles) || (($chan ne "-") && ([::tcl::string::match *c* [lindex [split [getchanmode $chan]] 0]])) } {
		return [regsub -all "\017" [stripcodes abcgru $data] ""]
	} else {
		return $data
	}
}

 ###############################################################################
### Découpage d'un texte trop long en plusieurs fragments.
### Le découpage peut intervenir au milieu d'un mot et les \n sont compris comme
### une fin de fragment.
### La limite ne doit pas être inférieure à 2.
 ###############################################################################
proc ::LiveBugTracer::split_line {limit text} {
	incr limit -1
	set output_length [::tcl::string::length $text]
	set text_color ""
	set letter_index 0
	while {$letter_index < $output_length} {
		if { ([set CRLF_index [::tcl::string::first "\n" $text $letter_index]] <= [set range_end [expr {$letter_index + $limit}]]) && ($CRLF_index > -1) } {
			set cut_index $CRLF_index
		} elseif {$output_length - $letter_index > $limit} {
			set CRLF_index -1
			set cut_index $range_end
 		} else {
			set CRLF_index -1
			set cut_index $output_length
		}
		# la condition suivante prévoit le cas où la limite tombe sur un \n 
		if { $letter_index != $cut_index } {
			if { $CRLF_index == -1 } {
				lappend output "[set text_color]\002\002[::tcl::string::range $text $letter_index $cut_index]"
				set text_color "[set ::LiveBugTracer::highlight_color]"
			} else {
				lappend output "[set text_color]\002\002[::tcl::string::range $text $letter_index [expr {$cut_index - 1}]]"
				set text_color ""
			}
		} else { set text_color "" }
		set letter_index [expr {$cut_index + 1}]
	}
	return $output
}

 ###############################################################################
### Tronque une ligne de texte à la longueur spécifiée et insère (...) à la fin
 ###############################################################################
proc ::LiveBugTracer::truncate_line {limit text} {
	incr limit -1
	if { [::tcl::string::length $text] > $limit } {
		set text [::tcl::string::replace [::tcl::string::range $text 0 $limit] end-[expr {[::tcl::string::length $::LiveBugTracer::truncate_symbol] - 1}] end $::LiveBugTracer::truncate_symbol]
	}
	return $text
}

 ###############################################################################
### Retourne le préfixe de commande adéquat selon qu'il s'agit d'une commande
### de partyline ou d'une commande publique
 ###############################################################################
proc ::LiveBugTracer::auto_command_prefix {chan} {
	if { $chan eq "-" } {
		return "."
	} else {
		return $::LiveBugTracer::pub_command_prefix
	}
}

 ###############################################################################
### Retourne une liste de tous les namespaces et sous-namespaces, à partir du
### namespace de départ specifié ($current_namespace) qui sera lui aussi inclus.
### $counter doit valoir 0 lors de l'appel initial.
 ###############################################################################
proc ::LiveBugTracer::list_namespaces {counter current_namespace} {
	if { !$counter } {
		incr counter
		lappend ::LiveBugTracer::namespace_list $current_namespace
	}
	if {[set children [namespace children $current_namespace]] ne ""} {
		lappend ::LiveBugTracer::namespace_list {*}$children
	}
	set current_namespace [lindex $::LiveBugTracer::namespace_list $counter]
	incr counter 1
	::LiveBugTracer::list_namespaces_callback $counter $current_namespace
}
proc ::LiveBugTracer::list_namespaces_callback {counter current_namespace} {
	if { $counter + 1 <= [llength $::LiveBugTracer::namespace_list] } {
		::LiveBugTracer::list_namespaces $counter $current_namespace
	} else {
		set output $::LiveBugTracer::namespace_list
		unset ::LiveBugTracer::namespace_list
		return $output
	}
}
proc ::LiveBugTracer::sent_message { message } {
	putloglev o * ${message}
	if { ${::LiveBugTracer::destination_status} != "" } { puthelp "PRIVMSG ${::LiveBugTracer::channel_destination} :${message}"; }
}

 ###############################################################################
### Post-initialisation
 ###############################################################################
uplevel #0 [list trace add execution catch leave ::LiveBugTracer::catch_callback]
uplevel #0 [list trace add variable ::errorInfo write ::LiveBugTracer::errorInfo_callback]

 ###############################################################################
### Binds
 ###############################################################################
bind PUB $::LiveBugTracer::debugging_auth [set ::LiveBugTracer::pub_command_prefix][set ::LiveBugTracer::watch_cmd] ::LiveBugTracer::pub_watch
bind DCC $::LiveBugTracer::debugging_auth $::LiveBugTracer::watch_cmd ::LiveBugTracer::dcc_watch
bind PUB $::LiveBugTracer::debugging_auth [set ::LiveBugTracer::pub_command_prefix][set ::LiveBugTracer::trace_cmd] ::LiveBugTracer::pub_trace
bind DCC $::LiveBugTracer::debugging_auth $::LiveBugTracer::trace_cmd ::LiveBugTracer::dcc_trace
bind PUB $::LiveBugTracer::debugging_auth [set ::LiveBugTracer::pub_command_prefix][set ::LiveBugTracer::list_traces_cmd] ::LiveBugTracer::pub_show_traces
bind DCC $::LiveBugTracer::debugging_auth $::LiveBugTracer::list_traces_cmd ::LiveBugTracer::dcc_show_traces
bind PUB $::LiveBugTracer::debugging_auth [set ::LiveBugTracer::pub_command_prefix][set ::LiveBugTracer::clean_traces_cmd] ::LiveBugTracer::pub_clean_all_traces
bind DCC $::LiveBugTracer::debugging_auth $::LiveBugTracer::clean_traces_cmd ::LiveBugTracer::dcc_clean_all_traces
bind PUB $::LiveBugTracer::debugging_auth [set ::LiveBugTracer::pub_command_prefix][set ::LiveBugTracer::autobacktrace_cmd] ::LiveBugTracer::pub_activate_deactivate
bind DCC $::LiveBugTracer::debugging_auth $::LiveBugTracer::autobacktrace_cmd ::LiveBugTracer::dcc_activate_deactivate
bind PUB $::LiveBugTracer::debugging_auth [set ::LiveBugTracer::pub_command_prefix][set ::LiveBugTracer::anti_infiniteloop_cmd] ::LiveBugTracer::pub_loopfuse
bind DCC $::LiveBugTracer::debugging_auth $::LiveBugTracer::destination_cmd ::LiveBugTracer::dcc_destination
bind PUB $::LiveBugTracer::debugging_auth [set ::LiveBugTracer::pub_command_prefix][set ::LiveBugTracer::destination_cmd] ::LiveBugTracer::pub_destination
bind DCC $::LiveBugTracer::debugging_auth $::LiveBugTracer::destination_cmd ::LiveBugTracer::dcc_destination
bind EVNT - prerehash ::LiveBugTracer::uninstall
if { $::LiveBugTracer::default_anti_infiniteloop_status } {
	::LiveBugTracer::loopfuse - - 1
	::LiveBugTracer::sent_message "\[$::LiveBugTracer::scriptname\] La protection anti-boucle infinie est activée"
}	


putlog "$::LiveBugTracer::scriptname v$::LiveBugTracer::version (©2012 MenzAgitat) a été chargé."
