# Le Grand Partage

Site de partage et de dons d'objets.

## Déploiement
Le workflow GitHub Actions publie automatiquement le contenu du dépôt sur GitHub Pages à chaque mise à jour de `main`.

URL attendue : https://lpcdjn-hub.github.io/le-grand-partage/

## Connexion Supabase
Le front-end utilise le client JavaScript Supabase depuis un CDN et le projet Supabase configuré dans `index.html`. La clé intégrée est une clé publique publishable ; les permissions sont contrôlées par les politiques RLS définies dans `supabase/schema.sql`.

Fonctions déjà raccordées dans le front-end :
- inscription et connexion par e-mail / mot de passe ;
- affichage des annonces disponibles depuis la base partagée ;
- publication d'annonces par les membres connectés ;
- téléversement facultatif de photos dans le bucket `listing-photos`.

Si la confirmation d'adresse e-mail est activée dans Supabase Auth, les nouveaux membres doivent confirmer leur adresse avant de pouvoir se connecter.

## Limites à ce stade
- Les messages privés, la gestion complète du profil, la modification/suppression des annonces et les signalements ne sont pas encore intégrés à l'interface.
- Les fonctions doivent encore être testées en conditions réelles avec deux comptes.
- La PWA et le déploiement GitHub Pages doivent être vérifiés après publication.
