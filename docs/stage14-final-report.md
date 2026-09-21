# Этап 14 — итоговая проверка системы Архива

## Production migration

- `031_staff_control.sql` применена в Supabase `wfivgzoiepldxddewvqf`.
- Карточка пользователя Staff Control загружается после миграции.
- Загружены 23 определения достижений.
- Прямые записи клиента в прогресс и награды запрещены.

## Существующие аккаунты на 21.09.2026

- TOTAL USERS: 17
- ARCHIVE 0: 5
- ARCHIVE I: 4
- ARCHIVE II: 0
- ARCHIVE III: 5
- TODM IV: 2
- AUTHOR / TODM V: 1
- FULL ACCESS: 3
- SUPPORTERS: 0
- KNOWN ARCHIVE PURCHASES: 0

## Security checks

- `authenticated → archive_progress INSERT`: false
- `authenticated → archive_progress UPDATE`: false
- `authenticated → user_achievements INSERT`: false
- `authenticated → archive_audit_log DELETE`: false
- Staff RPC доступен `authenticated`, но каждое действие повторно проверяет TODM IV/V на сервере.
- TODM IV не может изменять Автора или собственный прогресс.
- Прямой `service_role` отсутствует во frontend.
- Защита Томов II–III сохраняет правило `archive_level >= 3 OR full_access`.

## QA

- Личный кабинет, фракционная тема, прогресс, награды и история загружаются без console errors.
- Staff Control: список пользователей, поиск, карточка, профиль и сетка наград загружаются.
- TODM Shop больше не продаёт Архив; старые ссылки ведут к бесплатной прогрессии.
- JavaScript прошёл `node --check`, Git diff прошёл `git diff --check`.
- Responsive CSS покрывает desktop и mobile; проведена визуальная проверка текущего desktop viewport и структурная проверка mobile breakpoints.

## CONTENT REQUIRED / UNVERIFIED

- Актуальные тексты Пролога и глав 1–3 всё ещё требуются.
- 12 канонических вопросов Испытания I всё ещё требуются.
- Начисление за онлайн-игру остаётся `WAITING_FOR_GAME_BACKEND`.
- Платёжная система и подтверждение поддержки пока не подключены.

## Рекомендация по старым пользователям

Рекомендация: **KEEP сейчас, затем CONVERT после утверждения правил**.

Причина: подтверждённых старых покупок Архива нет, но пять обычных пользователей имеют III уровень, четыре — I, а три аккаунта имеют `full_access`. Немедленный RESET может неожиданно закрыть доступ действующим читателям. Безопаснее сохранить текущие права до отдельного решения владельца, затем выполнить прозрачную конвертацию с резервной копией и rollback-планом.

Массовое изменение уровней не выполнялось.
