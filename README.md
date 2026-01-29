# Gravity

## Visão geral
Gravity é um painel administrativo e vitrine pública focado em catálogos digitais. A base do app é em Flutter 3.10 + Riverpod, combinando armazenamento local (Hive) com Firebase Auth para permitir controle de acesso, métricas e compartilhamento via web/WhatsApp mesmo sem conexão cheia.

## Recursos principais

### Painel administrativo completo
- O AdminShellScreen monta o StatefulShellRoute do GoRouter com NavigationRail + Drawer para Dashboard, Pedidos, Produtos, Categorias, Catálogos, Promoções (placeholder), Vendedoras e Configurações.
- OrdersScreen exibe KPIs (pedidos do dia, faturamento, ticket médio), busca livre, filtros por status, período, ordenação e permite atualizar status do pedido em linha. Cada registro pode abrir o WhatsApp com dados do cliente.
- ProductsScreen mostra cards responsivos, filtros por nome/categoria/status, KPIs rápidos e ações para ver, editar, excluir, criar produtos ou importar via CSV/arquivos de imagem.
- CategoriesScreen oferece busca, ordenação (manual ou A-Z), drag-and-drop e diálogos para criar/editar/excluir categorias com redistribuição automática dos produtos.
- CatalogsScreen e o CatalogEditorScreen cuidam da criação de catálogos (slug, modo varejo/atacado, layout fotográfico, exigência de dados, anúncio, banners, link público, código de compartilhamento) e expõem ações para copiar link, compartilhar PDF/link, editar ou deletar.
- SellersScreen gerencia vendedoras com campos obrigatórios de WhatsApp, status ativo/inativo, confirmação para exclusão e alternância rápida via switch.
- SettingsScreen controla modo escuro (via 	hemeModeProvider), nome da loja, WhatsApp padrão, URL pública e salva tudo em Hive para uso em geração de links e mensagens automáticas.

### Catálogos e compartilhamento
- CatalogShareHelper combina CatalogPdfService (geração estilizada em PDF com fotos, preço, pix e parcelamento) e WhatsAppShareService (envio de link, PDF ou pedido via WhatsApp usando share_plus e url_launcher).
- O link público segue o padrão /c/{shareCode} e usa AppSettings.publicBaseUrl (ou https://gravity.app) para montar a URL.
- Há botões na tela do catálogo para regenerar código, copiar link com o Clipboard, salvar PDF nos downloads e enviar o arquivo diretamente ao WhatsApp do contato.

### Vitrine pública e checkout
- CatalogHomePage consome catalogPublicProvider, exibe chips de categoria, mensagem de anúncio e layout flexível (grid/list/carrossel) com controle de tamanho, estoque e promoção.
- ProductQuickAddSheet permite selecionar tamanho (quando houver), quantidade e adiciona o item ao carrinho global (CartViewModel), que calcula total e mantém itens usando OrderItem.
- CartSidePanel lista itens, ajusta quantidade e leva ao CheckoutSheet, que valida nome/WhatsApp, mostra total e dispara CheckoutViewModel.submitOrder, salvando o pedido em Hive e abrindo o WhatsApp com o resumo.

### Infraestrutura e arquitetura
- **Estado**: Riverpod + iverpod_annotation geram os ViewModels (dashboard, orders, products, catalogs, categories, sellers, settings, cart, checkout, product_import etc.) que consomem repositórios baseados em Hive.
- **Persistência**: Hive abre boxes (orders, categories, products, catalogs, sellers, settings) com adaptadores para cada model (Order, OrderStatus, OrderItem, Category, Product, Catalog, CatalogBanner, Seller, AppSettings). Os repositórios expõem streams para manter a UI reativa.
- **Autenticação**: FirebaseAuthRepository (com opção de LocalAuthRepository para dev/offline) e AuthController fazem login e registro por e-mail/senha. _authRedirect garante que apenas admins acessem /admin/* e redireciona para /login, /register ou / conforme o estado.
- **Navegação**: GoRouter (com GoRouterRefreshStream ligado ao uthStateChanges) define rotas públicas (/, /login, /register, /c/{shareCode}) e um fluxo protegido /admin/*. O MaterialApp.router usa temas definidos com GoogleFonts.inter e ThemeMode global.
- **Serviços utilitários**: CatalogPdfService gera PDFs com pdf e printing, WhatsAppShareService dispara mensagens e arquivos, CatalogShareHelper orquestra opções de compartilhamento, e widgets responsivos (ResponsiveScaffold/ResponsiveContainer) garantem boa aparência em diferentes larguras.
- **Firebase + offline**: main.dart inicializa Hive, registra adaptadores, abre boxes e só então chama Firebase.initializeApp em 	ry/catch, permitindo iniciar o app mesmo sem conexão completa.

## Estrutura de dados e fluxo
- **Modelos**: AppSettings, Order, OrderItem, OrderStatus, Category, Product, Catalog (com enum CatalogMode), CatalogBanner, Seller. Cada um possui métodos copyWith e map para serialização e combinações (ex: preços de varejo/atacado, tamanhos, cores, imagens, flags de estoque/promoção).
- **ViewModels/repositórios**: Os viewmodels observam repositórios (ordersRepository, productsRepository, catalogsRepository, etc.) gerados por Hive e atualizam a UI automaticamente. Os repositórios também oferecem métodos síncronos/assíncronos quando necessário (ex: CatalogsViewModel.deleteCatalog valida dono, CheckoutViewModel grava pedidos e notifica DashboardViewModel para recarregar KPIs).
- **Build runner**: Como o projeto usa iverpod_annotation e hive_generator, é necessário regenerar os arquivos .g.dart sempre que os modelos/viewmodels mudam.

## Estrutura de pastas
- lib/core: widgets responsivos, widgets auxiliares (catalog share/pdf/WhatsApp), autenticação, migração e configuração.
- lib/data: contratos e repositórios Hive para cada entidade.
- lib/models: classes anotadas com Hive para orders, produtos, catálogos, categorias, vendedores e configurações.
- lib/viewmodels: lógica reativa (cart, checkout, dashboards, importação de produtos etc.).
- lib/features: telas divididas em dmin (dashboard, pedidos, produtos, categorias, catálogos, vendedoras, configurações), uth (login/registro), public (front-end do cliente) e 	heme (modo escuro).
- 	est: testes de unidade para DashboardViewModel e um template widget_test.

## Execução local
1. Instale o SDK do Flutter 3.10.7 (ou compatível com environment.sdk do pubspec.yaml).
2. lutter pub get
3. Gere os arquivos anotados:
   `ash
   flutter pub run build_runner build --delete-conflicting-outputs
   `
4. Conecte um dispositivo ou use lutter run -d windows (o app já tem pastas para Android, iOS, web e windows).
5. Para desenvolvimento rápido, lutter run abre automaticamente /admin/orders e o controlador de rotas garante bloqueio de acesso.

## Firebase e configurações
- irebase_options.dart já contém as opções compiladas do Firebase (Firestore/Auth) e é usado em main.dart. Ajuste com lutterfire configure se trocar de projeto.
- Há um arquivo de serviço (catalogo-fc9b5-firebase-adminsdk-fbsvc-b3b763c964.json) e regras em irestore.rules para controlar o acesso remoto, mas os dados de fato ficam armazenados em Hive até que uma sincronização seja implementada.
- SettingsScreen grava o defaultWhatsapp, publicBaseUrl, storeName e defaultMessageTemplate em Hive; esses valores são reutilizados ao compartilhar catálogos e ao enviar pedidos via WhatsApp.

## Testes e qualidade
- lutter test test/dashboard_viewmodel_test.dart valida que os KPIs do dashboard são calculados corretamente para diferentes status de pedidos.
- 	est/widget_test.dart é o template padrão do Flutter e pode ser adaptado para validar widgets críticos.

## Dicas e próximos passos
- Ao criar catálogos públicos, salve-os antes de copiar o link: apenas após o salvamento o shareCode é gerado.
- Use a importação por CSV/ imagens para popular produtos em massa (os arquivos são vinculados pelos SKUs).
- A tela de pedidos já permite enviar WhatsApp diretamente ao cliente e alterar status; para registrar faturamento, cuide de marcar como confirmado/pago/enviado/entregue.
- O botão de compartilhamento abre o CatalogShareHelper, que permite exportar PDFs, copiar links e forçar geração de novo código.
- Teste o compartilhar de pedidos com o WhatsApp padrão configurado no settings para manter o fluxo de vendas automatizado.
- Para habilitar o modo offline completo, crie uma implementação com LocalAuthRepository e sincronize manualmente com Firestore.
