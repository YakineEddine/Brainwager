# Brainwager — Agent Instructions

Concise, mandatory project rules. The docs in `docs/01`–`docs/04` are the
gameplay source of truth; do not rewrite architecture blindly.

* Stack: Flutter + Riverpod + go_router + Supabase. No Firebase, ever.
* `docs/01` through `docs/04` define the intended architecture/gameplay.
* `features/game_engine` must stay pure Dart: never import Flutter or Supabase.
* Supabase/server is authoritative for game state, timing and scoring.
* Never expose `question_answers_private` or future `game_questions` to clients.
* Never put service-role keys or secrets in Flutter or Git.
* Every behavioral change requires appropriate tests.
* Always run `flutter analyze` and `flutter test` before declaring a task done.
* Do not claim tests passed unless the commands were actually run successfully.
* Keep changes focused; do not start a later project phase during another task.
* Treat existing migrations as potentially already applied. Do not edit
  historical migrations just to change a deployed database.
* For a new Supabase migration, inspect the installed Supabase CLI with
  `--help` first and create the migration using the CLI, never invent a
  migration filename.
* Do not merge or push directly to `main` without explicit instruction.
