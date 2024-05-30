# pg_full_inherit

> Расширение для PostgreSQL, позволяющее делать полное наследование таблиц.
> Расширение позволяет унаследовать дочерним таблицам ограничения
> PRIMARY KEY, UNIQUE, FOREIGN KEY, CONSTRAINT TRIGGER и триггеры.

Важное замечание: при удалении наследования командой
`ALTER TABLE public.new_users NO INHERIT public.users;`
никакие действия не произойдут.

# Установка

## Классическая

Скачайте в папку `extension` PostgreSQL файлы из [dist](./dist)
и выполните следующие команды. Для windows папка может располагаться в
`C:\Program Files\PostgreSQL\16\share\extension`.

Создайте новую схему для удобства.

```postgresql
CREATE SCHEMA "abstract";
ALTER ROLE "postgres" SET search_path TO "public", "abstract";
```

Установите расширение.

```postgresql
CREATE EXTENSION "pg_full_inherit"
    SCHEMA "abstract"
    VERSION '1.0';
```

[Подробнее про расширение и файл control](https://postgrespro.ru/docs/postgresql/current/extend-extensions)

## Обходной путь

Если нет возможности добавить расширение в PostgreSQL, то есть другой вариант.
Скопировать в текстовый редактор содержание файлов с расширением `.sql`
из [dist](./dist). Заменить выражение `@extschema@` на схему,
в которую будет добавлены необходимые функции, например `abstract`.
Скопировать в консоль PostgreSQL и запустить.

# Использование

Расширение работает со следующими командами и их вариациями.

```postgresql
-- создание дочерней таблицы
CREATE TABLE public.full_users
(
) INHERITS (public.users);
-- добавления наследования к таблице 
ALTER TABLE public.new_users
    INHERIT public.users;
-- добавление ограничений PRIMARY KEY, UNIQUE, FOREIGN KEY к родительской таблице
ALTER TABLE public.users
    ADD CONSTRAINT users_username_ukey UNIQUE (username),
    ADD COLUMN lang_id INT,
    ADD CONSTRAINT users_lang_id_fkey FOREIGN KEY (lang_id) REFERENCES langs (id);
-- удаление ограничений
ALTER TABLE public.users
    DROP CONSTRAINT users_username_ukey;
ALTER TABLE public.users
    DROP CONSTRAINT users_lang_id_fkey;
ALTER TABLE public.users
    DROP COLUMN lang_id;
-- добавление триггера к родительской таблице
CREATE CONSTRAINT TRIGGER "check_username"
    AFTER INSERT OR UPDATE
    ON public.users
    FOR EACH ROW
EXECUTE FUNCTION public.trigger_check_username();
-- удаление триггера у родительской таблицы
DROP TRIGGER IF EXISTS "check_username" ON public.users;
```

После срабатывания команды в консоли будет описано, что было сделано
с дочерними таблицами. Для каждого добавленного ограничения и триггера
будет комментарий, что и почему происходит, а так же команда, которая сработала.

Пример вывода в консоли.

```postgresql
-- ADD CONSTRAINT full_users_city_id_fkey TO full_users TABLE FROM users TABLE
ALTER TABLE full_users
    ADD CONSTRAINT full_users_city_id_fkey FOREIGN KEY (city_id) REFERENCES cities (id);
-- ADD CONSTRAINT full_users_pkey TO full_users TABLE FROM users TABLE
ALTER TABLE full_users
    ADD CONSTRAINT full_users_pkey PRIMARY KEY (id);
-- ADD CONSTRAINT full_users_email_key TO full_users TABLE FROM users TABLE
ALTER TABLE full_users
    ADD CONSTRAINT full_users_email_key UNIQUE (email);
-- ADD TRIGGER lower_username TO full_users TABLE FROM users TABLE
CREATE TRIGGER lower_username
    BEFORE INSERT OR UPDATE
    ON public.full_users
    FOR EACH ROW
EXECUTE FUNCTION trigger_lower_username();
-- ADD TRIGGER check_email TO full_users TABLE FROM users TABLE
CREATE CONSTRAINT TRIGGER check_email
    AFTER INSERT OR UPDATE
    ON public.full_users NOT DEFERRABLE INITIALLY IMMEDIATE
    FOR EACH ROW
EXECUTE FUNCTION trigger_check_email();
```

## Именование

### Именование ограничений

Имена ограничений у родительской и дочерней таблицы не могут быть одинаковыми
(особенности СУБД). Поэтому, чтобы управлять автоматическим именованием ограничений
в расширении, есть функция `get_child_constraint_name`.

Если вас устраивает, как именует ограничения PostgreSQL, то оставьте всё как есть.
Если хотите, чтобы ограничения дочерней таблицы имели особые имена,
то переопределите функцию по своему усмотрению.

### Именование триггеров

Имена триггеров у родительской и дочерней таблицы могут быть одинаковыми
(особенности СУБД). Однако вы можете управлять автоматическим именованием триггеров
в расширении, есть функция `get_child_trigger_name`.

Если вас устраивает одинаковые имена триггеров, то оставьте всё как есть.
Если хотите, чтобы триггеры дочерней таблицы имели особые имена,
то переопределите функцию по своему усмотрению.

## Включение и отключение наследования

Вы можете включать и отключать создание и удаление ограничений и триггеров
с помощью команд.

```postgresql
-- отключение событийного триггера
    ALTER EVENT TRIGGER имя_событийного_триггера DISABLE;
-- включение событийного триггера
    ALTER EVENT TRIGGER имя_событийного_триггера ENABLE;
```

Всего есть 4 триггера:

- `add_inherit_constraints` - событийный триггер добавления ограничений
- `drop_inherit_constraints` - событийный триггер удаления ограничений
- `add_inherit_triggers` - событийный триггер добавления триггеров
- `drop_inherit_triggers` - событийный триггер удаления триггеров

# Принцип работы

Принцип работы основан на событийных триггерах и системных каталогах,
где хранится информация о таблицах.

В расширении есть две функции `get_inherit_constraints` и `get_inherit_triggers`,
которые возвращают таблицы с данными об ограничениях и триггерах
у родительских и дочерних таблиц.

Эти функции используются в событийных триггерах для определения,
какие ограничения и триггеры необходимо добавить.

# Примеры работы

## Создание Родительской таблицы

Для примера используются таблицы и триггеры из [/test/init.sql](/test/init.sql).

```postgresql
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
```

Ответ в консоли

```postgresql
```

## Создание Дочерней таблицы

```postgresql
CREATE TABLE public.full_users
(
    name VARCHAR(255) NOT NULL,
    bio  VARCHAR(255)
) INHERITS (public.users);
```

Ответ в консоли

```postgresql
```
