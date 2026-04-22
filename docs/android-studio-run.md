# Android Studio Run

Para rodar o `Acolhe` pelo botao `Run` do Android Studio, use este fluxo:

## 1. Preparar o projeto uma vez

Na raiz do projeto:

```powershell
cd C:\Users\USER\Documents\Playground\Acolhe
powershell -ExecutionPolicy Bypass -File .\setup-mobile.ps1
```

Isso gera as pastas nativas do Flutter, incluindo `android/`, e baixa as dependencias do app.

## 2. Abrir o projeto certo

No Android Studio, abra esta pasta:

```text
C:\Users\USER\Documents\Playground\Acolhe\acolhe-mobile
```

Nao abra a raiz monorepo `Acolhe` se a intencao for usar o botao `Run` do app mobile.

## 3. Configurar o Flutter SDK

No Android Studio:

1. `File > Settings > Languages & Frameworks > Flutter`
2. Em `Flutter SDK path`, use:

```text
C:\Users\USER\Documents\Playground\tools\flutter
```

Se o Android Studio pedir o plugin `Dart`, instale tambem.

## 4. Aguardar sincronizacao

Depois de abrir o projeto:

- aguarde o `Gradle Sync`;
- aguarde o `Pub get`;
- confirme que o device aparece na barra superior.

## 5. Rodar pelo botao Run

Com o tablet conectado ou um emulador aberto:

1. selecione o dispositivo na barra superior;
2. clique no botao `Run`.

## 6. Rodar com backend local

Se quiser que o app fale com o backend do computador, suba o backend em rede local:

```powershell
cd C:\Users\USER\Documents\Playground\Acolhe
powershell -ExecutionPolicy Bypass -File .\start-backend.ps1 -Host 0.0.0.0
```

No Android Studio, edite a configuracao de execucao do Flutter e adicione em `Additional run args`:

```text
--dart-define=API_BASE_URL=http://SEU_IP_LOCAL:8000
```

Exemplo:

```text
--dart-define=API_BASE_URL=http://192.168.0.15:8000
```

Se voce nao informar `API_BASE_URL`, o app roda com mocks locais.

## 7. Se o botao Run nao aparecer

Verifique:

- o projeto aberto e `acolhe-mobile`;
- o plugin `Flutter` instalado;
- o plugin `Dart` instalado;
- o caminho do Flutter SDK configurado;
- a pasta `android/` existe dentro de `acolhe-mobile`;
- um device Android esta disponivel.

## 8. Se aparecer "Unknown run configuration type FlutterRunConfigurationType"

Esse erro normalmente significa que o Android Studio ainda nao reconhece configuracoes de execucao Flutter.

Checklist rapido:

1. confirme que voce abriu `C:\Users\USER\Documents\Playground\Acolhe\acolhe-mobile`
   e nao apenas a subpasta `android`;
2. va em `File > Settings > Plugins` e confirme que `Flutter` esta instalado e habilitado;
3. confirme que o plugin `Dart` tambem esta instalado e habilitado;
4. va em `File > Settings > Languages & Frameworks > Flutter` e configure:

```text
C:\Users\USER\Documents\Playground\tools\flutter
```

5. reinicie o Android Studio;
6. se o erro continuar, remova a configuracao antiga `main.dart` no seletor de Run e crie outra em:
   `Run > Edit Configurations > + > Flutter`;
7. se o Windows reclamar de symlink/plugin, ative o `Developer Mode`:

```powershell
start ms-settings:developers
```

Depois disso, selecione `lib/main.dart` como entrypoint e clique em `Run`.
