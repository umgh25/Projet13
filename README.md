# PoC - Your Car Your Way

Ce proof of concept a pour objectif de valider la mise en place d’un chat en temps réel entre deux utilisateurs.

Pour simplifier les tests, deux utilisateurs sont déjà définis dans l’application. L’utilisateur peut sélectionner un profil, se connecter, puis échanger des messages dans un salon de chat en direct.

Le projet utilise WebSocket avec STOMP afin de permettre des échanges instantanés entre le frontend et le backend.

⚠️ Ce projet est un PoC technique : aucune sécurité avancée (authentification forte, chiffrement, gestion complète des sessions) n’est implémentée.

## Technologies et prérequis

### Technologies utilisées

- Backend : Spring Boot 3.5, Java 17, WebSocket/STOMP
- Frontend : Angular 21, TypeScript, RxJS, SockJS et `@stomp/stompjs`
- Build : Maven Wrapper pour le backend et npm pour le frontend

### Prérequis

- Java 17 ou supérieur
- Node.js compatible avec Angular 21
- npm
- Un navigateur web moderne

## Base de données

Un fichier `init_db.sql` est disponible dans :

`backend/src/main/resources/init_db.sql`

Il permet de créer les tables de la base de données décrites dans le document **Architecture Definition**.