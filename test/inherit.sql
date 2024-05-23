CREATE TABLE public.new_users
(
    id       INTEGER      NOT NULL,
    email    VARCHAR(255) NOT NULL,
    username VARCHAR(255) NOT NULL,
    city_id  INT          NOT NULL,
    is_new   BOOLEAN      NOT NULL
);

ALTER TABLE public.new_users
    INHERIT public.users;

ALTER TABLE public.new_users
    NO INHERIT public.users;
