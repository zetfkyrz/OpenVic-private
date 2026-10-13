# OpenVic — статус работ, история задач и план

Документ для передачи работы (в том числе Claude в облачном режиме без доступа к Godot).
Дата составления: 2026-10-13. Автор правок: Claude Sonnet 5.5 по задачам владельца репозитория.

## 1. Контекст

- Проект — фанатский ремейк Victoria 2 (разработчики оригинального OpenVic дали разрешение на работу), цель владельца: довести
  игру до играбельного состояния: экономика, население, армия, дипломатия, ИИ.
- Исходное состояние: «готова только карта» — на деле данные, карта и большая часть симуляции были, но не было собранного
  C++-расширения, не работал ряд экранов UI и не было войн/боёв/ИИ/заводов.
- Репозитории и правила работы с ними — в [CLAUDE.md](../../CLAUDE.md).

## 2. Что сделано (хронология задач владельца)

| # | Задача владельца | Результат |
|---|---|---|
| 1 | Посмотреть ошибки Godot, исправить, запустить игру | Причина: не было собранного GDExtension (`bin/openvic.gdextension` без DLL), сабмодули были пустые. Подтянул сабмодули, собрал расширение (MSVC 14.44, пресет `windows-x64-editor`), игра запускается из редактора |
| 2 | «failed to find victoria2», отключить проверку | Проверка не отключалась: без папки Vic2 игра не работает. Путь `C:\Program Files (x86)\Paradox Interactive\Victoria 2 Heart of Darkness` записан в `%APPDATA%\OpenVic\vic2.cfg` |
| 3 | Анализ билда: что есть и чего не хватает | Сделан разбор (см. раздел 4) |
| 4 | Дипломатия, ИИ «принимает всё, что я ему отправил» | `diplomatic_action` в симуляции, экран «Дипломатия», получатель всегда принимает (см. 3.1) |
| 5 | Свой приватный репозиторий + возможность брать обновления оригинала | Два приватных репозитория (основной и симуляция), remote `upstream` |
| 6 | Интерфейс мешает при открытии окон | Миникарта/кнопки карты и панель провинции скрываются при открытом экране управления |
| 7 | При выборе года выбирать страну, показывать как политическую карту | Лобби: политическая карта на дату сценария, выбор страны кликом (см. 3.2) |
| 8 | Экран технологий | Готов (см. 3.3) |
| 9 | Заводы и экран производства, «можно сделать своё, сложнее и интереснее» | Своя модель заводов в симуляции + экран Production на оригинальных шаблонах (см. 3.4) |
| 10 | «Ты сломал оригинальный интерфейс» (производство) | Экран переписан на оригинальные шаблоны Vic2 (регион, сооружения в ряд, «плюс», диалог постройки) |
| 11 | Подготовить передачу для облачного режима | Этот документ + `CLAUDE.md`, коммиты подписаны |

## 3. Реализованные фичи (технические детали)

### 3.1 Дипломатия
- **Симуляция:** `DiplomaticActionManager::execute_diplomatic_action(type_index, sender, receiver, context, instance_manager)`
  (`diplomacy/DiplomaticAction.cpp`) — проверка `allowed`, списание влияния, **политика ответа получателя (сейчас
  «принимает всё»)** в одном месте с комментарием `TODO`, затем `commit`. Игровое действие
  `diplomatic_action(country_index_t, country_index_t, uint32 type_index)`.
- Исправления в данных ванили-кода: `increase_relations`/`decrease_relations` были принудительно `allowed = false` (включены);
  `give_military_access` давал доступ в обратную сторону (исправлено).
- **Расширение:** `PlayerSingleton::get_diplomatic_action_identifiers()`, `get_diplomacy_country_list()` (индекс, имя, ранги,
  правительство, население, отношения, настроение), `get_diplomatic_relation(country_index)`, `send_diplomatic_action(country, action)`.
- **UI:** `game/src/UI/Session/DiplomacyMenu.gd` — список стран на шаблоне `diplomacy_country_info`, панель фактов,
  кнопки действий (шаблон `diplomacy_option`), видимость кнопок зависит от текущих отношений. Недоступные действия:
  `call_ally`, `command_units`, `justify_war`, `expel_advisors` (константа `_UNAVAILABLE_ACTIONS`).

### 3.2 Лобби и выбор страны
- `GameSingleton::setup_game` теперь вызывается **при выборе даты в лобби** (повторный вызов сбрасывает прежний экземпляр
  игры); страна по умолчанию — `ENG`. `start_game_session` требует игрока и выдаёт ему тестовое исследование.
- `LobbyMenu.gd`: ставит карте режим `mapmode_political`, центрирует камеру на столице, клик по провинции →
  `PlayerSingleton.set_player_country_by_province_number` (море и ничьи провинции игнорируются), имя — в
  `SelectedCountryNameLabel`.

### 3.3 Технологии
- `PlayerSingleton::get_technology_info()` (папки → области → технологии со статусом 0..3, текущее исследование, школа,
  очки), `start_research(index)`. UI: `TechnologyMenu.gd` на шаблонах `folder_window`, `tech_group`, `tech_window`.
- Не сделано: список изобретений (`possible_inventions`, `inventions` в окне технологии), эффекты технологии, описание
  (`<id>_desc` отсутствует в локализации).

### 3.4 Заводы (собственная модель, не копия ванили)
Файлы симуляции: `economy/production/FactoryInstance.{hpp,cpp}`, `map/State.{hpp,cpp}`, `map/MapInstance.cpp`,
`map/ProvinceInstance.*`, `misc/GameAction.*`.

Модель завода (`FactoryInstance`):
- у завода **свой бюджет**; стартовый капитал = 15 дней входов по текущим ценам (`FOUNDING_CAPITAL_DAYS`);
- **склад входов**, закупка на рынке (`BuyUpToOrder`) на 2 дня вперёд в пределах бюджета;
- **найм** из попов штата по `Job` типа производства (`amount` × `base_workforce_size` × уровень);
- выпуск = `base_output_quantity × level × занятость × throttle × input_fraction × efficiency`;
- **efficiency** (0.6–1.5) растёт при прибыли и падает при убытке; **throttle** (0.2–1) снижается при убытке;
- рабочие получают **50% добавленной стоимости** (`выручка − стоимость израсходованных входов`), капиталисты — 25% прибыли;
- **частная экспансия:** 45 прибыльных дней подряд и бюджет ≥ 1.5× стоимости → завод сам расширяется на 1 уровень;
- **закрытие:** 90 убыточных дней при минимальном throttle → `open = false` (игрок может открыть заново);
- результаты рыночных колбэков копятся в слотах заказа и **обрабатываются на следующем тике** (`settle`), т.к. колбэки
  исполняются параллельно по товарам;
- не учитываются эффекты работ (`THROUGHPUT/INPUT/OUTPUT`), бонусы технологий, субсидии, приоритет найма.

Интеграция: у `State` до 8 заводов (`FactoryInstance::MAX_FACTORIES_PER_STATE`); `MapInstance::factory_tick` вызывается из
`InstanceManager::tick` **после** `map_tick` (провинциальный тик обнуляет занятость) и до `market_instance.execute_orders()`;
стартовые заводы берутся из `state_building` истории провинций (`ProvinceInstance::pending_state_buildings`,
добавляются в `MapInstance::initialise_for_new_game`). Классы `FactoryProducer`/`ProductionType::is_valid_for_factory_in`
(теперь принимает `State const&`) — старый неиспользуемый код оставлен.

Действия: `build_factory(country, province, building_type)` — постройка или расширение на 1 уровень (деньги списываются из
казны сразу по рыночной цене `goods_cost` + `cost`, срок — `build_time` или 180 дней), `set_factory_open(..., bool)`.
Условия: штат принадлежит стране, тип разблокирован (`is_building_type_unlocked`), есть слот, хватает денег.

UI (`ProductionMenu.gd`): оригинальные шаблоны `state_info` → `factory_info_bounds` → `factory_info`, диалог `build_factory`
с `new_factory_option`; вспомогательные данные — `PlayerSingleton::get_production_info()`, `build_factory`, `set_factory_open`.

## 4. Что НЕ сделано (приоритеты)

1. **Войны и бои** — в симуляции нет сущностей войны/боя/осады; есть только `Wargoal`, `WarHistory`, флаг `at_war`.
   Нужно: объявление войны (`declare_war` сейчас лишь ставит флаг), мобилизация, перемещение армий (`UnitInstanceGroup::tick`
   частично), бой, оккупация, мирные договоры (`offer_peace` пустой), `call_ally` (заблокирован).
2. **ИИ** — есть флаг `CountryInstance::is_ai`, `AIDefines`; решений никто не принимает. Нужен хотя бы ИИ: постройка
   заводов, исследования, найм, дипломатия (ответы на предложения вместо «принимает всё»).
3. **Баланс экономики заводов:** стоимость постройки велика относительно казны (верфь 18 742 £ при ~470 £ на старте),
   часть товаров не имеет спроса (цемент, консервы — выпуск без выручки), зарплаты малы. Нужна калибровка и, возможно, расчёт
   спроса (стройка, армия, попы).
4. **UI производства:** скрыты вкладки «инвестиции», «производство товаров», «проекты попов», верхние кнопки
   (выбрать все, субсидии, закрыть/открыть все), фильтры/сортировка, `subsidise`, `priority`, `delete_factory`, всплывающие
   подсказки (employment_info, goods_cost_info), деталь «доступно рабочих» в диалоге.
5. **Дипломатия:** константы defines (`INCREASERELATION_*`, `DISCREDIT_DAYS`, `BANEMBASSY_DAYS`, стоимости сферы),
   вкладки «Великие державы», «Войны», «Кризис», оправдание войны (`justify_war`), реальная логика согласия.
6. **Население/армия UI:** в `PopulationMenu.cpp` (≈строки 869–915) не выведены: повышения/понижения, ассимиляция,
   миграция, доходы и потребности, формы повстанцев; `MilitaryMenu.cpp` — тестовые данные очереди найма и прогресса
   мобилизации; `TradeMenu.cpp` — тестовые «топ-производители» и общий рынок.
7. **Временные заглушки:** тестовое исследование в `GameSingleton::start_game_session`; выдача «преступности» провинциям
   по кругу в `setup_game`; страна по умолчанию `ENG`; нет загрузки из сохранений; бюджет — `TODO` по субсидиям/процентам.
8. **Сохранения:** заводы в сохранения не сериализуются (сериализации нет и у остальных частей).
9. **Колонии, национальные фокусы, события-попапы, морские юниты в портах** (`ModelSingleton` TODO).

## 5. Работа без Godot (облачный режим)

**Можно и полезно:**
- **Собирать расширение** (Linux: `cmake --preset linux-x64-editor && cmake --build --preset linux-x64-editor`, нужны
  gcc ≥ 13 или clang ≥ 17, Ninja, интернет для зависимостей CMake). Сборка — главная проверка корректности C++.
  На Windows тот же код компилируется MSVC 14.44; GCC/Clang могут требовать правок `#include`.
- Править симуляцию: ИИ, войны, баланс, действия `GameAction`, данные для UI (`PlayerSingleton`).
- Править GDScript — но без запуска нельзя проверить поведение; сверяйся с существующими экранами и именами элементов из
  `interface/*.gui` Vic2 (в облаке файлов Vic2 нет, имена элементов перечислены ниже).
- Можно скачать **Godot 4.7.2 (Linux, headless)** и собранное расширение, прогнать `godot --headless --path game --quit`
  для проверки парсинга скриптов (без данных Vic2 игра дойдёт до диалога выбора папки — этого достаточно для parse-ошибок).
- Для симуляции есть `openvic-simulation.headless` и тесты (`extension/deps/openvic-simulation/tests`), но им нужны
  файлы Vic2, поэтому в облаке они не запустятся; юнит-тесты без данных — можно.

**Нельзя:** запускать игру, смотреть экраны, проверять экономику/баланс, подбирать координаты GUI.
Любую правку UI помечай в описании PR как «не проверено визуально», а баланс — как «требует прогона у владельца».

**Рекомендуемый процесс в облаке:** маленькие шаги → сборка расширения → коммит `-s` → в описании что именно проверено
(компиляция) и что должен проверить владелец локально (какой экран/сценарий). Владелец потом локально делает `git pull`,
пересобирает (Windows, MSVC 14.44) и тестирует.

## 6. Справочник по подводным камням

**C++**
- `fixed_point_t` не умножается/делится на `int64_t`; используй `int32_t` (`from_fraction(int32, int32)`).
- Константы `fixed_point_t::_0_50` и т.п. — статические объекты; не используй их в инициализаторах глобальных переменных.
- Колбэки `place_market_sell_order`/`place_buy_up_to_order` исполняются при `execute_orders` параллельно по товарам.
- `State`/`ProvinceInstance` стабильны в памяти (`memory::colony`), `std::vector` с `FactoryInstance` нельзя (указатель в колбэке).
- В `GameAction.hpp` у последней строки X-макроса нет `\`; при добавлении строки дописывай `\` у предыдущей.
- Новые `.cpp` в симуляции подхватываются `file(GLOB_RECURSE ... CONFIGURE_DEPENDS)`; в расширении — проверь `CMakeLists.txt`.

**GDScript / GUI Vic2**
- `add_gui_element("файл", "окно")`, дальше доступ `./окно/...`; `GUINode.generate_gui_element(файл, шаблон)` создаёт копию.
- Окна с `orientation = CENTER` (напр. `factory_info`): позиция относительно центра родителя; для ряда используй
  `-ширина_родителя/2 + ширина_элемента/2 + i*ширина`.
- `GUIListBox.clear_children(n)` оставляет первые n; элементы можно переиспользовать.
- Иконки товаров — `set_icon_index(good_index + 2)`; кадры `GFX_employment_ratio` — 11 (1..11).
- Цвета текста в `GUILabel`: `§G…§!`, `§R`, `§Y`, `§W`.
- Элементы фабрики (`factory_info`): `level`, `upgrade`, `output`, `input_0..3`, `input_N_lack2`, `income`, `income_icon`,
  `employment_ratio`, `prod_factory_inprogress_bg`, `build_factory_progress`, `upgrade_factory_progress`,
  `progress_overlay_16_64`, `closed_overlay`, **`factory_closed_text`**, `open_close`, `delete_factory`, `subsidise`, `priority`,
  `prod_cancel_progress`.
- Экран дипломатии: `diplomacy_country_info`, `diplomacy_option`, `diplomacy_country_facts`; технологий: `folder_window`,
  `tech_group`, `tech_window`, `selected_tech_window`; производства: `state_info`, `factory_info`, `build_factory`,
  `new_factory_option`.

**Локальная отладка через godot-ai MCP (для сессий у владельца)**
- Клики `input_mouse` идут в пикселях окна (2546×1302 при embedded окне); при мыши у верхнего/нижнего края камера
  прокручивается (edge scrolling) — движение/клики делать вне краёв. `F1`/`F3` — горячие клавиши экранов, повторное нажатие
  закрывает экран. Скриншоты большого размера иногда падают — брать ≤1000 px.
- Логи игры: `%APPDATA%\OpenVic\logs\godot.log` (spdlog `[info]` выводится туда же).

## 7. Список изменённых файлов

Основной репозиторий (относительно `OpenVicProject/OpenVic` @ c063ac6):
`.gitmodules`, `CLAUDE.md`, `docs/handoff/PROGRESS_AND_ROADMAP.md`,
`extension/src/openvic-extension/singletons/{GameSingleton.cpp,PlayerSingleton.cpp,PlayerSingleton.hpp}`,
`game/src/UI/GameMenu/LobbyMenu/LobbyMenu.gd`,
`game/src/UI/Session/{DiplomacyMenu,Menubar,ProductionMenu,ProvinceOverviewPanel,TechnologyMenu}.gd`.

Симуляция (относительно `OpenVicProject/OpenVic-Simulation` @ b7f5feb2, ветка `diplomacy-actions`):
`InstanceManager.cpp`, `country/CountryInstance.hpp`, `diplomacy/DiplomaticAction.{cpp,hpp}`,
`economy/production/FactoryInstance.{cpp,hpp}` (новые), `economy/production/ProductionType.{cpp,hpp}`,
`map/{MapInstance,ProvinceInstance,State}.{cpp,hpp}`, `misc/GameAction.{cpp,hpp}`.
