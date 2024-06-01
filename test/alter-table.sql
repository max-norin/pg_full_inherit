-- добавить в таблицу новые UNIQUE, FOREIGN KEY
ALTER TABLE public.users
    ADD CONSTRAINT "users--username: ukey" UNIQUE (username),
    ADD COLUMN lang_id INT,
    ADD CONSTRAINT "users: lang_id_fkey" FOREIGN KEY (lang_id) REFERENCES langs (id);
-- добавление CONSTRAINT TRIGGER к таблице пользователей
CREATE CONSTRAINT TRIGGER "check username"
    AFTER INSERT OR UPDATE
    ON public.users
    FOR EACH ROW
EXECUTE FUNCTION public.trigger_check_username();
-- добавление TRIGGER к таблице пользователей
CREATE TRIGGER "auto bio"
    BEFORE INSERT OR UPDATE
    ON public.users
    FOR EACH ROW
EXECUTE FUNCTION public.trigger_auto_bio();
