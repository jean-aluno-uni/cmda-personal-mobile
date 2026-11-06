# CMDA Personal, aplicativo Android

Aplicativo mobile do CMDA Personal, feito em Flutter. Ele se conecta por Bluetooth a um adaptador OBD2 ELM327, lê os dados do veículo, envia cada leitura para a API do [cmda-personal-backend](https://github.com/jean-aluno-uni/cmda-personal-backend) e mostra as mesmas telas do frontend web, com dados reais da API.

Para demonstrar sem carro, o notebook roda o [cmda-personal-simulador](https://github.com/jean-aluno-uni/cmda-personal-simulador), que se comporta como um ELM327.

## Instalar o APK

1. Baixe o `app-release.apk` na página de [Releases](https://github.com/jean-aluno-uni/cmda-personal-mobile/releases) deste repositório.
2. Abra o arquivo no celular e permita a instalação de fontes desconhecidas quando o Android pedir.
3. Na primeira vez que abrir a tela de conexão, permita o acesso a dispositivos próximos.

Requer Android 7.0 ou superior.

## Como funciona

```
notebook ou carro                       celular                          notebook
ELM327 ou simulador  <- Bluetooth ->  aplicativo CMDA  <- HTTP JSON ->  API FastAPI + MySQL
```

1. O usuário entra com e-mail e senha, e o app guarda o token JWT e o veículo devolvido por `GET /vehicles`.
2. Na tela de conexão, o usuário escolhe o notebook ou o adaptador já pareado no Android.
3. O app inicializa o adaptador com `ATZ`, `ATE0`, `ATL0`, `ATS0`, `ATH0` e `ATSP0` e avisa a API com `POST /vehicles/{id}/connect`.
4. A cada 2 segundos pede RPM `010C`, velocidade `010D`, líquido de arrefecimento `0105`, óleo `015C`, ar de admissão `010F`, tensão `0142` e códigos de falha `03`.
5. Converte as respostas e envia a leitura em `POST /vehicles/{id}/readings`. Cada código de falha novo vira um alerta em `POST /vehicles/{id}/alerts`.
6. Se o adaptador parar de responder, o app avisa a API com `disconnect` e tenta reconectar a cada 5 segundos.

As telas consultam a API a cada 3 segundos, então mostram o que está gravado no banco, inclusive os alertas e o diagnóstico que a API gera a partir das leituras.

## Telas

| Tela | Rotas da API |
|---|---|
| Login | `POST /auth/login`, `GET /vehicles` |
| Recuperar senha, código e nova senha | `POST /auth/password/forgot`, `otp/resend`, `otp/verify`, `reset` |
| Painel inicial | `GET /users/me`, `GET /vehicles/{id}`, `GET /vehicles/{id}/telemetry/latest`, `GET /vehicles/{id}/alerts/summary` |
| Conexão com o veículo | Bluetooth, `POST /vehicles/{id}/connect`, `disconnect`, `readings` e `alerts` |
| Condições do motor | `telemetry/latest`, `temperature/history`, `diagnostics` |
| RPM | `telemetry/latest`, `diagnostics?indicadores=RPM,Velocidade` |
| Alertas | `alerts/summary` e `alerts` com filtro de 24h, 7 dias e 30 dias |
| Diagnóstico | `diagnostics`, `telemetry/latest` |
| Perfil | `GET /users/me`, `GET /vehicles/{id}`, `POST /auth/logout` |

## Estrutura

```
lib/
├── main.dart          rotas e tema
├── api.dart           apiCall, sessão e tratamento de erros da API
├── obd.dart           conexão Bluetooth e protocolo ELM327
├── widgets.dart       cabeçalho, cartões, gráficos e navegação
└── telas/             uma tela por arquivo
```

## Rodar a demonstração

1. No notebook, suba a API escutando na rede com `uvicorn app.main:app --host 0.0.0.0 --port 8000` e libere a porta 8000 no firewall.
2. Ligue o celular e o notebook na mesma rede. O roteador do próprio celular é o mais seguro.
3. Pareie o celular com o notebook e rode o simulador, conforme o README dele.
4. No app, abra Servidor da API na tela de login e informe `http://<ip-do-notebook>:8000/api/v1`.
5. Entre com `demo@cmda.app` e `Demo@1234`, toque no botão de Bluetooth do painel e conecte no notebook.

## Gerar o APK

Com o Flutter e o Android SDK instalados.

```bash
flutter pub get
flutter build apk --release
```

O arquivo sai em `build/app/outputs/flutter-apk/app-release.apk`.
