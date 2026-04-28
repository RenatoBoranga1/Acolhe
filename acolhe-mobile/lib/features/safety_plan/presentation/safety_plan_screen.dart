import 'package:acolhe_mobile/features/safety_plan/application/safety_plan_controller.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:acolhe_mobile/shared/widgets/app_shell.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:acolhe_mobile/shared/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SafetyPlanScreen extends ConsumerStatefulWidget {
  const SafetyPlanScreen({super.key});

  @override
  ConsumerState<SafetyPlanScreen> createState() => _SafetyPlanScreenState();
}

class _SafetyPlanScreenState extends ConsumerState<SafetyPlanScreen> {
  final _safeLocationsController = TextEditingController();
  final _warningSignsController = TextEditingController();
  final _immediateStepsController = TextEditingController();
  final _priorityContactsController = TextEditingController();
  final _notesController = TextEditingController();
  final _checklistController = TextEditingController();
  bool _hydrated = false;

  @override
  void dispose() {
    _safeLocationsController.dispose();
    _warningSignsController.dispose();
    _immediateStepsController.dispose();
    _priorityContactsController.dispose();
    _notesController.dispose();
    _checklistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(safetyPlanControllerProvider);
    if (!_hydrated) {
      _hydrated = true;
      _safeLocationsController.text = encodeListText(plan.safeLocations);
      _warningSignsController.text = encodeListText(plan.warningSigns);
      _immediateStepsController.text = encodeListText(plan.immediateSteps);
      _priorityContactsController.text = encodeListText(plan.priorityContacts);
      _notesController.text = plan.personalNotes;
      _checklistController.text = encodeListText(plan.emergencyChecklist);
    }

    return AppShell(
      title: 'Plano de seguranca',
      subtitle: 'Passos curtos para momentos de risco ou sobrecarga.',
      maxContentWidth: 1180,
      child: Column(
        children: [
          AdaptiveTwoPane(
            primary: GlassCard(
              child: Column(
                children: [
                  ListEditorField(
                    controller: _safeLocationsController,
                    label: 'Locais seguros',
                    hint: 'Uma opcao por linha',
                  ),
                  const SizedBox(height: 14),
                  ListEditorField(
                    controller: _warningSignsController,
                    label: 'Sinais de alerta',
                    hint: 'Uma opcao por linha',
                  ),
                  const SizedBox(height: 14),
                  ListEditorField(
                    controller: _immediateStepsController,
                    label: 'Passos imediatos',
                    hint: 'Uma acao por linha',
                  ),
                ],
              ),
            ),
            secondary: GlassCard(
              child: Column(
                children: [
                  ListEditorField(
                    controller: _priorityContactsController,
                    label: 'Contatos prioritarios',
                    hint: 'Uma pessoa por linha',
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _notesController,
                    label: 'Anotacoes pessoais',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  ListEditorField(
                    controller: _checklistController,
                    label: 'Checklist de emergencia',
                    hint: 'Um item por linha',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppButton.primary(
            label: 'Salvar plano',
            onPressed: () async {
              await ref.read(safetyPlanControllerProvider.notifier).save(
                    SafetyPlanModel(
                      safeLocations:
                          decodeListText(_safeLocationsController.text),
                      warningSigns:
                          decodeListText(_warningSignsController.text),
                      immediateSteps:
                          decodeListText(_immediateStepsController.text),
                      priorityContacts:
                          decodeListText(_priorityContactsController.text),
                      personalNotes: _notesController.text.trim(),
                      emergencyChecklist:
                          decodeListText(_checklistController.text),
                    ),
                  );
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Plano salvo com seguranca no aparelho.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
