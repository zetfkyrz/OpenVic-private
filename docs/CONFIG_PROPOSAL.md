# Этап 1: вынос констант в конфиг — предложение (ждёт ОК)

## Механизм
В проекте уже есть механизм defines: `common/defines.lua` (Lua-таблица `defines = { группа = { КЛЮЧ = число } }`),
который разбирает `DefineManager::load_defines_file` через `lua_defines_parse` и `expect_dictionary_keys`; каждая группа —
структура `*Defines` в `src/openvic-simulation/defines/` (`AIDefines`, `MilitaryDefines`, …) с `expect_defines()`.
Моды переопределяют файл обычным порядком поиска файлов (`Dataloader::lookup_file`).

Предлагаю **расширить именно его**, а не вводить новый формат:
- Новый файл `common/openvic_defines.lua` (тот же Lua-синтаксис, тот же парсер, ключи `ЗАГЛАВНЫМИ`), **необязательный**:
  если файла нет (ванильная Vic2), используются значения по умолчанию, зашитые в структурах (равны нынешним константам,
  поведение не меняется). Мод кладёт свой `common/openvic_defines.lua` и переопределяет любые ключи; отсутствующие
  ключи остаются по умолчанию (в отличие от `defines.lua`, где отсутствие ключа — ошибка).
- Новые структуры в `defines/`: `OpenVicDefines` (контейнер) с группами-структурами: `ov_ai`, `ov_population`, `ov_politics`,
  `ov_colonisation`, `ov_war`, `ov_peace`, `ov_research`, `ov_economy`. Они доступны как `DefineManager::get_openvic_defines()`.
- Пример со всеми ключами и значениями по умолчанию: `docs/openvic_defines.example.lua` (генерируется из тех же структур).
- Единицы: доли — дробные числа (`0.25` вместо `25` процентов), чтобы моды не путались; сроки — дни; счётчики — целые.
- Кредиты (`economy/credit`) **не трогаю**: вы готовите их переделку (PENDING_PLANS: [частично]).
- Константы формата/технические (размеры буферов, `NUM_SPEEDS`, имена, константы BMP/карты, `VECTORS_FOR_*`) в конфиг
  не выносятся: это не игровые параметры.

## Список констант (значение по умолчанию → ключ)

### ov_ai (`ai/CountryAI`)
| Сейчас | Ключ |
|---|---|
| `WAR_CHANCE_PERCENT_PER_YEAR = 25` | `WAR_CHANCE_PER_YEAR = 0.25` |
| `MAX_TARGET_POWER_PERCENT = 60` / `_PLAYER = 30` | `MAX_TARGET_POWER_RATIO = 0.60`, `MAX_TARGET_POWER_RATIO_PLAYER = 0.30` |
| `MAX_RANK_FOR_WARS = 30` | `MAX_RANK_FOR_WARS` |
| `FACTORY_PAYBACK_YEARS = 8` (+ правило «казна ≥ 3× стоимости») | `FACTORY_PAYBACK_YEARS`, `FACTORY_CASH_COST_MULT = 3` |
| `WAR_REGIMENTS_PER_PROVINCE_PERMILLE = 300` | `WAR_REGIMENTS_PER_PROVINCE = 0.3` |
| `MAX_RECRUITS_PER_MONTH = 3` | `MAX_RECRUITS_PER_MONTH` |
| день месяца/хэш-кубик решений (литералы в `CountryAI.cpp`, 9 мест) | `DECISION_DAY_OF_MONTH` и др. |

### ov_population (`population/PopDynamics`)
`GROWTH_BREAKEVEN_PERCENT 35`, `GROWTH_PERMILLE_PER_YEAR 25`, `DECLINE_PERMILLE_PER_YEAR 60`,
`ASSIMILATION_PERMILLE_PER_MONTH 1`, `PROMOTION_PERCENT_PER_MONTH 4`, `MIGRATION_PERMILLE_PER_MONTH 3`,
`MIGRATION_SCORE_MARGIN_PERCENT 8` → ключи `GROWTH_BREAKEVEN_LIFE_NEEDS`, `GROWTH_PER_YEAR`, `DECLINE_PER_YEAR`,
`ASSIMILATION_PER_MONTH`, `PROMOTION_PER_MONTH`, `MIGRATION_PER_MONTH`, `MIGRATION_SCORE_MARGIN` (+ 5 литералов в `PopDynamics.cpp`).

### ov_politics (`politics/PoliticsDynamics`, восстания)
`MILITANT_LEVEL 6`, `MIN_MILITANT_PEOPLE 30000`, `PEOPLE_PER_REBEL_REGIMENT 12000`, `MAX_REBEL_REGIMENTS 6`,
`MIN_MILITANT_PERCENT 15`, `UPRISING_COOLDOWN_DAYS 365`, `AI_SUPPRESSION_DAYS 90`; формула роста воинственности
`(pressure − 0.25) × 0.35` (2 литерала в `PoliticsDynamics.cpp`) → `MILITANCY_PRESSURE_OFFSET`, `MILITANCY_GROWTH`.

### ov_colonisation (`country/Colonisation`)
`MAX_COLONIAL_RANK 16`, `SEA_RANGE_BASE 3`, `SEA_RANGE_PER_BASE_LEVEL 2`, поддержка колонии `5`, скидка соседу `−20` из defines
(остаётся из defines Vic2).

### ov_war (`military/War`, `UnitInstanceGroup`)
Из заголовков: `TRUCE_DAYS 1825`, `SIEGE_BASE_DAYS 3`, `SIEGE_DAYS_PER_FORT_LEVEL 5`, `CAPITAL_PROVINCE_WEIGHT 5`,
`MAX_BATTLE_SCORE 25`, `REGIMENTS_PER_TRANSPORT 4`, `LANDING_ORGANISATION_DIVISOR 2`.
Из `.cpp`: `LEADER_POINT_DIVISOR 10`, `DIG_IN_DIVISOR 10`, `LEADER_DEATH_ODDS 30`, `NAVAL_STRENGTH_DAMAGE_PERCENT 2`,
`NAVAL_ORGANISATION_DAMAGE_PERCENT 8`, `MOVEMENT_SPEED_SCALE 3`, `PORT_STEP_DISTANCE 10`.
Инлайн-формулы `War.cpp` (≈28 мест): `min_org_factor 0.3`, `organisation_damage 0.05`, `strength_damage 0.01`,
`rout_threshold 0.1` (сухопутный и морской), приз престижа лидера `0.01`, осада `1/8 + siege/10`,
восстановление `organisation 0.02 / strength 0.005`, истощение `base 0.002`, `без снабжения 0.003`, `floor_share 0.2`.

### ov_peace (`military/Peace`)
`REPARATIONS_COST 10`, `HUMILIATE_COST 8`, `REPARATIONS_PERCENT 25`, `HUMILIATE_PRESTIGE 5`, `OFFER_VALID_DAYS 60`
+ ≈20 литералов в формулах оценки/стоимости (`Peace.cpp`: `evaluate_offer`, `get_state_cost`, пауза между предложениями `+30`,
день месяца ИИ-мира `10`).

### ov_research (`research/ResearchDynamics`)
`BASE_PROGRESS_PERCENT 3`, `LITERACY_PROGRESS_PERCENT 6` → `INVENTION_BASE_CHANCE_PER_MONTH 0.03`, `INVENTION_LITERACY_CHANCE 0.06`.

### ov_economy (заводы, рынок, страна)
`FactoryInstance`: `MAX_FACTORIES_PER_STATE 8`, `PAYBACK_YEARS 6`, `DEFAULT_CONSTRUCTION_DAYS 180`, `STOCKPILE_TARGET_DAYS 2`,
`EXPANSION_EMPLOYMENT_PERCENT 80`, `WORKING_CAPITAL_DAYS 5`, `MIN_WORKING_CAPITAL 20`, `DAYS_OF_LOSS_BEFORE_CLOSING 90`;
из ранних записей (в `FactoryInstance.cpp`, 9 литералов): `FOUNDING_CAPITAL_DAYS 15`, прибыль 45 дней до расширения,
доли рабочих 50 % и капиталистов 25 %, границы `efficiency 0.6–1.5`, `throttle 0.2–1`.
`GoodMarket`: `MONTHS_OF_PRICE_HISTORY 36`. `CountryInstance`: `DAYS_OF_BALANCE_HISTORY 30`, `DAYS_OF_SUPPLY 10`,
`PRIMITIVE_CIVILISATION_PROGRESS 0.15`, `UNCIVILISED_CIVILISATION_PROGRESS 0.5`. `Pop.cpp`: границы
militancy/consciousness 0–10, literacy 0.01–1 (это правила модели, оставляю в коде).
`NotificationLog::MAX_ENTRIES 300` → `NOTIFICATION_LOG_SIZE`.

## Порядок работ после вашего ОК
1. `OpenVicDefines` + группы-структуры со значениями по умолчанию (равны нынешним) + разбор `common/openvic_defines.lua`
   (необязательный, неизвестные ключи — предупреждение).
2. Замена констант на обращения к `instance_manager.definition_manager.get_define_manager().get_openvic_defines()...`
   по файлам.
3. Контроль: headless-прогон `-e 60` до и после даёт **одинаковый CHECKSUM** (значения по умолчанию = прежним).
4. Пример `docs/openvic_defines.example.lua`, описание в `CLAUDE.md`, отдельный коммит.

## Допущения (для вашего решения)
- Единицы в конфиге — доли, не проценты/промилле (в коде везде делаю перевод в `fixed_point_t`).
- Один необязательный файл вместо правки `defines.lua` (ванильный файл не трогаем, моды не обязаны его копировать).
