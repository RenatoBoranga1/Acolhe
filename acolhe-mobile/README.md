# Acolhe Mobile

Aplicativo Flutter do Acolhe com:

- onboarding responsavel;
- PIN e biometria opcionais;
- chat acolhedor com modo discreto e experiencia app-like;
- layout responsivo para tablet;
- ajuda urgente;
- registro privado;
- plano de seguranca;
- rede de apoio;
- configuracoes de privacidade.

## Arquitetura atual

Base atual do projeto:

- `Flutter` para interface e runtime multiplataforma;
- `Riverpod` para estado global;
- `go_router` para navegacao;
- `flutter_secure_storage` para persistencia sensivel local;
- `local_auth` para biometria.

Decisao de produto aplicada:

- o chat passou a ser o centro da experiencia autenticada;
- o historico de conversas ficou persistido localmente com conversa ativa salva;
- a interface principal foi reorganizada como workspace com sidebar/drawer, historico, mensagens, empty state e composer fixo;
- os outros modulos continuam acessiveis pela navegacao lateral, preservando a base funcional existente.

## Observacao sobre a estrutura Flutter

Como este workspace nao possui o SDK Flutter no `PATH`, o projeto agora usa um SDK Flutter local compartilhado no workspace, detectado automaticamente pelos scripts.
Para gerar as pastas nativas (`android/`, `ios/`, etc.) a partir da raiz do repositorio:

```bash
powershell -ExecutionPolicy Bypass -File .\setup-mobile.ps1
```

Isso preserva todo o codigo de produto ja implementado em `lib/`.

## Rodando em tablet Android

O app agora esta preparado para tablet com:

- grade responsiva na home e em recursos;
- layout em duas colunas para chat, onboarding, plano de seguranca, rede de apoio e configuracoes;
- largura maxima controlada para evitar telas muito esticadas;
- bolhas, historico e area de conversa adaptadas para telas maiores.

Para testar em um tablet Android:

```bash
powershell -ExecutionPolicy Bypass -File .\flutter-local.ps1 devices
powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1 -DeviceId SEU_DEVICE_ID
```

Se quiser rodar so com os mocks locais, nao informe `ApiBaseUrl`.
Se quiser conectar ao backend no seu computador, use o IP da sua maquina na mesma rede Wi-Fi, e nao `localhost`:

```bash
powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1 -DeviceId SEU_DEVICE_ID -ApiBaseUrl http://SEU_IP_LOCAL:8000
```

Exemplo:

```bash
powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1 -DeviceId R9YT12345 -ApiBaseUrl http://192.168.0.15:8000
```

Importante: `SEU_DEVICE_ID` e `SEU_IP_LOCAL` sao placeholders. Nao use `<` e `>` no comando.

## Android Studio

Se voce quer rodar pelo botao `Run`, abra a pasta `acolhe-mobile` no Android Studio e configure o Flutter SDK para:

```text
C:\Users\USER\Documents\Playground\tools\flutter
```

Depois do `setup-mobile.ps1`, aguarde o `Gradle Sync`, selecione o device e use o botao `Run`.

Guia completo:

- [../docs/android-studio-run.md](../docs/android-studio-run.md)

## Troubleshooting rapido

Se o Android Studio mostrar:

```text
Unknown run configuration type FlutterRunConfigurationType
```

quase sempre significa que o plugin `Flutter` ainda nao esta ativo no IDE, ou que a pasta aberta foi `android` em vez de `acolhe-mobile`.

Checklist:

- abra `C:\Users\USER\Documents\Playground\Acolhe\acolhe-mobile`;
- habilite os plugins `Flutter` e `Dart`;
- configure o Flutter SDK em `C:\Users\USER\Documents\Playground\tools\flutter`;
- reinicie o Android Studio;
- se precisar, recrie a configuracao em `Run > Edit Configurations > + > Flutter`.
