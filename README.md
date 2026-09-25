# Brainwager — « Bet on what you know / Parie sur ce que tu sais »

Party trivia game multijoueur festif. 100 % original (nom, design, logo, textes, questions).
Aucun asset / wording copié d'un jeu existant.

**Package :** `com.yakineeddine.brainwager` (⚠️ tout en minuscules — `com.YAKINEEDDINE...`
avec majuscules est invalide comme `applicationId` Android / Play Store. On garde
« YAKINEEDDINE » uniquement comme nom de compte développeur si tu veux.)

**Stack :** Flutter (Android en priorité) · Supabase (Auth anonyme, Postgres, Realtime,
RLS, RPC security definer) · Riverpod · AdMob + Play Billing · Sentry optionnel.
AUCUN Firebase.

**Langues :** FR + EN dès le départ (gen-l10n officiel).

## Docs Phase 0

- `docs/01-architecture.md` — décisions techniques + structure dossiers
- `docs/02-supabase-model.md` — modèle de données, RLS, RPC, Realtime, timer serveur, anti-triche
- `docs/03-ecrans-navigation.md` — liste écrans, navigation, design system Brainwager
- `docs/04-game-config-et-taches.md` — règles configurables + plan de tâches Phase 1→6

## Rappel règles (source de vérité)

1. Partie = 11 questions (configurable). Q1–Q10 : réponse tapée + mise 1–10, chaque valeur
   utilisable **une seule fois** par joueur et par partie. Bonne réponse = +mise, sinon 0.
2. Q11 finale : mise 0 / 10 / 20. Bonne = +mise, mauvaise = −mise.
3. Timer 30 s défaut, verrouillage auto. Révélation → classement animé.
4. Correction auto tolérante (normalisation + Levenshtein + alias) + correction manuelle hôte
   avec recalcul live.
5. Individuel ou équipes. Hôte peut jouer. Mode écran TV pour l'hôte.

## Statut

Phase 0 terminée (plan). En attente de « continue » pour Phase 1.
Ne pas coder avant validation du plan.
