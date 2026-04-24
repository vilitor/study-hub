import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/widgets/custom_text_field.dart';

/// Construtor Mágico que desenha campos de formulário baseados no tipo das propriedades lá do Notion
class DynamicFormBuilder extends StatelessWidget {
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
  Widget build(BuildContext context) {
    switch (property.type) {
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
        // No escopo aceito pelo plano, teremos apenas Date (Filled Automático com Now). 
        // Desenharemos um Container ReadOnly pra sinalizar o envio automático.
        return _buildDateReadonly(context);
        
      default:
        // Caso surja algum tipo exótico (checkbox, url, files, formula), pulamos ou exibimos alerta simples
        return const SizedBox.shrink();
    }
  }

  // 1. Text e Rich_text usam input nativo com multilinhas e decoradores de tema
  Widget _buildTextField(BuildContext context) {
    // Controller efêmero para facilitar a vida do state parent (no mundo real usariamos controle direto no pai)
    // Para simplificar a estrutura stateful x stateless do mapper dinâmico usaremos onChanged (String)
    
    // O TextFormField cuidará de repassar os eventos onChanged
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: CustomTextField(
        label: property.name,
        hint: 'Digite algo...',
        prefixIcon: property.type == 'title' ? Icons.title_rounded : Icons.notes_rounded,
        initialValue: initialValue as String?,
        maxLines: property.type == 'title' ? 1 : 3,
        onChanged: onChanged,
      ),
    );
  }

  // 2. Número
  Widget _buildNumberField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: CustomTextField(
        key: ValueKey(initialValue?.toString() ?? 'empty'),
        label: property.name,
        hint: '0',
        prefixIcon: Icons.numbers_rounded,
        initialValue: initialValue?.toString() ?? '',
        keyboardType: TextInputType.number,
        onChanged: (val) {
          final numberValue = int.tryParse(val) ?? 0;
          onChanged(numberValue);
        },
      ),
    );
  }

  // 3. Dropdown para Select
  Widget _buildSelect(BuildContext context) {
    final value = property.options.contains(initialValue) ? initialValue as String : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              property.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).inputDecorationTheme.fillColor ?? AppColors.cardGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                hint: const Text('Selecione uma opção'),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                items: property.options.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(item, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) => onChanged(val),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Wrap Chips para Multi-select
  Widget _buildMultiSelect(BuildContext context) {
    if (property.options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text('Nenhuma opção para ${property.name} (adicione lá no Notion primeiro!)',
            style: const TextStyle(color: AppColors.error, fontSize: 12)),
      );
    }

    final currentSelection = (initialValue as List<String>?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              property.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: property.options.map((opt) {
              final isSelected = currentSelection.contains(opt);
              return GestureDetector(
                onTap: () {
                  final newSelection = List<String>.from(currentSelection);
                  if (isSelected) {
                    newSelection.remove(opt);
                  } else {
                    newSelection.add(opt);
                  }
                  onChanged(newSelection);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.purple : Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        opt,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 5. Data (Automática Hoje visualmente)
  Widget _buildDateReadonly(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: CustomTextField(
        label: property.name,
        hint: 'Data atual preenchida automaticamente',
        prefixIcon: Icons.calendar_today_rounded,
        initialValue: 'Hoje',
        readOnly: true,
        onChanged: (v) {},
      ),
    );
  }
}
