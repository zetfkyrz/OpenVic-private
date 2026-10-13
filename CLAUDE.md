# OpenVic (личный форк) — руководство для Claude

Фанатский ремейк Victoria 2 на Godot 4.7.2 + C++ GDExtension. Это **приватная рабочая копия** официального проекта.
Подробный статус, историю задач и roadmap читай в [docs/handoff/PROGRESS_AND_ROADMAP.md](docs/handoff/PROGRESS_AND_ROADMAP.md) — начни с него.

Язык общения с пользователем: **русский** (идентификаторы и код — на английском).

## Репозитории и remotes

| Что | Где |
|---|---|
| Основной репо (`origin`) | `github.com/zetfkyrz/OpenVic-private`, ветка `master` |
| Оригинал (`upstream`) | `github.com/OpenVicProject/OpenVic` |
| Симуляция (сабмодуль `extension/deps/openvic-simulation`) | `github.com/zetfkyrz/OpenVic-Simulation-private`, ветка **`diplomacy-actions`** |
| Оригинал симуляции (`upstream` в сабмодуле) | `github.com/OpenVicProject/OpenVic-Simulation` |

- Обновления из оригинала: `git fetch upstream && git merge upstream/master` (в корне и отдельно в сабмодуле).
- Работая над симуляцией: коммить **сначала в сабмодуле** (ветка `diplomacy-actions`), пушь, и только потом коммить обновлённый
  указатель сабмодуля в основном репо. Иначе основной репо будет ссылаться на несуществующий коммит.
- Сабмодули `lexy-vdf` и `openvic-dataloader` внутри симуляции указывают на оригинал (их не меняли).
- Коммиты подписывай `Signed-off-by` (`git commit -s`) и трейлером `Co-Authored-By: Claude ...`.
- **Не коммить** `game/addons/godot_ai/` и правки `game/project.godot`, добавленные плагином godot-ai (локальный инструмент
  для управления редактором, не часть проекта).

## Структура

- `game/` — проект Godot (GDScript, сцены, GUI из файлов Victoria 2). Главная сцена `res://src/Systems/Startup/GameStart.tscn`.
- `extension/src/openvic-extension/` — GDExtension: мост между Godot и симуляцией (`singletons/`, `classes/`, `components/`).
- `extension/deps/openvic-simulation/` — сама симуляция на C++ (данные Vic2, экономика, страны, дипломатия, армии).
- Экраны UI: `game/src/UI/Session/*.gd` + C++ данные в `PlayerSingleton` / `MenuSingleton` / `*Menu.cpp`.
- Команды игрока идут через `GameAction` (`misc/GameAction.hpp`): добавляется строка `X(...)` и обработчик в `GameAction.cpp`,
  из расширения вызывается `instance_manager->queue_game_action<имя_argument_t>(...)`.

## Сборка

Требуется C++20 (Windows: MSVC **14.44**, 14.38 не компилирует код симуляции), CMake 3.28+, Ninja, Python 3.

```bash
git submodule update --init --recursive
cmake --preset windows-x64-editor        # Linux: linux-x64-editor, macOS: macos-universal-editor
cmake --build --preset windows-x64-editor
```

Windows: запускать из окружения MSVC, например `vcvars64.bat -vcvars_ver=14.44`. Результат копируется в `game/bin/openvic/`.
Из редактора Godot подхватывается именно **editor**-вариант библиотеки; после пересборки редактор нужно перезапустить
(или запускать проект заново), горячая перезагрузка работает не всегда.

## Запуск игры

Нужна установленная Victoria II: Heart of Darkness. Путь хранится в `user://vic2.cfg` (Windows: `%APPDATA%/OpenVic/vic2.cfg`,
секция `[victoria_2]`, ключ `base_defines_path`) или передаётся `-- --search-path "<путь>"`. Загрузка данных ~25–60 секунд.

## Что можно делать без Godot и без файлов Victoria 2 (облако)

Можно: править C++ и GDScript, **собирать расширение** (проверка компиляции — основная обратная связь), писать документацию,
рефакторить, добавлять игровые действия и данные для UI. Нельзя: запускать игру, смотреть интерфейс, тестировать экономику
(нет данных Vic2 и дисплея). Детали и приёмы — в разделе «Работа без Godot» файла roadmap.

## Важные грабли (коротко, подробности в roadmap)

- `fixed_point_t` умножается/делится только на целые ≤ 4 байт (`int32_t`), `int64_t` не компилируется.
- Колбэки рынка (`BuyUpToOrder`, `MarketSellOrder`) исполняются **параллельно по товарам** — писать только в «свой» слот заказа,
  обрабатывать результат на следующем тике.
- Окна GUI с `orientation = CENTER`: позиция дочерних элементов отсчитывается от центра родителя.
- Иконки товаров (`GFX_resources`): кадр = `good_index + 2`.
- Не редактируй GDScript/C++ «вслепую» без сборки: после изменений C++ всегда собирай расширение.
