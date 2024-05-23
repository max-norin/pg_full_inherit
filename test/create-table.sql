-- таблица пользователей с PRIMARY KEY, UNIQUE, FOREIGN KEY, CONSTRAINT TRIGGER, TRIGGER
CREATE TABLE public.users
(
    id       SERIAL PRIMARY KEY,
    email    VARCHAR(255) NOT NULL UNIQUE,
    username VARCHAR(255) NOT NULL,
    city_id  INT          NOT NULL,
    FOREIGN KEY (city_id) REFERENCES public.cities (id)
);
-- добавление CONSTRAINT TRIGGER к таблице пользователей
CREATE CONSTRAINT TRIGGER "check_email"
    AFTER INSERT OR UPDATE
    ON public.users
    FOR EACH ROW
EXECUTE FUNCTION public.trigger_check_email();
-- добавление TRIGGER к таблице пользователей
CREATE TRIGGER "lower_username"
    BEFORE INSERT OR UPDATE
    ON public.users
    FOR EACH ROW
EXECUTE FUNCTION public.trigger_lower_username();


-----------------------------------------------------------
CREATE TABLE public.full_users
(
    name VARCHAR(255) NOT NULL,
    bio  VARCHAR(255)
) INHERITS (public.users);
