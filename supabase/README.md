# Настройка Supabase для TODM

1. Откройте SQL Editor в проекте Supabase.
2. Выполните `schema.sql` целиком один раз.
3. В Authentication → Providers → Email включите регистрацию и отключите Confirm email.
4. В Authentication → URL Configuration укажите production URL GitHub Pages и `http://127.0.0.1:8765/**` для локальной проверки.
5. Зарегистрируйте авторский аккаунт через сайт.
6. Выполните закомментированный `update account_access` из конца `schema.sql`.

Не размещайте secret/service_role key в этом репозитории. Пороговые суммы в `archive_thresholds` намеренно не активированы и содержат технические значения-заглушки.
