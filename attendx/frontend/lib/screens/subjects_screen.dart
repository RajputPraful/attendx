import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import '../models/subject.dart';

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  void _openEditor(BuildContext context, {Subject? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SubjectEditorSheet(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
      ),
      body: app.subjects.isEmpty
          ? const Center(child: Text('No subjects yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: app.subjects.length,
              itemBuilder: (context, i) {
                final s = app.subjects[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(s.name),
                    subtitle: Text('${s.code ?? "No code"} • Required ${s.requiredPercentage.toStringAsFixed(0)}%'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openEditor(context, existing: s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => context.read<AppState>().deleteSubject(s.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _SubjectEditorSheet extends StatefulWidget {
  final Subject? existing;
  const _SubjectEditorSheet({this.existing});

  @override
  State<_SubjectEditorSheet> createState() => _SubjectEditorSheetState();
}

class _SubjectEditorSheetState extends State<_SubjectEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _code;
  late TextEditingController _required;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _code = TextEditingController(text: e?.code ?? '');
    _required = TextEditingController(text: (e?.requiredPercentage ?? 75).toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Add Subject' : 'Edit Subject',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Subject name'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Subject code (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _required,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Required attendance %'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final app = context.read<AppState>();
                if (widget.existing == null) {
                  await app.addSubject(Subject(
                    id: 0,
                    name: _name.text,
                    code: _code.text.isEmpty ? null : _code.text,
                    requiredPercentage: double.tryParse(_required.text) ?? 75,
                    color: '#6750A4',
                  ));
                } else {
                  await app.updateSubject(widget.existing!.id, {
                    'name': _name.text,
                    'code': _code.text.isEmpty ? null : _code.text,
                    'required_percentage': double.tryParse(_required.text) ?? 75,
                  });
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
