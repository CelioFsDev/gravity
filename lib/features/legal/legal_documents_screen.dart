import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

enum LegalDocumentType { privacy, terms, deletion }

class LegalContactConfig {
  LegalContactConfig._();

  static const String appName = 'CatalogoJa';
  static const String legalEntityName = 'SUA EMPRESA LTDA';
  static const String websiteUrl = 'https://seudominio.com';
  static const String privacyEmail = 'juridico@seudominio.com';
  static const String supportEmail = 'suporte@seudominio.com';
  static const String whatsappNumber = '5511999999999';
  static const String lastUpdated = '27 de abril de 2026';
}

class LegalDocumentsScreen extends StatelessWidget {
  const LegalDocumentsScreen({required this.type, super.key});

  final LegalDocumentType type;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final document = _documentFor(type);

    return Scaffold(
      backgroundColor: isDark ? AppTokens.deepNavy : const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: Text(document.title),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LegalHero(document: document),
                  const SizedBox(height: 20),
                  _LegalWarningCard(isDark: isDark),
                  const SizedBox(height: 20),
                  _LegalNav(currentType: type),
                  const SizedBox(height: 20),
                  ...document.sections.map(
                    (section) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _LegalSectionCard(section: section),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _LegalContactCard(document: document),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _LegalDocument _documentFor(LegalDocumentType type) {
    switch (type) {
      case LegalDocumentType.privacy:
        return _privacyDocument;
      case LegalDocumentType.terms:
        return _termsDocument;
      case LegalDocumentType.deletion:
        return _deletionDocument;
    }
  }
}

class _LegalHero extends StatelessWidget {
  const _LegalHero({required this.document});

  final _LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTokens.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              document.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              document.summary,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ultima atualizacao: ${LegalContactConfig.lastUpdated}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalWarningCard extends StatelessWidget {
  const _LegalWarningCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? Colors.amber.withOpacity(0.1) : const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.35)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Antes de publicar, substitua os dados de exemplo da sua empresa, dominio, email juridico e WhatsApp de suporte.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalNav extends StatelessWidget {
  const _LegalNav({required this.currentType});

  final LegalDocumentType currentType;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _navButton(
          context,
          label: 'Politica de Privacidade',
          route: '/legal/privacy',
          selected: currentType == LegalDocumentType.privacy,
        ),
        _navButton(
          context,
          label: 'Termos de Uso',
          route: '/legal/terms',
          selected: currentType == LegalDocumentType.terms,
        ),
        _navButton(
          context,
          label: 'Exclusao de Conta',
          route: '/legal/delete-account',
          selected: currentType == LegalDocumentType.deletion,
        ),
      ],
    );
  }

  Widget _navButton(
    BuildContext context, {
    required String label,
    required String route,
    required bool selected,
  }) {
    return OutlinedButton(
      onPressed: selected ? null : () => context.go(route),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : null,
        backgroundColor: selected ? AppTokens.electricBlue : null,
        side: BorderSide(
          color: selected ? AppTokens.electricBlue : AppTokens.borderLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: Text(label),
    );
  }
}

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard({required this.section});

  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppTokens.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE6ECF3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...section.paragraphs.map(
              (paragraph) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableText(
                  paragraph,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: isDark ? Colors.white70 : AppTokens.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalContactCard extends StatelessWidget {
  const _LegalContactCard({required this.document});

  final _LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppTokens.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE6ECF3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contato e solicitacoes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              document.contactLead,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? Colors.white70 : AppTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => _launchEmail(LegalContactConfig.privacyEmail),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('ENVIAR E-MAIL'),
                ),
                OutlinedButton.icon(
                  onPressed: _launchWhatsApp,
                  icon: const Icon(Icons.message_outlined),
                  label: const Text('FALAR NO WHATSAPP'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              'Empresa: ${LegalContactConfig.legalEntityName}\n'
              'Site: ${LegalContactConfig.websiteUrl}\n'
              'Email juridico: ${LegalContactConfig.privacyEmail}\n'
              'Suporte: ${LegalContactConfig.supportEmail}\n'
              'WhatsApp: ${LegalContactConfig.whatsappNumber}',
              style: TextStyle(
                fontSize: 13,
                height: 1.7,
                color: isDark ? Colors.white60 : AppTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': document.emailSubject},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/${LegalContactConfig.whatsappNumber}'
      '?text=${Uri.encodeComponent(document.whatsAppMessage)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _LegalDocument {
  const _LegalDocument({
    required this.title,
    required this.summary,
    required this.contactLead,
    required this.emailSubject,
    required this.whatsAppMessage,
    required this.sections,
  });

  final String title;
  final String summary;
  final String contactLead;
  final String emailSubject;
  final String whatsAppMessage;
  final List<_LegalSection> sections;
}

class _LegalSection {
  const _LegalSection({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;
}

const _privacyDocument = _LegalDocument(
  title: 'Politica de Privacidade',
  summary:
      'Este documento explica como o aplicativo coleta, usa, armazena e compartilha dados pessoais de lojistas, equipes internas e clientes finais que interagem com catalogos, pedidos e canais de atendimento.',
  contactLead:
      'Se voce quiser exercer seus direitos de acesso, correcao, portabilidade, anonimização, oposicao ou exclusao de dados, entre em contato pelos canais abaixo.',
  emailSubject: 'Solicitacao de privacidade e dados pessoais',
  whatsAppMessage: 'Ola! Quero tratar uma solicitacao de privacidade e dados.',
  sections: [
    _LegalSection(
      title: '1. Quem controla os dados',
      paragraphs: [
        '${LegalContactConfig.legalEntityName} opera o ${LegalContactConfig.appName} e atua como controladora dos dados pessoais tratados para cadastro, autenticacao, suporte, operacao da plataforma e seguranca da conta.',
        'Quando o lojista usa a plataforma para vender a consumidores finais, ele tambem pode atuar como controlador dos dados de clientes cadastrados em pedidos, contatos e catalogos.',
      ],
    ),
    _LegalSection(
      title: '2. Dados que podemos coletar',
      paragraphs: [
        'Podemos coletar dados de identificacao e contato, como nome, email, telefone e WhatsApp, alem de informacoes de login, perfil, empresa, catalogos, produtos, pedidos, registros tecnicos, IP, dispositivo, falhas e eventos de uso.',
        'Tambem podem ser tratados dados fornecidos pelo proprio lojista sobre seus clientes, como nome, telefone, itens pedidos e historico comercial dentro da operacao da loja.',
      ],
    ),
    _LegalSection(
      title: '3. Finalidades do tratamento',
      paragraphs: [
        'Usamos os dados para criar e manter contas, autenticar acessos, publicar catalogos, receber pedidos, disponibilizar compartilhamento por link ou WhatsApp, prestar suporte, prevenir fraude, cumprir obrigacoes legais e melhorar o produto.',
        'Dados tecnicos e de erro podem ser usados para diagnosticar instabilidades, monitorar disponibilidade e corrigir defeitos do aplicativo.',
      ],
    ),
    _LegalSection(
      title: '4. Bases legais',
      paragraphs: [
        'O tratamento pode ocorrer com base na execucao de contrato, exercicio regular de direitos, cumprimento de obrigacao legal, legitimo interesse para seguranca e melhoria do servico e, quando aplicavel, consentimento.',
      ],
    ),
    _LegalSection(
      title: '5. Compartilhamento de dados',
      paragraphs: [
        'Os dados podem ser processados por fornecedores de infraestrutura, autenticacao, banco de dados, hospedagem, analytics, monitoramento de erros, armazenamento de arquivos e mensageria, sempre dentro do necessario para a operacao da plataforma.',
        'Tambem pode haver compartilhamento quando exigido por ordem judicial, autoridade competente ou para defesa de direitos em processos administrativos e judiciais.',
      ],
    ),
    _LegalSection(
      title: '6. Retencao e seguranca',
      paragraphs: [
        'Mantemos os dados pelo tempo necessario para cumprir as finalidades descritas nesta politica, respeitar prazos legais, resolver disputas e preservar trilhas minimas de seguranca e auditoria.',
        'Adotamos medidas tecnicas e administrativas razoaveis para proteger dados contra acesso nao autorizado, destruicao, perda, alteracao ou divulgacao indevida.',
      ],
    ),
    _LegalSection(
      title: '7. Direitos do titular',
      paragraphs: [
        'O titular pode solicitar confirmacao de tratamento, acesso, correcao, anonimização, bloqueio, eliminacao, portabilidade, informacao sobre compartilhamento e revisao de decisoes quando aplicavel.',
        'As solicitacoes serao avaliadas dentro dos limites legais e podem exigir validacao de identidade para evitar fraude.',
      ],
    ),
  ],
);

const _termsDocument = _LegalDocument(
  title: 'Termos de Uso',
  summary:
      'Estes termos regulam o acesso e uso do aplicativo, incluindo a criacao de contas, publicacao de catalogos, recebimento de pedidos e responsabilidades do lojista ao usar a plataforma comercialmente.',
  contactLead:
      'Em caso de duvidas contratuais, suporte comercial, contestacoes ou notificacoes formais, use os canais abaixo.',
  emailSubject: 'Duvida sobre termos de uso',
  whatsAppMessage: 'Ola! Quero tirar uma duvida sobre os termos de uso.',
  sections: [
    _LegalSection(
      title: '1. Aceite',
      paragraphs: [
        'Ao criar conta, acessar ou usar o ${LegalContactConfig.appName}, voce declara que leu e concorda com estes Termos de Uso e com a Politica de Privacidade.',
      ],
    ),
    _LegalSection(
      title: '2. Objeto do servico',
      paragraphs: [
        'A plataforma oferece recursos para cadastro de produtos, categorias, catalogos, compartilhamento de vitrines, recebimento de pedidos e organizacao da operacao comercial do lojista.',
      ],
    ),
    _LegalSection(
      title: '3. Cadastro e responsabilidade da conta',
      paragraphs: [
        'O usuario deve fornecer dados verdadeiros, manter credenciais seguras e responder por atividades realizadas em sua conta ou por usuarios vinculados por sua empresa.',
        'E proibido compartilhar acesso de forma insegura, usar identidade de terceiros ou praticar qualquer tentativa de burlar permissoes, limites de plano ou mecanismos de seguranca.',
      ],
    ),
    _LegalSection(
      title: '4. Uso permitido',
      paragraphs: [
        'O usuario concorda em utilizar a plataforma apenas para fins legitimos, sem inserir conteudos ilicitos, enganosos, ofensivos, fraudulentos ou que violem direitos de terceiros, propriedade intelectual ou normas de consumo.',
      ],
    ),
    _LegalSection(
      title: '5. Conteudo e dados do lojista',
      paragraphs: [
        'O lojista e responsavel pelos produtos, precos, imagens, textos, informacoes comerciais, dados de clientes e cumprimento das obrigacoes legais relacionadas ao seu proprio negocio.',
        'A plataforma nao se responsabiliza por promessas comerciais, entrega, estoque, garantia, politica de troca ou tributacao do lojista perante o consumidor final.',
      ],
    ),
    _LegalSection(
      title: '6. Disponibilidade, limites e alteracoes',
      paragraphs: [
        'Podemos atualizar, corrigir, suspender ou descontinuar recursos, bem como aplicar limites por plano, medidas antifraude, manutencoes programadas e ajustes operacionais sempre que necessario.',
      ],
    ),
    _LegalSection(
      title: '7. Suspensao e encerramento',
      paragraphs: [
        'Contas podem ser suspensas ou encerradas em caso de violacao destes termos, uso abusivo, risco de seguranca, fraude, inadimplencia, ordem legal ou descumprimento de politicas da plataforma.',
      ],
    ),
    _LegalSection(
      title: '8. Lei aplicavel',
      paragraphs: [
        'Estes termos sao regidos pela legislacao brasileira. Sempre que possivel, conflitos serao resolvidos de forma amigavel antes de eventual medida administrativa ou judicial.',
      ],
    ),
  ],
);

const _deletionDocument = _LegalDocument(
  title: 'Exclusao de Conta e Dados',
  summary:
      'Esta pagina descreve como o usuario pode solicitar exclusao da propria conta, remocao de dados pessoais e tratamento de dados que precisem ser preservados por obrigacao legal, seguranca ou defesa de direitos.',
  contactLead:
      'Para excluir sua conta ou pedir eliminacao de dados, envie a solicitacao a partir do email vinculado ao cadastro ou informe dados suficientes para validacao.',
  emailSubject: 'Solicitacao de exclusao de conta e dados',
  whatsAppMessage: 'Ola! Quero solicitar a exclusao da minha conta e dos meus dados.',
  sections: [
    _LegalSection(
      title: '1. Como solicitar',
      paragraphs: [
        'Voce pode solicitar exclusao da conta e dos dados pelo email juridico ou pelo canal oficial de suporte. Para sua seguranca, podemos pedir confirmacao de identidade e vinculacao com a conta.',
      ],
    ),
    _LegalSection(
      title: '2. O que normalmente e excluido',
      paragraphs: [
        'Quando a solicitacao for valida e nao houver impedimento legal, a conta pode ser desativada e os dados pessoais vinculados a autenticacao, perfil, contato e uso operacional podem ser anonimizados, apagados ou desvinculados.',
      ],
    ),
    _LegalSection(
      title: '3. Dados que podem ser mantidos',
      paragraphs: [
        'Alguns registros podem ser preservados pelo prazo necessario para cumprimento de obrigacao legal, prevencao a fraude, auditoria, seguranca do ambiente, resolucao de disputas, exercicio regular de direitos e rastreabilidade tecnica minima.',
      ],
    ),
    _LegalSection(
      title: '4. Prazo de atendimento',
      paragraphs: [
        'A solicitacao sera analisada em prazo razoavel, considerando a complexidade do pedido e a necessidade de validacao. Havendo impossibilidade parcial de exclusao, informaremos o fundamento aplicavel.',
      ],
    ),
    _LegalSection(
      title: '5. Dados de terceiros inseridos pelo lojista',
      paragraphs: [
        'Se a conta controlava dados de clientes finais, pedidos ou catalogos da operacao comercial, poderemos orientar sobre exportacao previa e efeitos da exclusao para nao interromper indevidamente o negocio ou afetar direitos de terceiros.',
      ],
    ),
  ],
);
