import 'package:acolhe_mobile/features/journal/application/journal_controller.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:acolhe_mobile/shared/widgets/app_shell.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:acolhe_mobile/shared/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class IncidentRecordScreen extends ConsumerStatefulWidget {
  const IncidentRecordScreen({super.key});

  @override
  ConsumerState<IncidentRecordScreen> createState() =>
      _IncidentRecordScreenState();
}

class _IncidentRecordScreenState extends ConsumerState<IncidentRecordScreen> {
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _peopleController = TextEditingController();
  final _witnessController = TextEditingController();
  final _attachmentsController = TextEditingController();
  final _observationsController = TextEditingController();
  final _impactsController = TextEditingController();

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _peopleController.dispose();
    _witnessController.dispose();
    _attachmentsController.dispose();
    _observationsController.dispose();
    _impactsController.dispose();
    super.dispose();
  }

  IncidentRecordModel _buildRecord() {
    return IncidentRecordModel(
      id: generateId(),
      occurredOn: _dateController.text.trim(),
      occurredAt: _timeController.text.trim(),
      location: _locationController.text.trim(),
      description: _descriptionController.text.trim(),
      peopleInvolved: decodeListText(_peopleController.text),
      witnesses: decodeListText(_witnessController.text),
      attachments: decodeListText(_attachmentsController.text),
      observations: _observationsController.text.trim(),
      perceivedImpacts: decodeListText(_impactsController.text),
      summary: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Registro privado',
      subtitle: 'Rascunho pessoal salvo apenas no aparelho, se voce quiser.',
      maxContentWidth: 1180,
      child: Column(
        children: [
          const GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  title: 'Anote no seu ritmo',
                  subtitle:
                      'Voce pode preencher apenas o que fizer sentido agora. Isso e um rascunho pessoal e nao um documento oficial.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AdaptiveTwoPane(
            primary: GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: AppTextField(
                              controller: _dateController, label: 'Data')),
                      const SizedBox(width: 12),
                      Expanded(
                          child: AppTextField(
                              controller: _timeController, label: 'Hora')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppTextField(controller: _locationController, label: 'Local'),
                  const SizedBox(height: 14),
                  ListEditorField(
                    controller: _peopleController,
                    label: 'Pessoas envolvidas',
                    hint: 'Uma pessoa por linha',
                  ),
                  const SizedBox(height: 14),
                  ListEditorField(
                    controller: _witnessController,
                    label: 'Testemunhas',
                    hint: 'Uma pessoa por linha',
                  ),
                  const SizedBox(height: 14),
                  ListEditorField(
                    controller: _attachmentsController,
                    label: 'Anexos',
                    hint: 'Ex.: print_01.png',
                  ),
                ],
              ),
            ),
            secondary: GlassCard(
              child: Column(
                children: [
                  AppTextField(
                    controller: _descriptionController,
                    label: 'Descricao',
                    hint:
                        'O que aconteceu, apenas ate onde se sentir confortavel.',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _observationsController,
                    label: 'Observacoes',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  ListEditorField(
                    controller: _impactsController,
                    label: 'Impactos percebidos',
                    hint: 'Ex.: medo, ansiedade',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AdaptiveTwoPane(
            breakpoint: 820,
            primaryFlex: 1,
            secondaryFlex: 1,
            primary: AppButton.primary(
              label: 'Gerar resumo cronologico',
              onPressed: () async {
                final record = _buildRecord();
                await ref
                    .read(journalControllerProvider.notifier)
                    .saveRecord(record);
                final summary = await ref
                    .read(journalControllerProvider.notifier)
                    .generateSummary(record);
                ref.read(selectedIncidentSummaryProvider.notifier).state =
                    summary;
                if (!mounted) {
                  return;
                }
                context.push('/incident-summary');
              },
            ),
            secondary: AppButton.secondary(
              label: 'Salvar sem resumo',
              onPressed: () async {
                await ref
                    .read(journalControllerProvider.notifier)
                    .saveRecord(_buildRecord());
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Registro salvo com seguranca no aparelho.')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class IncidentSummaryScreen extends ConsumerWidget {
  const IncidentSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(selectedIncidentSummaryProvider);
    return AppShell(
      title: 'Resumo cronologico',
      subtitle: 'Rascunho pessoal. Nao e documento oficial.',
      maxContentWidth: 760,
      backFallbackRoute: '/incident-record',
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rascunho pessoal',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Nao e documento oficial. Revise com calma antes de compartilhar com qualquer pessoa.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text(
              record?.summary.isNotEmpty == true
                  ? record!.summary
                  : 'Nenhum resumo foi gerado ainda.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
