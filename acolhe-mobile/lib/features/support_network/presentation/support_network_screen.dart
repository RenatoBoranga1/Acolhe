import 'package:acolhe_mobile/features/support_network/application/support_network_controller.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:acolhe_mobile/shared/widgets/app_shell.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:acolhe_mobile/shared/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportNetworkScreen extends ConsumerStatefulWidget {
  const SupportNetworkScreen({super.key});

  @override
  ConsumerState<SupportNetworkScreen> createState() => _SupportNetworkScreenState();
}

class _SupportNetworkScreenState extends ConsumerState<SupportNetworkScreen> {
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController(
    text: 'Oi, preciso do seu apoio. Passei por uma situacao dificil e gostaria de conversar com voce.',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(supportNetworkControllerProvider);
    return AppShell(
      title: 'Rede de apoio',
      subtitle: 'Contatos confiaveis e uma mensagem simples para pedir ajuda.',
      maxContentWidth: 1180,
      child: AdaptiveTwoPane(
        primary: Column(
          children: [
            for (final contact in contacts) ...[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(contact.name, style: Theme.of(context).textTheme.titleMedium),
                        ),
                        Text('Prioridade ${contact.priority}'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${contact.relationship} - ${contact.phone}'),
                    const SizedBox(height: 12),
                    Text(contact.readyMessage),
                    const SizedBox(height: 12),
                    AppButton.secondary(
                      label: 'Copiar mensagem pronta',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: contact.readyMessage));
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mensagem copiada.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
        secondary: GlassCard(
          child: Column(
            children: [
              AppTextField(controller: _nameController, label: 'Nome'),
              const SizedBox(height: 14),
              AppTextField(controller: _relationshipController, label: 'Relacao'),
              const SizedBox(height: 14),
              AppTextField(controller: _phoneController, label: 'Telefone'),
              const SizedBox(height: 14),
              AppTextField(
                controller: _messageController,
                label: 'Mensagem pronta',
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              AppButton.primary(
                label: 'Adicionar contato',
                onPressed: () async {
                  await ref.read(supportNetworkControllerProvider.notifier).addContact(
                        TrustedContactModel(
                          id: generateId(),
                          name: _nameController.text.trim(),
                          relationship: _relationshipController.text.trim(),
                          phone: _phoneController.text.trim(),
                          email: '',
                          priority: 1,
                          readyMessage: _messageController.text.trim(),
                        ),
                      );
                  _nameController.clear();
                  _relationshipController.clear();
                  _phoneController.clear();
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contato adicionado.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
