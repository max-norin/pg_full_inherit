# pg_full_inherit

100% работает на PostgreSQL 16 версии, на остальных не проверял.
Если у вас есть информация, что работает на более ранних версиях
сообщите мне.

> Расширение для PostgreSQL, позволяющее делать полное наследование таблиц.
> Расширение позволяет унаследовать дочерним таблицам ограничения
> PRIMARY KEY, UNIQUE, FOREIGN KEY, CONSTRAINT TRIGGER и триггеры.

Примечание: при удалении наследования командой
`ALTER TABLE public.new_users NO INHERIT public.users;`
никаких дополнительных действий не произойдёт. Таблица будет иметь
те же столбцы, ограничения и триггеры, как при наследовании.
Включая автоматически наследуемые ограничения `CHECK` and `NOT NULL`.

# Содержание

1. [Установка](#Установка)
   1. [Классическая](#Классическая)
   1. [Обходной путь](#Обходной путь)
1. [Использование](#Использование)
   1. [Именование](#Именование)
      1. [Именование ограничений](#Именование-ограничений)
      1. [Именование триггеров](#Именование-триггеров)
      1. [Исключения](#Исключения)
   1. [Включение и отключение наследования](#Включение-и-отключение-наследования)
1. [Принцип работы](#Принцип-работы)
1. [Примеры работы](#Установка)
   1. [Создание Родительской таблицы](#Создание-Родительской-таблицы)
   1. [Создание Дочерней таблицы](#Создание Дочерней-таблицы)
   1. [Изменения Родительской таблицы](#Изменения-Родительской-таблицы)
   1. [Изменения Родительской таблицы](#Изменения-Родительской-таблицы-1)
   1. [Создание таблицы и определение её как Дочерней таблицы](#Создание-таблицы-и-определение-её-как-Дочерней-таблицы)
   1. [Снятие наследования Дочерней таблицы](#Снятие-наследования-Дочерней-таблицы)
1. [Удаление расширения](#Удаление-расширения)

# Установка

## Классическая

Скачайте файлы из [dist](./dist) и переместите их в папку `extension`
приложения PostgreSQL. Для windows папка может располагаться в
`C:\Program Files\PostgreSQL\16\share\extension`.
Далее выполните следующие команды. 

Создайте новую схему для удобства.

```sql
CREATE SCHEMA "abstract";
ALTER ROLE "postgres" SET search_path TO "public", "abstract";
```

Установите расширение.

```sql
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

```sql
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
-- удаление ограничений у родительской таблицы
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

```sql
-- ADD CONSTRAINT full_users_city_id_fkey TO full_users TABLE FROM users TABLE
ALTER TABLE full_users ADD CONSTRAINT full_users_city_id_fkey FOREIGN KEY (city_id) REFERENCES cities(id);
-- ADD CONSTRAINT full_users_pkey TO full_users TABLE FROM users TABLE
ALTER TABLE full_users ADD CONSTRAINT full_users_pkey PRIMARY KEY (id);
-- ADD CONSTRAINT full_users_email_key TO full_users TABLE FROM users TABLE
ALTER TABLE full_users ADD CONSTRAINT full_users_email_key UNIQUE (email);
-- ADD TRIGGER check_email TO full_users TABLE FROM users TABLE
CREATE CONSTRAINT TRIGGER check_email AFTER INSERT OR UPDATE ON public.full_users NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION trigger_check_email();
-- ADD TRIGGER lower_username TO full_users TABLE FROM users TABLE
CREATE TRIGGER lower_username BEFORE INSERT OR UPDATE ON public.full_users FOR EACH ROW EXECUTE FUNCTION trigger_lower_username();
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

### Исключения

При выполнении скриптов могут выпасть исключения, что добавляемые
ограничения или триггеры уже существуют. Это говорит о том, что
ограничения или триггеры, которое создаются в расширении,
имеют такие же имена, как уже существующие ограничения или триггеры.

Решения:

- переименуйте существующие ограничения или триггеры
- измените именование ограничений или триггеров с помощью функций
  `get_child_constraint_name` и `get_child_trigger_name`

## Включение и отключение наследования

Вы можете включать и отключать создание и удаление ограничений и триггеров
с помощью команд.

```sql
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

Для примера используются таблицы и триггеры из [/test/init.sql](/test/init.sql).

## Создание Родительской таблицы

```sql
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

## Создание Дочерней таблицы

```sql
-- дочерняя таблица пользователей
CREATE TABLE public.full_users
(
    name VARCHAR(255) NOT NULL,
    bio  VARCHAR(255)
) INHERITS (public.users);
```

Ответ в консоли

```sql
-- ADD CONSTRAINT full_users_city_id_fkey TO full_users TABLE FROM users TABLE
ALTER TABLE full_users ADD CONSTRAINT full_users_city_id_fkey FOREIGN KEY (city_id) REFERENCES cities(id);
-- ADD CONSTRAINT full_users_pkey TO full_users TABLE FROM users TABLE
ALTER TABLE full_users ADD CONSTRAINT full_users_pkey PRIMARY KEY (id);
-- ADD CONSTRAINT full_users_email_key TO full_users TABLE FROM users TABLE
ALTER TABLE full_users ADD CONSTRAINT full_users_email_key UNIQUE (email);
-- ADD TRIGGER check_email TO full_users TABLE FROM users TABLE
CREATE CONSTRAINT TRIGGER check_email AFTER INSERT OR UPDATE ON public.full_users NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION trigger_check_email();
-- ADD TRIGGER lower_username TO full_users TABLE FROM users TABLE
CREATE TRIGGER lower_username BEFORE INSERT OR UPDATE ON public.full_users FOR EACH ROW EXECUTE FUNCTION trigger_lower_username();
```

## Изменения Родительской таблицы

```sql
-- добавить в таблицу пользователей новые UNIQUE, FOREIGN KEY
ALTER TABLE public.users
    ADD CONSTRAINT "users--username: ukey" UNIQUE (username),
    ADD COLUMN lang_id INT,
    ADD CONSTRAINT "users: lang_id fkey" FOREIGN KEY (lang_id) REFERENCES langs (id);
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
```

Ответ в консоли

```sql
-- ADD CONSTRAINT "full_users--username: ukey" TO full_users TABLE FROM users TABLE
ALTER TABLE full_users ADD CONSTRAINT "full_users--username: ukey" UNIQUE (username);
-- ADD CONSTRAINT "full_users: lang_id fkey" TO full_users TABLE FROM users TABLE
ALTER TABLE full_users ADD CONSTRAINT "full_users: lang_id fkey" FOREIGN KEY (lang_id) REFERENCES langs(id);

-- ADD TRIGGER "check username" TO full_users TABLE FROM users TABLE
CREATE CONSTRAINT TRIGGER "check username" AFTER INSERT OR UPDATE ON public.full_users NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION trigger_check_username()

-- ADD TRIGGER "auto bio" TO full_users TABLE FROM users TABLE
CREATE TRIGGER "auto bio" BEFORE INSERT OR UPDATE ON public.full_users FOR EACH ROW EXECUTE FUNCTION trigger_auto_bio()
```

## Изменения Родительской таблицы

```sql
-- удаление из таблицы пользователей UNIQUE (username)
ALTER TABLE public.users
  DROP CONSTRAINT "users--username: ukey";
-- удаление из таблицы пользователей FOREIGN KEY (lang_id) REFERENCES langs (id)
ALTER TABLE public.users
  DROP CONSTRAINT "users: lang_id fkey";
-- удаление из таблицы пользователей колонки с FOREIGN KEY (city_id) REFERENCES cities (id)
ALTER TABLE public.users
  DROP COLUMN city_id;
-- удаление из таблицы пользователей CONSTRAINT TRIGGER и TRIGGER
DROP TRIGGER IF EXISTS "check username" ON public.users;
DROP TRIGGER IF EXISTS "auto bio" ON public.users;
```

Ответ в консоли

```sql
-- DROP CONSTRAINT "full_users--username: ukey" FROM full_users TABLE BASED ON DEPENDENCY ON users TABLE
ALTER TABLE full_users DROP CONSTRAINT IF EXISTS "full_users--username: ukey";

-- DROP CONSTRAINT "full_users: lang_id_fkey" FROM full_users TABLE BASED ON DEPENDENCY ON users TABLE
ALTER TABLE full_users DROP CONSTRAINT IF EXISTS "full_users: lang_id_fkey";

-- DROP CONSTRAINT full_users_city_id_fkey FROM full_users TABLE BASED ON DEPENDENCY ON users TABLE
ALTER TABLE full_users DROP CONSTRAINT IF EXISTS full_users_city_id_fkey;

-- DROP TRIGGER "check username" FROM full_users TABLE BASED ON DEPENDENCY ON users TABLE
DROP TRIGGER IF EXISTS "check username" ON full_users;

-- DROP TRIGGER "auto bio" FROM full_users TABLE BASED ON DEPENDENCY ON users TABLE
DROP TRIGGER IF EXISTS "auto bio" ON full_users;
```

## Создание таблицы и определение её как Дочерней таблицы

```sql
-- таблица аналогичная таблице пользователей, но без ограничений и триггеров
CREATE TABLE public.new_users
(
    id       INTEGER      NOT NULL,
    email    VARCHAR(255) NOT NULL,
    username VARCHAR(255) NOT NULL,
    city_id  INT          NOT NULL,
    lang_id  INT          NOT NULL,
    is_new   BOOLEAN      NOT NULL
);
-- определение таблицы, как дочерней
ALTER TABLE public.new_users
    INHERIT public.users;
```

Ответ в консоли

```sql
-- ADD CONSTRAINT new_users_email_key TO new_users TABLE FROM users TABLE
ALTER TABLE new_users ADD CONSTRAINT new_users_email_key UNIQUE (email);
-- ADD CONSTRAINT new_users_pkey TO new_users TABLE FROM users TABLE
ALTER TABLE new_users ADD CONSTRAINT new_users_pkey PRIMARY KEY (id);
-- ADD TRIGGER check_email TO new_users TABLE FROM users TABLE
CREATE CONSTRAINT TRIGGER check_email AFTER INSERT OR UPDATE ON public.new_users NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION trigger_check_email();
-- ADD TRIGGER lower_username TO new_users TABLE FROM users TABLE
CREATE TRIGGER lower_username BEFORE INSERT OR UPDATE ON public.new_users FOR EACH ROW EXECUTE FUNCTION trigger_lower_username();
```

## Снятие наследования Дочерней таблицы

```sql
ALTER TABLE public.new_users
    NO INHERIT public.users;
```

Таблица перестанет быть наследованной, но никаких действий не произойдет.

# Удаление расширения

```sql
DROP EXTENSION "pg_full_inherit";
```
