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
6. Se o adaptador parar de responder, o app avisa a API com `disconnect` e tenta reconectar a cada 6 segundos, por no máximo 8 tentativas. Depois disso, o app para de tentar e o usuário conecta de novo pela tela de conexão.

As telas consultam a API a cada 3 segundos, então mostram o que está gravado no banco, inclusive os alertas e o diagnóstico que a API gera a partir das leituras.

O visual segue o design system do frontend web e dos protótipos do documento, com a cor `#C2182B`, o cabeçalho em degradê com o sino de alertas e a foto do perfil, e a navegação inferior com Home, Diagnóstico e Perfil. A foto do veículo e a foto do perfil ficam em `assets/img`, as mesmas usadas no frontend web.

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

## Roteiro completo da demonstração

Este é o passo a passo para montar a demonstração do jeito que o grupo usa na apresentação, com o notebook fazendo o papel do carro e o celular rodando o app. Precisa de um notebook Windows com Bluetooth, Python 3.14, MySQL 8 e um celular Android 7.0 ou superior.

### 1. Banco e API no notebook

Siga o README do [cmda-personal-backend](https://github.com/jean-aluno-uni/cmda-personal-backend) para criar o ambiente virtual, configurar o `.env`, aplicar as migrations e rodar o seed. Depois suba a API escutando na rede, e não só em `127.0.0.1`.

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 2. Liberar a API para o celular

O Windows bloqueia conexões vindas de outros aparelhos, principalmente quando o Wi-Fi está marcado como rede pública. Abra o PowerShell como administrador e rode os dois comandos abaixo uma única vez. O primeiro desliga regras antigas que bloqueiam o Python, e o segundo libera a porta da API.

```bash
Get-NetFirewallRule -DisplayName "python.exe" | Where-Object Action -eq Block | Disable-NetFirewallRule
```

```bash
New-NetFirewallRule -DisplayName "CMDA API 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
```

Para desfazer depois da apresentação, rode `Remove-NetFirewallRule -DisplayName "CMDA API 8000"` como administrador.

### 3. Rede

Ligue o celular e o notebook no mesmo Wi-Fi. Redes de faculdade costumam isolar os aparelhos, então o mais seguro é ligar o notebook no roteador do próprio celular. Descubra o IP do notebook com o comando `ipconfig`, na linha Endereço IPv4 do adaptador Wi-Fi.

### 4. Bluetooth e simulador

1. Pareie o celular com o notebook nas configurações de Bluetooth.
2. No Windows, abra Configurações, Bluetooth e dispositivos, Dispositivos, Mais configurações de Bluetooth, aba Portas COM. Deixe **uma única** porta do tipo Entrada. Se não houver nenhuma, clique em Adicionar e escolha Entrada.
3. No celular, renomeie o notebook pareado para `OBDII`, para ele aparecer no app com o nome de um adaptador real.
4. Rode o simulador na porta de entrada, conforme o README do [cmda-personal-simulador](https://github.com/jean-aluno-uni/cmda-personal-simulador).

### 5. Aplicativo

1. Instale o APK da página de [Releases](https://github.com/jean-aluno-uni/cmda-personal-mobile/releases/latest).
2. Na tela de login, abra Servidor da API e informe `http://<ip-do-notebook>:8000/api/v1`.
3. Entre com `demo@cmda.app` e `Demo@1234`.
4. No painel, toque em Conectar ao veículo, permita o acesso a dispositivos próximos e escolha o `OBDII`.

O terminal do simulador mostra `aplicativo conectado na COMx` e, a cada 2 segundos, uma linha com os valores enviados. As telas do app atualizam sozinhas.

### Problemas comuns

| Sintoma | Causa e solução |
|---|---|
| Não foi possível conectar ao servidor | Celular em outra rede, IP errado ou firewall bloqueando. Confira o IP com `ipconfig` e rode os comandos do passo 2 |
| Não foi possível conectar no adaptador | Simulador fechado ou escutando na porta errada. Deixe só uma porta de Entrada e rode o simulador nela |
| O Android mostra Não é possível conectar-se a OBDII | Aviso do próprio Android quando o adaptador não responde, normal durante o cenário de queda do simulador |
| Nenhum dispositivo pareado | O notebook não foi pareado ou o Bluetooth do celular está desligado |
| Telas sem dados com o veículo conectado | A API não está recebendo leituras. Confira se o simulador mostra as linhas de envio |

Se o Bluetooth falhar na hora da apresentação, rode o simulador no modo reserva com `--api`, que manda as leituras direto para a API, e as telas do app continuam mudando.

## Gerar o APK

Com o Flutter e o Android SDK instalados.

```bash
flutter pub get
flutter build apk --release
```

O arquivo sai em `build/app/outputs/flutter-apk/app-release.apk`.
