-- удаление из таблицы пользователей UNIQUE (username) и FOREIGN KEY (lang_id) REFERENCES langs (id)
ALTER TABLE public.users
    DROP CONSTRAINT users_username_ukey;
ALTER TABLE public.users
    DROP CONSTRAINT users_lang_id_fkey;
-- удаление из таблицы пользователей колонки с FOREIGN KEY (city_id) REFERENCES cities (id)
ALTER TABLE public.users
    DROP COLUMN city_id;
-- удаление из таблицы пользователей CONSTRAINT TRIGGER и TRIGGER
DROP TRIGGER "check_username" ON public.users;
DROP TRIGGER "auto_bio" ON public.users;
