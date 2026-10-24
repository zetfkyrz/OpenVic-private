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

## Параметры симуляции (common/openvic_defines.lua)

Все настраиваемые числа дополнений OpenVic (ИИ, население, политика и восстания, колонизация, войны, мир, исследования,
заводы и запасы правительства) лежат в **группах `ov_*` файла `common/openvic_defines.lua`** (необязательный; синтаксис и
парсер как у `defines.lua`, моды переопределяют файл целиком — берётся первый найденный). Значения по умолчанию заданы в
`extension/deps/openvic-simulation/src/openvic-simulation/defines/OpenVicDefines.hpp` и равны прежним константам кода.
- Полный список ключей с диапазонами: `docs/openvic_defines.example.lua` (генерируется: `openvic-simulation.headless -b <Vic2> -D <файл>`).
- Новый параметр = одна строка `INT/FIXED/RATE/DOUBLE(КЛЮЧ, поле, значение по умолчанию, мин, макс)` в списке своей группы, дальше
  `instance_manager.definition_manager.get_define_manager().get_openvic_defines().<группа>.<поле>`. Не хардкодь числа игрового баланса.
- `RATE` — доля с точностью до 1/10000 (`Rate(25, 100)` = 0.25): `rate.of(x)` даёт ровно тот же `fixed_point_t`, что `x * 25 / 100`.
- Хеш всех итоговых значений (`get_hash()`, `GameSingleton.get_defines_hash()`) пишется в заголовок сохранения; при загрузке
  несовпадение версии симуляции/хеша даёт предупреждение «открыть всё равно» (формат 1 мигрируется). TODO: проверка хеша в
  рукопожатии мультиплеера (мультиплеера пока нет).
- Неизвестный ключ, не число или значение вне диапазона → предупреждение с именем файла и ключа, берётся значение по умолчанию.

## Автотесты

Одна команда (нужен собранный headless-исполняемый файл симуляции и, для тестов на настоящей игре, папка Victoria 2):

```bash
python tools/run_tests.py                       # найти исполняемый файл и папку Vic2 самому
python tools/run_tests.py --build               # сначала собрать симуляцию (out/build/sim-selftest, без Godot)
python tools/run_tests.py --vic2 "<путь>" --exe <openvic-simulation.headless>
python tools/run_tests.py --pure-only           # только проверки без файлов игры
```
Папка Vic2 берётся из `--vic2`, переменной `OPENVIC_VIC2_PATH`, `vic2.cfg` игры или папки `Victoria 2 Heart of Darkness` в корне. Код выхода 0 —
всё прошло. Сами проверки — `extension/deps/openvic-simulation/src/headless/SelfTest.cpp` (вызов напрямую: `openvic-simulation.headless
--selftest-pure` / `-b <Vic2> --selftest`; тоже зарегистрированы в CTest, если задан `OPENVIC_VIC2_PATH` при конфигурации). Что проверяется:
доли `Rate` (то же число, что `x * n / d`), чтение и диапазоны `openvic_defines.lua`, текст реплея и заголовок сохранения (версии, хеш,
миграция формата 1), **детерминизм** (два прогона с одними командами — одно состояние и одна история действий), **сохранение/загрузка**
(состояние после загрузки = состоянию до сохранения, игра идёт дальше так же), **сохранение денег** (журнал `MoneyLedger` замкнут,
деньги растут только от золота, стартовых бюджетов новых заводов и округления рынка). Время: около 1.5 минуты.
Новое состояние, которое симуляция помнит между днями/месяцами, держи в `InstanceManager`, а не в `static` — иначе тест детерминизма
(и загрузка сохранения после другой игры) упадёт. Деньги двигай только через места с «крючками» `MoneyLedger::record` (см. `BUGS_FIXED.md`).

Ручной контроль «значения по умолчанию не изменили игру» (этап 1): строки `CHECKSUM` у `headless -b <Vic2> -e 60`, `-A -e 1`, `-P -X -e 400`
до и после правки должны совпадать (`-C` печатает CHECKSUM каждый день, чтобы найти первый день расхождения).
