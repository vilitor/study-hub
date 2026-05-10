import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/widgets/app_multi_select_field.dart';
import 'package:study_hub/widgets/custom_text_field.dart';

class DynamicFormBuilder extends StatefulWidget {
  final NotionProperty property;
  final dynamic initialValue;
  final ValueChanged<dynamic> onChanged;

  const DynamicFormBuilder({
    super.key,
    required this.property,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<DynamicFormBuilder> createState() => _DynamicFormBuilderState();
}

class _DynamicFormBuilderState extends State<DynamicFormBuilder> {
  TextEditingController? _controller;
  FocusNode? _focusNode;

  bool get _usesTextController =>
      widget.property.type == 'title' ||
      widget.property.type == 'rich_text' ||
      widget.property.type == 'number';

  @override
  void initState() {
    super.initState();
    if (_usesTextController) {
      _controller = TextEditingController(
        text: _stringValue(widget.initialValue),
      );
      _focusNode = FocusNode();
    }
  }

  @override
  void didUpdateWidget(covariant DynamicFormBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_usesTextController && _controller != null) {
      final next = _stringValue(widget.initialValue);
      if (!_focusNode!.hasFocus && _controller!.text != next) {
        _controller!.text = next;
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.property.type) {
      case 'title':
      case 'rich_text':
        return _buildTextField(context);
      case 'select':
        return _buildSelect(context);
      case 'multi_select':
        return _buildMultiSelect(context);
      case 'number':
        return _buildNumberField(context);
      case 'date':
        return _buildDateReadonly(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: CustomTextField(
        label: widget.property.name,
        hint: 'Digite algo...',
        prefixIcon: widget.property.type == 'title'
            ? Icons.title_rounded
            : Icons.notes_rounded,
        controller: _controller,
        focusNode: _focusNode,
        maxLines: widget.property.type == 'title' ? 1 : 3,
        onChanged: widget.onChanged,
      ),
    );
  }

  Widget _buildNumberField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: CustomTextField(
        label: widget.property.name,
        hint: '0',
        prefixIcon: Icons.numbers_rounded,
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        onChanged: (val) {
          widget.onChanged(int.tryParse(val) ?? 0);
        },
      ),
    );
  }

  Widget _buildSelect(BuildContext context) {
    final value = widget.property.options.contains(widget.initialValue)
        ? widget.initialValue as String
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              widget.property.name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).inputDecorationTheme.fillColor ??
                  AppColors.cardGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                hint: const Text('Selecione uma opção'),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                items: widget.property.options.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelect(BuildContext context) {
    if (widget.property.options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text(
          'Nenhuma opção para ${widget.property.name}.',
          style: const TextStyle(color: AppColors.error, fontSize: 12),
        ),
      );
    }

    final currentSelection = (widget.initialValue as List<String>?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AppMultiSelectField(
        title: widget.property.name,
        helperText: 'Selecione um ou mais valores.',
        options: widget.property.options,
        selectedValues: currentSelection,
        enableSearch: widget.property.options.length >= 8,
        onChanged: widget.onChanged,
      ),
    );
  }

  Widget _buildDateReadonly(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: CustomTextField(
        label: widget.property.name,
        hint: 'Data atual preenchida automaticamente',
        prefixIcon: Icons.calendar_today_rounded,
        initialValue: 'Hoje',
        readOnly: true,
        onChanged: (_) {},
      ),
    );
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }
}
