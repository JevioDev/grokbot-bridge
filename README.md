# grokbot-bridge

Локальный runtime-мост для Grok Bot. Проект подключает установленный Grok Bot
к локальному Computer desktop, shim-серверу и выбранной модели.

Поддерживаются Linux и Windows 10/11 с Docker Desktop.

## Возможности

- локальный запуск Grok Bot и agent loop;
- потоковый текст, tool calls и состояние reasoning;
- Codex OAuth через существующую сессию `codex login`;
- custom OpenAI-compatible endpoint;
- выбор модели в настройках приложения;
- локальный Chrome/XFCE Computer desktop с noVNC;
- Windows-запуск через PowerShell.

Интеграция использует undocumented API Grok Bot и может потребовать обновлений
после изменения desktop-приложения.

## Требования

### Linux

- установленный Grok Bot;
- Node.js 22.12 или новее;
- Docker с запущенным daemon;
- OpenSSL и curl;
- `codex login` для Codex-моделей или API-ключ OpenAI-compatible провайдера.

### Windows

- Windows 10/11;
- Grok Bot for Windows;
- Node.js 22.12 или новее;
- Docker Desktop с Linux containers;
- OpenSSL и curl (обычно доступны через Git for Windows);
- Codex CLI с выполненным `codex login` или API-ключ провайдера.

По умолчанию Windows-скрипты ищут приложение в стандартных папках. Если оно
установлено иначе, задайте `GROKBOT_APP` и при необходимости
`GROKBOT_RESOURCES`.

## Быстрый запуск

### Linux

```bash
git clone https://github.com/JevioDev/grokbot-bridge.git
cd grokbot-bridge
npm ci
npm run setup
cp .env.example .env
./run-all.sh
```

### Windows PowerShell

```powershell
git clone https://github.com/JevioDev/grokbot-bridge.git
cd grokbot-bridge
npm ci
npm run setup
Copy-Item .env.example .env
.\run-all.ps1
```

`npm run setup` создаёт локальные TLS-сертификаты и определяет runtime
установленного Grok Bot. Эти файлы не добавляются в Git.

### Совместимость версии Grok Bot

Bridge поддерживает два режима:

- `legacy` — извлекает `dist/host/host-main.cjs` из `resources/app.asar`;
- `modern` — использует встроенный `node-agent-coordinator` новой сборки и
  подключает его к Computer gateway на `127.0.0.1:1340`.

Windows-сборка Grok Bot `0.47.0` использует `modern` режим. Для него Docker
контейнер должен публиковать порт `1340`.

Если setup сообщает, что отсутствуют оба runtime, установите совместимую
сборку Grok Bot или задайте `GROKBOT_RESOURCES` на другой каталог ресурсов.

Первый запуск Computer скачивает Docker-образ размером несколько гигабайт.
После запуска takeover desktop доступен по адресу:
<http://127.0.0.1:6080/vnc.html>.

Проверка окружения:

```text
npm run doctor
```

## Архитектура

```text
Grok Bot UI ──► host gateway (:8550) ──► shim (:8443) ──► модель
     │                 │
     │                 └── agent loop, shell, files и tools
     │
     └── Computer container (:6080 noVNC, :1337 exec daemon)
```

- `run-recon.sh` и `run-recon.ps1` запускают desktop с изолированным профилем;
- `run-host.sh` и `run-host.ps1` запускают извлечённый host runtime;
- `shim/server.mjs` обслуживает авторизацию, модели и Connect inference;
- `computerctl.sh` и `computerctl.ps1` управляют Computer-контейнером;
- `run-*.ps1` предназначены для Windows.

Все сервисы привязаны к `127.0.0.1`. Не открывайте их наружу без отдельной
защиты.

## Настройка моделей

Модели объявляются в `models.json`:

```json
{
  "default": "Local Qwen",
  "models": {
    "Local Qwen": {
      "provider": "openai-compatible",
      "base_url": "http://127.0.0.1:1234/v1",
      "model": "qwen2.5-vl",
      "auth": false,
      "timeout_ms": 180000
    },
    "OpenRouter model": {
      "provider": "openai-compatible",
      "base_url": "https://openrouter.ai/api/v1",
      "model": "provider/model-id",
      "env_key": "OPENROUTER_API_KEY"
    }
  }
}
```

Для endpoint с авторизацией добавьте ключ в `.env`:

```dotenv
OPENROUTER_API_KEY=your-key-here
```

Не храните API-ключи в `models.json`.

Для OpenAI-compatible моделей shim отправляет запросы на:

```text
{base_url}/chat/completions
```

Поддерживаются streaming SSE, function/tool calling и изображения. Доступны
дополнительные параметры:

- `auth: false` — не добавлять Bearer-заголовок;
- `extra_headers` — дополнительные HTTP-заголовки;
- `timeout_ms` — timeout запроса в миллисекундах.

## Как работают tools

1. Grok Bot отправляет Connect/protobuf-запрос в shim.
2. Shim преобразует описание tools в формат OpenAI Chat Completions.
3. Модель возвращает streaming `tool_calls`.
4. Grok Bot выполняет tool: shell, файлы, Computer или `SendMessage`.
5. Результат tool отправляется модели следующим сообщением.
6. Скриншоты Computer передаются как `image_url`.

Обычный текст модели является внутренним ответом agent loop. Чтобы показать
сообщение пользователю, модель должна вызвать `SendMessage`.

## Команды

### Linux

```bash
./run-all.sh
./computerctl.sh status
./computerctl.sh open
./computerctl.sh logs
./shimctl.sh status
./shimctl.sh restart
npm run check
npm test
```

### Windows PowerShell

```powershell
.\run-all.ps1
.\computerctl.ps1 status
.\computerctl.ps1 open
.\computerctl.ps1 logs
.\shimctl.ps1 status
.\shimctl.ps1 restart
npm run check
npm test
```

Для отладки компоненты можно запускать отдельно:

```powershell
.\computerctl.ps1 start
.\shimctl.ps1 restart
.\run-host.ps1
.\run-recon.ps1
```

`run-all.ps1` ждёт доступности host gateway на TCP-порту `8550` перед запуском
Grok Bot. При завершении он останавливает только host, shim и Computer,
которые были подняты этим запуском; уже работавшие компоненты остаются
запущенными.

## Проверка

```text
npm run check
npm test
```

## Структура репозитория

- `shim/` — protobuf, inference adapters, model picker и сервер;
- `scripts/` — setup, doctor и platform helpers;
- `models.json` — каталог моделей без credentials;
- `run-*.sh` — Linux launchers;
- `run-*.ps1` — Windows launchers;
- `computerctl.*` — управление Computer-контейнером;
- `test/` — unit-тесты.

Следующие файлы намеренно не версионируются: `host/`, `certs/`, `appdata/`,
`state/`, `logs/`, `node_modules/` и `.env`.

## Безопасность

- изолированный профиль Grok Bot не изменяет основной профиль приложения;
- prompt и ответы модели могут отправляться выбранному провайдеру;
- логи могут содержать prompt, аргументы tools и пути к файлам;
- noVNC даёт управление Computer desktop, поэтому оставляйте его на loopback.

Сообщения об уязвимостях описаны в `SECURITY.md`.

## Лицензия

Исходный код распространяется по лицензии ISC. Grok Bot, Docker image и
сторонние model services регулируются условиями их владельцев.

## Credits

Проект основан на [codeaashu/grokbot-shim](https://github.com/codeaashu/grokbot-shim).
Поддержка Windows и дополнительные OpenAI-compatible интеграции поддерживаются
JevioDev.
