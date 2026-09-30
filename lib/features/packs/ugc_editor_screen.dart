// Éditeur UGC Phase 3C : création (/packs/edit) + édition (/packs/edit/:id).
// Uniquement les RPC 0011 (create_ugc_pack / update_ugc_pack /
// get_ugc_pack_for_edit). Aucune écriture/lecture directe de tables.
// Pas d'import, pas de deep link : tickets suivants.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/game_errors.dart';
import '../../l10n/app_localizations.dart';
import 'pack_providers.dart';
import 'ugc_draft.dart';
import 'ugc_repository.dart';

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
  bool _saved = false;
  String? _loadError;
  String? _saveError;
  List<String> _validationErrors = [];
  String? _shareCode;

  bool get _isCreate => widget.packId == null;

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
        _saved = false;
      });
      return;
    }
    setState(() {
      _saving = true;
      _validationErrors = [];
      _saveError = null;
      _saved = false;
    });
    try {
      final repo = UgcPackRepository();
      final UgcSaveResult res;
      if (_isCreate) {
        res = await repo.createPack(draft, acceptTerms: true);
      } else {
        res = await repo.updatePack(widget.packId!, draft);
      }
      ref.invalidate(packCatalogProvider);
      if (!_isCreate) ref.invalidate(packPreviewProvider(widget.packId!));
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
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
    if (_forms.length >= 100) return;
    setState(() => _forms = [..._forms, _QuestionForm()]);
  }

  void _removeQuestion(int index) {
    if (_forms.length <= 11) return;
    setState(() {
      final next = [..._forms];
      final removed = next.removeAt(index);
      removed.dispose();
      _forms = next;
      _saved = false;
    });
  }

  void _moveQuestion(int from, int to) {
    if (from < 0 ||
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
      _saved = false;
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
                      decoration: InputDecoration(labelText: l10n.editorTitleFr),
                    ),
                    TextField(
                      controller: _titleEn,
                      decoration: InputDecoration(labelText: l10n.editorTitleEn),
                    ),
                    TextField(
                      controller: _descFr,
                      decoration: InputDecoration(labelText: l10n.editorDescFr),
                    ),
                    TextField(
                      controller: _descEn,
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
                        onRemove: () => _removeQuestion(i),
                        onMoveUp:
                            i > 0 ? () => _moveQuestion(i, i - 1) : null,
                        onMoveDown: i + 1 < _forms.length
                            ? () => _moveQuestion(i, i + 1)
                            : null,
                        onChanged: () {
                          if (_saved) setState(() => _saved = false);
                        },
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed:
                          _forms.length >= 100 ? null : _addQuestion,
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
                        onChanged: (v) =>
                            setState(() => _termsAccepted = v ?? false),
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
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onChanged;
  const _QuestionCard({
    required this.index,
    required this.total,
    required this.form,
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
        {int lines = 1}) {
      return TextField(
        controller: c,
        maxLines: lines,
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => widget.onChanged(),
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
                field(f.answerFr, l10n.editorAnswerFr),
                field(f.answerEn, l10n.editorAnswerEn),
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
                      onChanged: (v) => setState(() {
                        f.difficulty = v ?? 1;
                        widget.onChanged();
                      }),
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
                      onChanged: (v) => setState(() {
                        f.matchMode = v ?? 'fuzzy';
                        widget.onChanged();
                      }),
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
                      onPressed:
                          widget.total > 11 ? widget.onRemove : null,
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
