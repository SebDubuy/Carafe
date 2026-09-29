# Glouglou — App macOS de suivi d'hydratation

## Présentation du projet

Glouglou est une petite app macOS qui vit dans la barre de menus et aide à boire assez d'eau dans la journée. On ajoute ses verres en un clic, l'icône (une goutte) se remplit au fil de la journée, et l'app envoie des rappels quand ça fait longtemps qu'on n'a rien bu ou qu'on est en retard sur son rythme.

Ton de l'app : léger, un peu espiègle, jamais culpabilisant. Interface entièrement en français.

## Stack technique

- Swift + SwiftUI, macOS 13 minimum.
- `MenuBarExtra` avec le style `.window`.
- App uniquement dans la barre de menus : pas d'icône dans le Dock (`LSUIElement = YES`).
- Stockage local avec `UserDefaults` (ou SwiftData si c'est plus propre pour l'historique). Aucun serveur, aucune donnée envoyée.
- Notifications avec le framework `UserNotifications`.
- Lancement au démarrage via `SMAppService`.

## Architecture attendue

Code propre et découpé en responsabilités claires :

- **Modèle de données** : entrées (quantité en ml + horodatage), objectif, tailles de verre, historique.
- **Logique des rappels** : planification, conditions, gestion veille/verrouillage.
- **Dessin de l'icône** : goutte dessinée en code selon le pourcentage.
- **Vue du menu** : progression, boutons d'ajout, historique.
- **Vue des réglages**.

## Fonctionnalités

### Icône dans la barre de menus

- Une goutte d'eau dessinée en code qui se remplit selon le pourcentage de l'objectif (au moins 8 niveaux : vide → pleine). (Au départ un verre ; remplacé par la goutte pour l'uniformité.)
- Eau en bleu ; l'image n'est donc pas en mode « template » : le contour est coloré selon l'apparence de la barre (foncé sur barre claire, blanc sur barre sombre).
- À côté de l'icône, texte optionnel : « 1,2 / 2 L » ou « 60 % » (choix dans les réglages, ou icône seule).
- Si ça fait longtemps que rien n'a été bu (même délai que le rappel d'inactivité), l'icône passe en état « alerte » (petite goutte ou teinte orange) : rappel discret sans notification.

### Menu (au clic sur l'icône)

- Progression du jour : jauge + « X,X L sur Y L ».
- Gros boutons d'ajout rapide, un par taille de verre configurée (par défaut : 15 cl, 25 cl, 33 cl, 50 cl).
- Bouton « Annuler le dernier ajout ».
- Heure du dernier verre (« Dernier verre il y a 45 min »).
- Mini historique des 7 derniers jours (petites barres), avec indication des jours où l'objectif a été atteint.
- Petit son « glouglou » discret à chaque verre ajouté (désactivable).
- Petite animation d'éclaboussure quand l'objectif du jour est atteint.
- **Quantité libre** : petit champ pour ajouter une quantité ponctuelle (ex. 40 cl) sans créer de verre.
- **Liste des verres du jour** : voir les verres bus aujourd'hui et pouvoir supprimer un verre précis.
- **Série de jours** : « 🔥 5 jours d'affilée » quand l'objectif est atteint plusieurs jours de suite.
- Accès aux réglages + bouton Quitter.

### Réglages

- **Objectif quotidien** :
  - fixe (défaut 2 L, réglable par pas de 0,25 L),
  - ou calculé depuis le poids : poids en kg × 33 ml, arrondi à 0,1 L.
- **Tailles de verre** : liste modifiable (ajouter / supprimer / renommer, ex. « Ma gourde – 75 cl »), avec un verre par défaut.
- **Affichage dans la barre** : icône seule / icône + litres / icône + pourcentage.
- **Son** : activé / désactivé.
- **Rappels** (voir section dédiée).
- **Lancer au démarrage**.

### Remise à zéro quotidienne

- Remise à zéro automatique chaque jour à minuit (heure locale). L'historique est conservé.
- Gérer correctement le changement de jour si le Mac est resté allumé, en veille ou éteint pendant minuit (vérifier aussi au réveil et au lancement).

## Rappels (point important)

Demander l'autorisation de notifications au premier lancement.

Deux types de rappels, activables séparément :

1. **Rappel d'inactivité** : si aucun verre n'a été ajouté depuis un certain délai (réglable : 45 min, 1 h, 1 h 30, 2 h ; défaut 1 h 30), envoyer une notification. Le compte à rebours repart à chaque verre ajouté.
2. **Rappel de rythme** : l'objectif est réparti linéairement sur la plage horaire active. Si le retard dépasse 20 % du rythme attendu, envoyer une notification du type « Tu es un peu en retard : 0,8 L bu, 1,2 L attendus à cette heure ». Maximum un rappel de ce type par heure.

Règles communes :

- Plage horaire active réglable (défaut 9 h – 19 h) : aucun rappel en dehors.
- Plus aucun rappel une fois l'objectif du jour atteint.
- Pas de rappel quand l'écran est verrouillé ou le Mac en veille (écouter `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` et les notifications de veille/réveil de `NSWorkspace`). Au retour : au maximum une seule notification, et seulement si elle est toujours pertinente.
- Ne jamais empiler les notifications : réutiliser le même identifiant pour remplacer la précédente.
- Actions directement dans la notification : « + 25 cl » (ou la taille du verre par défaut) et « Rappeler dans 15 min ». Un ajout depuis la notification met à jour l'icône immédiatement.
- Textes variés tirés au hasard, dans l'esprit de l'app, par exemple : « Glouglou ? Ça fait un moment… », « Ton verre s'ennuie », « Une petite gorgée ? ». Jamais culpabilisants.

## Mode debug

Prévoir un mode debug caché (par exemple Option + clic sur « Réglages », ou un argument de lancement) qui :

- ramène tous les délais de rappel à 1 minute,
- permet de simuler un changement de jour,
- affiche l'état interne des rappels (prochain rappel prévu, raison).

Hors périmètre (écarté) : types de boisson (on reste sur l'eau), raccourci clavier global, export CSV, statistiques (moyenne, record, heure de pointe : jugées superflues).

## Conventions

- Formats français : virgule décimale, « L » pour les totaux ; contenance des verres en « cl » (défaut) ou « ml », au choix dans les réglages.
- Tous les textes de l'interface en français, centralisés pour faciliter une future traduction (String Catalog).
- Commentaires dans le code en français.
- Pas de dépendances externes sauf nécessité réelle.

## Méthode de travail

1. Avant de coder, proposer un plan court (structure des fichiers + étapes) et attendre ma validation.
2. Construire étape par étape, en commençant par une version minimale qui marche :
   1. icône + ajout de verre + objectif fixe,
   2. réglages (objectif, tailles de verre, affichage) + quantité libre,
   3. remise à zéro quotidienne + historique + liste des verres du jour + série de jours,
   4. rappels + actions dans les notifications,
   5. son, animation et finitions.
3. À chaque étape, expliquer comment tester.
4. Si un choix technique a plusieurs options valables, me demander plutôt que trancher seul.
