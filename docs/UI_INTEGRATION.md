# Как подключить интерфейс к движку (кредиты, производство, дипломатия)

Составлено в этапе 4 (4b, 4f, кредиты). Здесь: что уже умеет движок, где лежит код, какие вызовы мост (`PlayerSingleton`) отдаёт
интерфейсу и что осталось сделать в сценах/скриптах. Все пути — от корня репозитория; сама симуляция — в сабмодуле
`extension/deps/openvic-simulation/src/openvic-simulation/` (ниже `SIM/`).

## 0. Общая схема

```
GDScript (game/src/UI/Session/*.gd)
   │  читает: PlayerSingleton.get_*()  → Dictionary / Array (копия данных на момент вызова)
   │  командует: PlayerSingleton.<действие>()  → queue_game_action<...>  → GameAction (SIM/misc/GameAction.hpp/.cpp)
   ▼
extension/src/openvic-extension/singletons/PlayerSingleton.hpp/.cpp   ← мост, методы объявлены и привязаны в _bind_methods
   ▼
SIM/  (InstanceManager, CreditManager, FactoryInstance, ...)
```

* Читать данные: в `_ready()` подписаться `GameSingleton.gamestate_updated.connect(_refresh)` и перечитывать только когда окно видно
  (пример — `CreditPanel.gd`, функция `_refresh`).
* Команда возвращает `true`, если действие поставлено в очередь. Результат виден после следующего `gamestate_updated`
  (в паузе действия выполняются при следующем шаге/обновлении).
* Новый метод моста = 3 места: объявление в `PlayerSingleton.hpp` (с комментарием о формате данных), реализация в `.cpp`, привязка
  `OV_BIND_METHOD(...)` в `_bind_methods` (список в начале `.cpp`). После правок C++ нужна пересборка расширения.
* Новое игровое действие = строка `X(...)` в `SIM/misc/GameAction.hpp` + обработчик `VariantVisitor::operator()` в `GameAction.cpp`.
* Строки интерфейса: `tr("КЛЮЧ")`, значения в `game/assets/localisation/locales/{ru_RU,en_GB,en_US}/*.csv` (формат `КЛЮЧ;значение`,
  символ `;` внутри значения нельзя). Для кредитов — `credit.csv`.

## 1. Кредиты

**Что готово (логика):** `SIM/economy/credit/Credit.hpp/.cpp`, подробности и формулы — `docs/CREDITS.md`.

**Что готово (окно):** `game/src/UI/Session/CreditPanel.gd` — окно с четырьмя вкладками, собранное из стандартных контролов Godot
(`Tree`, `SpinBox`, `TabContainer`) поверх `Vic2Window.gd` (рамка, закрытие, перетаскивание). Открывается из `BudgetMenu.gd`
(`_open_credit_panel`). Работает на данных моста, но **не использует родные текстуры/кнопки Victoria 2**.

**Что сделать вам (стиль Vic2):**
1. В Vic2 нет готового `.gui` окна кредитов — придётся нарисовать своё. Варианты: (а) сделать `interface/credits.gui` в формате игры
   и загрузить его через `GUINode` (как `ProductionMenu.gd`, `DiplomacyMenu.gd`: `_gui_file = "..."`, потом
   `get_gui_label_from_nodepath`, `get_gui_icon_button_from_nodepath`); (б) оставить программное окно и заменить контролы на
   `GUIIconButton` / `GUILabel` / `GUIListBox` с нужными спрайтами (`GFX_*` из `interface/*.gfx`).
2. Вкладки: Vic2 использует кнопки-вкладки со спрайтом `GFX_prod_tab_button` (как `gp_info`, `war_info` в `country_diplomacy.gui`) — заменить
   `TabContainer` в `CreditPanel._ready` на ряд таких кнопок, переключающих `Control`ы-вкладки.
3. Таблицы: заменить `Tree` на `GUIListBox` (как в `DiplomacyMenu.gd`: `_country_listbox`) или на шаблонные строки; данные те же
   (ключи — в комментарии `PlayerSingleton.hpp`, раздел «Credits»).
4. Привязка данных не меняется: вкладка → вызов моста:

| Вкладка | Читать | Команды |
|---|---|---|
| «Главная» | `get_credit_overview()` → `internal`, `external` | `repay_loan(id, amount)`, `withdraw_credit_offer(id)` |
| «Выдать внутренний кредит» | `get_credit_overview()` → `regions`, `terms`, `rate_*`, `min_loan` | `stage_credit_region(province_index, selected)`, `offer_internal_credit(amount, rate, term, all_regions)` |
| «Выдать внешний кредит» | `get_diplomacy_country_list()`, `get_credit_overview()` → `staged_countries` | `stage_credit_country(country_index, selected)`, `offer_external_credit(amount, rate, term, all_countries)` |
| «Взять кредит» | `get_available_credit_offers()` | `take_credit(id)` |

5. Ограничения, которые интерфейс должен показывать: процент от 0 до `rate_limit`; ИИ выдаёт от `rate_min`, берёт до `rate_max`;
   минимальная сумма `min_loan`; сумма не больше казны (деньги резервируются при выдаче); краткосрочный кредит — только стройки до 365 дней.
6. Подсказки по типам — из `get_credit_overview()["terms"]` (длины и задержки берутся из конфига, не хардкодьте «5/10/20 лет»).

## 2. Производство

**Что уже умеет окно `game/src/UI/Session/ProductionMenu.gd` (до этого этапа):**
* список штатов игрока с заводами (`PlayerSingleton.get_production_info()`), по каждому заводу: уровень, занятость, выпуск, выручка, расходы на
  сырьё, зарплаты, прибыль, эффективность, бюджет, запасы сырья («не хватает»), доля государства, дивиденды, фонд расширения, стоимость и ценность;
* кнопки на завод: открыть/закрыть (`set_factory_open`), субсидия (`set_factory_subsidised`), расширить, строить (диалог «построить» —
  список доступных типов с ценой и временем, `build_factory`);
* массовые кнопки: субсидировать/снять субсидии всем, открыть/закрыть все, расширить все (`set_all_*`, `expand_all_factories`);
* режим субсидий (`set_subsidy_mode`), покупка/продажа долей завода (`buy_factory_share`/`sell_factory_share`).

**Добавлено в этом этапе (движок + мост, интерфейса нет):**

| Что | Симуляция | Мост | Что сделать в UI |
|---|---|---|---|
| Приоритет найма (0 низкий, 1 обычный, 2 высокий): заводы с высшим приоритетом нанимают первыми | `FactoryInstance::priority` (`SIM/economy/production/FactoryInstance.hpp`), порядок в `MapInstance::factory_tick` (`SIM/map/MapInstance.cpp`), действие `set_factory_priority` | `PlayerSingleton.set_factory_priority(province_index, building_type_index, priority)`; поле `priority` в `get_production_info()[state].factories[i]` | Кнопка-переключатель на панели завода (в `_setup_factory_panel` / `_update_factory_panel`): три положения, подпись из `tr("FACTORY_PRIORITY_*")` |
| Удаление завода: бюджет и фонд расширения возвращаются владельцам (доля государства — в казну, остальное — капиталистам) | `State::remove_factory` (`SIM/map/State.cpp`), действие `delete_factory` | `PlayerSingleton.delete_factory(province_index, building_type_index)` | Кнопка «Снести» с подтверждением (удаление необратимо; строящиеся тоже удаляются) |
| Вкладка «Инвестиции»: что строят капиталисты и государство, деньги капиталистов по штатам, остаток денег кредитов | — | `PlayerSingleton.get_investment_overview()` → `projects`, `states`, `total_capitalist_money` | Новая вкладка/окно: таблица `projects` (штат, тип, прогресс, `capitalist_funded`) и `states` |

**Фильтры и сортировка** (в планах «вкладки производства, фильтры, сортировка») делаются на стороне GDScript по уже отдаваемым полям:
сортировка по `profit`, `employment_ratio`, `output_quantity`, `level`, `throttle`; фильтры — по `output_good_index`, `open`, `subsidised`,
`built_by_state`, `constructing`, `lacking` (входы). Дополнительных вызовов моста не требуется.

«Производство товаров» и «проекты попов» — вкладки Vic2, которым нужны данные, которых в симуляции пока нет (статистика производства
по товарам для страны; проекты попов вообще не реализованы) — не сделаны.

## 3. Дипломатия (4f)

**Что готово в движке:** константы `defines.lua` теперь применяются в действиях (`SIM/diplomacy/DiplomaticAction.cpp`): цены влияния
(`DISCREDIT_INFLUENCE_COST`, `EXPELADVISORS_INFLUENCE_COST`, `BANEMBASSY_INFLUENCE_COST`, `ADDTOSPHERE_*`, `REMOVEFROMSPHERE_*`,
`INCREASEOPINION_*`, `DECREASEOPINION_*`), длительности (`DISCREDIT_DAYS`, `BANEMBASSY_DAYS`), изменение отношений
(`INCREASERELATION_RELATION_ON_ACCEPT` = +15, было жёстко +25; `DECREASERELATION_RELATION_ON_ACCEPT` = −25).
Реальная логика согласия получателя на действия — **после калибровки экономики** (зависит от ИИ), остаётся «принимает всё».

**Данные для вкладок окна `country_diplomacy.gui`** (скрипт `game/src/UI/Session/DiplomacyMenu.gd`; имена элементов — из `.gui`):

| Вкладка (кнопка в `.gui`) | Мост | Поля |
|---|---|---|
| «Великие державы» (`gp_info`) | `PlayerSingleton.get_great_powers_info()` | `rank`, `tag`, `name`, очки (престиж, промышленность, армия) и их места, `influence` (влияние игрока), `sphere` (страны в сфере) |
| «Войны» (`war_info`) | `PlayerSingleton.get_world_wars_info()` | `attackers`, `defenders`, `attacker_score`, `defender_score`, `days`, `involves_player` |
| «Поводы к войне» (`cb_info`) | — | поводов к войне (casus belli) в симуляции нет (нужен `justify_war`, этап войн) |
| «Кризис» (`crisis_info`, окно `crisis_info_win`) | `PlayerSingleton.get_crisis_info()` | сейчас всегда `{ available = false, active = false }`: механики кризиса в симуляции нет |

Фильтры (`filter_*`) и сортировки (`sort_by_*`) списка стран — клиентская работа над `get_diplomacy_country_list()` (поля `relation`, `*_rank`,
`population`; региональные фильтры требуют континента страны — его в мосте пока нет).

## 4. Сохранения (этап 4a, для справки)

`game/src/Systems/Startup/ReplayLoader.gd`, `SaveManager.gd`, `SaveGameWindow.gd`, `SaveLoadMenu.gd`; мост — `GameSingleton` (`get_defines_hash`,
сохранение/загрузка). Загрузка старых сохранений: действия старой системы кредитов пропускаются (см. `docs/CREDITS.md`).

## 5. Порядок работ, который я бы предложил

1. Пересобрать расширение (`cmake --build --preset <ваш>-editor`) и запустить игру; открыть кредиты из бюджета — проверить 4 вкладки.
2. Кредиты: заменить контролы на элементы Vic2 (раздел 1).
3. Производство: кнопки приоритета и удаления + вкладка инвестиций (раздел 2).
4. Дипломатия: наполнить вкладки `gp_info`/`war_info` данными (раздел 3); `crisis_info` и `cb_info` оставить пустыми, пока нет механик.
