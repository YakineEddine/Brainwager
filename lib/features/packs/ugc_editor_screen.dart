// Éditeur UGC Phase 3C : création (/packs/edit) + édition (/packs/edit/:id).
// Uniquement les RPC 0011 (create_ugc_pack / update_ugc_pack /
// get_ugc_pack_for_edit). Aucune écriture/lecture directe de tables.
// Pas d'import, pas de deep link : tickets suivants.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/game_errors.dart';
import '../../l10n/app_localizations.dart';
import 'pack_providers.dart';
import 'ugc_draft.dart';
import 'ugc_repository.dart';

/// Route d'édition pour un pack existant (l'URL devient l'autorité :
/// refresh rouvre l'éditeur, jamais un formulaire création vierge).
String editRouteFor(String packId) => '/packs/edit/$packId';

/// Identité d'édition effective : id de route, sinon id tout juste créé.
/// Le second save après création utilise UPDATE vers cet id (jamais re-CREATE).
String? resolveEditTarget({String? packId, String? createdId}) =>
    createdId ?? packId;

/// Vrai dès qu'une identité pack existe (édition en cours ou création
/// réussie) : le save part en UPDATE.
bool shouldUpdate({String? packId, String? createdId}) =>
    resolveEditTarget(packId: packId, createdId: createdId) != null;

/// Gel des mutations pendant la sauvegarde (pur, testé) : champs, listes,
/// dropdowns, cases et boutons de mutation suivent tous `enabled = !saving`.
/// Le défilement reste libre ; aucune valeur ne peut changer, donc le draft
/// affiché au succès est exactement le draft soumis.
bool mutationEnabled({required bool saving}) => !saving;

/// Indicateur "Enregistré" (pur) : toute édition locale le fait tomber,
/// pour chaque champ/liste (titre, descriptions, questions, réponses,
/// alias, catégorie, difficulté, match mode, ajout/retrait/déplacement).
class EditorSavedFlag {
  bool saved = false;

  void markSaved() => saved = true;

  void markDirty() => saved = false;
}

/// Contrôleurs d'une question du formulaire (11..100).
class _QuestionForm {
  final TextEditingController promptFr = TextEditingController();
  final TextEditingController promptEn = TextEditingController();
  final TextEditingController answerFr = TextEditingController();
  final TextEditingController answerEn = TextEditingController();
  final TextEditingController aliasesFr = TextEditingController();
  final TextEditingController aliasesEn = TextEditingController();
  final TextEditingController category = TextEditingController();
  int difficulty = 1;
  String matchMode = 'fuzzy';

  _QuestionForm();

  factory _QuestionForm.fromDraft(UgcQuestionDraft d) {
    final f = _QuestionForm();
    f.promptFr.text = d.promptFr;
    f.promptEn.text = d.promptEn;
    f.answerFr.text = d.answerMainFr;
    f.answerEn.text = d.answerMainEn;
    f.aliasesFr.text = aliasesToLines(d.aliasesFr);
    f.aliasesEn.text = aliasesToLines(d.aliasesEn);
    f.category.text = d.category;
    f.difficulty = d.difficulty;
    f.matchMode = d.matchMode;
    return f;
  }

  UgcQuestionDraft toDraft() {
    return UgcQuestionDraft(
      promptFr: promptFr.text,
      promptEn: promptEn.text,
      answerMainFr: answerFr.text,
      answerMainEn: answerEn.text,
      aliasesFr: parseAliasesLines(aliasesFr.text),
      aliasesEn: parseAliasesLines(aliasesEn.text),
      category:
          category.text.trim().isEmpty ? 'general' : category.text.trim(),
      difficulty: difficulty,
      matchMode: matchMode,
    );
  }

  void dispose() {
    promptFr.dispose();
    promptEn.dispose();
    answerFr.dispose();
    answerEn.dispose();
    aliasesFr.dispose();
    aliasesEn.dispose();
    category.dispose();
  }
}

class UgcEditorScreen extends ConsumerStatefulWidget {
  /// null = création, sinon édition du pack possédé.
  final String? packId;
  const UgcEditorScreen({super.key, this.packId});

  @override
  ConsumerState<UgcEditorScreen> createState() => _UgcEditorScreenState();
}

class _UgcEditorScreenState extends ConsumerState<UgcEditorScreen> {
  final _titleFr = TextEditingController();
  final _titleEn = TextEditingController();
  final _descFr = TextEditingController();
  final _descEn = TextEditingController();
  List<_QuestionForm> _forms =
      List.generate(11, (_) => _QuestionForm());
  bool _termsAccepted = false;
  bool _loading = false;
  bool _saving = false;
  final _savedFlag = EditorSavedFlag();
  bool get _saved => _savedFlag.saved;
  String? _createdId;
  String? _loadError;
  String? _saveError;
  List<String> _validationErrors = [];
  String? _shareCode;

  bool get _isCreate => widget.packId == null && _createdId == null;

  /// Toute édition locale fait tomber l'indicateur "Enregistré".
  void _markDirty() {
    if (_savedFlag.saved) setState(() => _savedFlag.markDirty());
  }

  @override
  void initState() {
    super.initState();
    if (!_isCreate) {
      // Post-frame : localeOf() est interdit pendant initState, et le
      // chargement linté ne doit pas précéder le premier build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _reloadForEdit());
    }
  }

  @override
  void dispose() {
    _titleFr.dispose();
    _titleEn.dispose();
    _descFr.dispose();
    _descEn.dispose();
    for (final f in _forms) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _reloadForEdit() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final draft =
          await UgcPackRepository().loadForEdit(widget.packId!);
      if (!mounted) return;
      for (final f in _forms) {
        f.dispose();
      }
      setState(() {
        _titleFr.text = draft.titleFr;
        _titleEn.text = draft.titleEn;
        _descFr.text = draft.descFr;
        _descEn.text = draft.descEn;
        _forms = [for (final q in draft.questions) _QuestionForm.fromDraft(q)];
        _shareCode = draft.shareCode;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final lang = Localizations.localeOf(context).languageCode;
      setState(() {
        _loading = false;
        _loadError = friendlyUgcError(e, lang);
      });
    }
  }

  UgcPackDraft _collectDraft() {
    return UgcPackDraft(
      titleFr: _titleFr.text,
      titleEn: _titleEn.text,
      descFr: _descFr.text,
      descEn: _descEn.text,
      questions: [for (final f in _forms) f.toDraft()],
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final lang = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;
    final draft = _collectDraft();
    final errors = validateUgcPack(draft);
    if (errors.isNotEmpty ||
        (_isCreate && !_termsAccepted)) {
      setState(() {
        _validationErrors = [
          ...errors,
          if (_isCreate && !_termsAccepted) 'terms-required',
        ];
        _saveError = null;
        _savedFlag.markDirty();
      });
      return;
    }
    setState(() {
      _saving = true;
      _validationErrors = [];
      _saveError = null;
      _savedFlag.markDirty();
    });
    try {
      final repo = UgcPackRepository();
      // Après création, l'id retourné devient l'identité d'édition :
      // tout save suivant est un UPDATE (jamais re-CREATE).
      final targetId =
          resolveEditTarget(packId: widget.packId, createdId: _createdId);
      final UgcSaveResult res;
      if (shouldUpdate(packId: widget.packId, createdId: _createdId) &&
          targetId != null) {
        res = await repo.updatePack(targetId, draft);
      } else {
        res = await repo.createPack(draft, acceptTerms: true);
      }
      ref.invalidate(packCatalogProvider);
      if (targetId != null) ref.invalidate(packPreviewProvider(targetId));
      if (!mounted) return;
      if (widget.packId == null) {
        // Création réussie : l'URL devient l'autorité (refresh rouvre
        // l'éditeur existant). Confirmation via SnackBar, l'état inline
        // ne survivrait pas au remplacement de route.
        final createdId = res.id;
        setState(() {
          _saving = false;
          _createdId = createdId;
          _shareCode = res.shareCode;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.editorSaved)),
        );
        context.replace(editRouteFor(createdId));
        return;
      }
      setState(() {
        _saving = false;
        _savedFlag.markSaved();
        _shareCode = res.shareCode;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = friendlyUgcError(e, lang);
      });
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.editorCodeCopied)),
    );
  }

  void _addQuestion() {
    if (_saving || _forms.length >= 100) return;
    setState(() {
      _forms = [..._forms, _QuestionForm()];
      _savedFlag.markDirty();
    });
  }

  void _removeQuestion(int index) {
    if (_saving || _forms.length <= 11) return;
    setState(() {
      final next = [..._forms];
      final removed = next.removeAt(index);
      removed.dispose();
      _forms = next;
      _savedFlag.markDirty();
    });
  }

  void _moveQuestion(int from, int to) {
    if (_saving ||
        from < 0 ||
        from >= _forms.length ||
        to < 0 ||
        to >= _forms.length ||
        from == to) {
      return;
    }
    setState(() {
      final next = [..._forms];
      final item = next.removeAt(from);
      next.insert(to, item);
      _forms = next;
      _savedFlag.markDirty();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? l10n.packCreate : l10n.packEdit),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _reloadForEdit,
                        child: Text(l10n.packRetry),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _titleFr,
                      enabled: mutationEnabled(saving: _saving),
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(labelText: l10n.editorTitleFr),
                    ),
                    TextField(
                      controller: _titleEn,
                      enabled: mutationEnabled(saving: _saving),
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(labelText: l10n.editorTitleEn),
                    ),
                    TextField(
                      controller: _descFr,
                      enabled: mutationEnabled(saving: _saving),
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(labelText: l10n.editorDescFr),
                    ),
                    TextField(
                      controller: _descEn,
                      enabled: mutationEnabled(saving: _saving),
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(labelText: l10n.editorDescEn),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${l10n.editorQuestions} (${_forms.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (var i = 0; i < _forms.length; i++)
                      _QuestionCard(
                        index: i,
                        total: _forms.length,
                        form: _forms[i],
                        enabled: mutationEnabled(saving: _saving),
                        onRemove: () => _removeQuestion(i),
                        onMoveUp: i > 0 &&
                                mutationEnabled(saving: _saving)
                            ? () => _moveQuestion(i, i - 1)
                            : null,
                        onMoveDown: i + 1 < _forms.length &&
                                mutationEnabled(saving: _saving)
                            ? () => _moveQuestion(i, i + 1)
                            : null,
                        onChanged: _markDirty,
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: !mutationEnabled(saving: _saving) ||
                              _forms.length >= 100
                          ? null
                          : _addQuestion,
                      child: Text(l10n.editorAddQuestion),
                    ),
                    if (_shareCode != null && _shareCode!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('${l10n.editorShareCode} : $_shareCode'),
                      TextButton(
                        onPressed: () => _copyCode(_shareCode!),
                        child: Text(l10n.editorCopyCode),
                      ),
                    ],
                    if (_isCreate) ...[
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _termsAccepted,
                        onChanged: mutationEnabled(saving: _saving)
                            ? (v) {
                                setState(
                                    () => _termsAccepted = v ?? false);
                                _markDirty();
                              }
                            : null,
                        title: Text(l10n.editorTerms),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(l10n.editorTermsAccepted),
                    ],
                    if (_validationErrors.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(l10n.editorFixErrors),
                      for (final code in _validationErrors)
                        Text(
                          '• ${friendlyUgcError(code, lang)}',
                        ),
                    ],
                    if (_saveError != null) ...[
                      const SizedBox(height: 8),
                      Text(_saveError!),
                    ],
                    if (_saved) ...[
                      const SizedBox(height: 8),
                      Text(l10n.editorSaved),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _saving ||
                              (_isCreate && !_termsAccepted)
                          ? null
                          : _save,
                      child: Text(l10n.editorSave),
                    ),
                  ],
                ),
    );
  }
}

class _QuestionCard extends StatefulWidget {
  final int index;
  final int total;
  final _QuestionForm form;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onChanged;
  const _QuestionCard({
    required this.index,
    required this.total,
    required this.form,
    required this.enabled,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onChanged,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = widget.form;
    // Note visible : les réponses numériques sont évaluées en exact,
    // même si fuzzy est sélectionné (le serveur tranche de toute façon).
    final numeric = isNumericAnswer(f.answerFr.text) ||
        isNumericAnswer(f.answerEn.text);
    Widget field(TextEditingController c, String label,
        {int lines = 1, bool liveNumeric = false}) {
      return TextField(
        controller: c,
        maxLines: lines,
        enabled: widget.enabled,
        decoration: InputDecoration(labelText: label),
        onChanged: (_) {
          widget.onChanged();
          // Recalcul immédiat du mode (note exact + Fuzzy indisponible),
          // même si le parent est déjà dirty (pas de setState parent).
          if (liveNumeric) setState(() {});
        },
      );
    }

    return Card(
      child: ExpansionTile(
        title: Text('Q${widget.index + 1}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                field(f.promptFr, l10n.editorQuestionFr),
                field(f.promptEn, l10n.editorQuestionEn),
                field(f.answerFr, l10n.editorAnswerFr, liveNumeric: true),
                field(f.answerEn, l10n.editorAnswerEn, liveNumeric: true),
                field(f.aliasesFr, l10n.editorAliasesFr, lines: 2),
                field(f.aliasesEn, l10n.editorAliasesEn, lines: 2),
                field(f.category, l10n.editorCategory),
                Row(
                  children: [
                    Expanded(child: Text(l10n.editorDifficulty)),
                    DropdownButton<int>(
                      value: f.difficulty,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1')),
                        DropdownMenuItem(value: 2, child: Text('2')),
                        DropdownMenuItem(value: 3, child: Text('3')),
                      ],
                      onChanged: widget.enabled
                          ? (v) => setState(() {
                                f.difficulty = v ?? 1;
                                widget.onChanged();
                              })
                          : null,
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: numeric ? 'exact' : f.matchMode,
                      items: [
                        DropdownMenuItem(
                          value: 'exact',
                          child: Text(l10n.editorExact),
                        ),
                        DropdownMenuItem(
                          value: 'fuzzy',
                          enabled: !numeric,
                          child: Text(l10n.editorFuzzy),
                        ),
                      ],
                      onChanged: widget.enabled
                          ? (v) => setState(() {
                                f.matchMode = v ?? 'fuzzy';
                                widget.onChanged();
                              })
                          : null,
                    ),
                  ],
                ),
                if (numeric) Text(l10n.editorNumericExactNote),
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.editorMoveUp,
                      onPressed: widget.onMoveUp,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: l10n.editorMoveDown,
                      onPressed: widget.onMoveDown,
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.enabled && widget.total > 11
                          ? widget.onRemove
                          : null,
                      child: Text(l10n.editorRemove),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
