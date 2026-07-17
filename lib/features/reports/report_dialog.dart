import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class ReportFormResult {
  const ReportFormResult({required this.category, this.description});

  final String category;
  final String? description;
}

Future<ReportFormResult?> showReportDialog({
  required BuildContext context,
  required String title,
  required List<String> categories,
}) async {
  return showDialog<ReportFormResult>(
    context: context,
    builder: (context) => _ReportDialog(title: title, categories: categories),
  );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.title, required this.categories});

  final String title;
  final List<String> categories;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  late String _category = widget.categories.first;
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '신고 사유',
              style: TtmTypography.label.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: TtmSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: [
                for (final category in widget.categories)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: TtmSpacing.md),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '추가 상황 설명',
                hintText: '운영자가 확인할 수 있도록 상황을 적어주세요.',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton.tonal(
          onPressed: () {
            Navigator.of(context).pop(
              ReportFormResult(
                category: _category,
                description: _description.text.trim().isEmpty
                    ? null
                    : _description.text.trim(),
              ),
            );
          },
          child: const Text('신고 접수'),
        ),
      ],
    );
  }
}
