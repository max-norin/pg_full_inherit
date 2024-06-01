-- удаление из таблицы пользователей UNIQUE (username)
ALTER TABLE public.users
    DROP CONSTRAINT "users--username: ukey";
-- удаление из таблицы пользователей FOREIGN KEY (lang_id) REFERENCES langs (id)
ALTER TABLE public.users
    DROP CONSTRAINT "users: lang_id_fkey";
-- удаление из таблицы пользователей колонки с FOREIGN KEY (city_id) REFERENCES cities (id)
ALTER TABLE public.users
    DROP COLUMN city_id;
-- удаление из таблицы пользователей CONSTRAINT TRIGGER и TRIGGER
DROP TRIGGER IF EXISTS "check username" ON public.users;
DROP TRIGGER IF EXISTS "auto bio" ON public.users;
