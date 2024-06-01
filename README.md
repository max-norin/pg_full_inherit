# pg_full_inherit

100% works on PostgreSQL version 16, I didn't check the rest. 
If you have any information that works on earlier versions, please let me know.

> An extension for PostgreSQL that allows full table inheritance. 
> The extension allows child tables to inherit 
> PRIMARY KEY, UNIQUE, FOREIGN KEY, CONSTRAINT TRIGGER constraints and triggers.

Note: when deleting inheritance by the command 
`ALTER TABLE public.new_users NO INHERIT public.users;`,
no additional actions will occur. The table will have 
the same columns, constraints, and triggers as in inheritance.
Including automatically inherited `CHECK` and `NOT NULL` constraints.

[README in Russian](./README.ru.md)

# About inheritance in PostgreSQL

In PostgreSQL versions 16 and earlier, only columns and `CHECK` `NOT NULL` constraints 
are inherited when a table is inherited. All other constraints and triggers are not inherited.

If you delete inheritance from the table, then the columns, `CHECK` `NOT NULL` constraints, data 
in the child tables remain unchanged.

# Table of Contents

1. [Installation](#installation)
   1. [Classic](#Classic)
   1. [Workaround](#Workaround)
1. [Using](#Using)
   1. [Naming convention](#Naming-convention)
      1. [Naming constraints](#Naming-constraints)
      1. [Naming triggers](#Naming-triggers)
      1. [Exceptions](#Exceptions)
   1. [Enabling and disabling inheritance](#Enabling-and-disabling-inheritance)
1. [Operating principle](#Operating-principle)
1. [Examples of work](#Examples-of-work)
   1. [Creating a Parent Table](#Creating-a-Parent-Table)
   1. [Creating a Child Table](#Creating-a-Child-Table)
   1. [Changes to the Parent Table](#Changes-to-the-Parent-Table)
   1. [Changes to the Parent Table](#changes-to-the-Parent-Table-1)
   1. [Creating a table and defining it as a Child table](#Creating-a-table-and-defining-it-as-a-Child-table)
   1. [Removing Child Table Inheritance](#Removing-Child-Table-Inheritance)
1. [Deleting an extension](#Deleting-an-extension)

# Installation

## Classic

Download the files from [dist](./dist) and move them to the `extension`
folder of the PostgreSQL application.
For windows, the folder can be located in 
`C:\Program Files\PostgreSQL\16\share\extension`.
Next, run the following commands.

Create the new schema for convenience.

```sql
CREATE SCHEMA "abstract";
ALTER ROLE "postgres" SET search_path TO "public", "abstract";
```

Install the extension.

```sql
CREATE EXTENSION "pg_full_inherit"
    SCHEMA "abstract"
    VERSION '1.0';
```

[Learn more about an extension and control file](https://postgrespro.ru/docs/postgresql/current/extend-extensions)

## Workaround

If you can't add the extension to PostgreSQL, then there is another option. 
Copy the contents of files with the `.sql` extension from [dist](./dist) to a text editor. 
Replace the expression `@extschema@` with a schema 
to which the necessary functions will be added, for example `abstract`. 
Copy it to the PostgreSQL console and run it.

# Using

The extension works with the following commands and their variations.

```sql
-- creating the child table
CREATE TABLE public.full_users
(
) INHERITS (public.users);
-- adding inheritance to the table
ALTER TABLE public.new_users
    INHERIT public.users;
-- adding PRIMARY KEY, UNIQUE, FOREIGN KEY constraints to the parent table
ALTER TABLE public.users
    ADD CONSTRAINT users_username_ukey UNIQUE (username),
    ADD COLUMN lang_id INT,
    ADD CONSTRAINT users_lang_id_fkey FOREIGN KEY (lang_id) REFERENCES langs (id);
-- deleting the constraint from the parent table
ALTER TABLE public.users
    DROP CONSTRAINT users_username_ukey;
ALTER TABLE public.users
    DROP CONSTRAINT users_lang_id_fkey;
ALTER TABLE public.users
    DROP COLUMN lang_id;
-- adding the trigger to the parent table
CREATE CONSTRAINT TRIGGER "check_username"
    AFTER INSERT OR UPDATE
    ON public.users
    FOR EACH ROW
EXECUTE FUNCTION public.trigger_check_username();
-- deleting the trigger from the parent table
DROP TRIGGER IF EXISTS "check_username" ON public.users;
```

After the command is triggered, the console will describe what was done
with the child tables. For each added constraint and trigger, 
there will be the comment on what is happening and why, as well as the command that triggered it.

Example of output in the console.

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

## Naming convention

### Naming constraints

The names of constraints in the parent and child tables cannot be the same 
(DBMS features). Therefore, to control the
automatic naming of constraints in the extension, there is 
the function get_child_constraint_name.

If you are satisfied with the way PostgreSQL names constraints, 
then leave it as it is. If you want child table
constraints to have special names, then redefine the function as you see fit.

### Naming triggers

The trigger names of the parent and child tables can be the same 
(DBMS features). However, you can control the automatic
naming of triggers in the extension, there is the function `get_child_trigger_name`.

If you are satisfied with the same trigger names, then leave it as it is. 
If you want the child table triggers to have
special names, then redefine the function as you see fit.

### Exceptions

When executing scripts, exceptions may occur that the constraints 
or triggers you are adding already exist. This means
that constraints or triggers that are created in the extension 
have the same names as existing constraints or triggers.

Decisions:

- rename existing constraints or triggers
- change the naming of constraints or triggers using functions 
`get_child_constraint_name` and `get_child_trigger_name`

## Enabling and disabling inheritance

You can enable or disable creating and deleting constraints 
and triggers using the commands.

```sql
-- disabling the event trigger
ALTER EVENT TRIGGER event_trigger_name DISABLE;
-- enabling the event trigger
ALTER EVENT TRIGGER event_trigger_name ENABLE;
```

There are 4 triggers in total:

- `add_inherit_constraints` - event trigger for adding constraints
- `drop_inherit_constraints` - event trigger for deleting constraints
- `add_inherit_triggers` - event trigger for adding triggers
- `drop_inherit_triggers` - event trigger for deleting triggers

# Operating principle

The principle of operation is based on event triggers 
and system catalogs where information about tables is stored.

The extension has two functions `get_inherit_constraints` and `get_inherit_triggersthat` 
return tables with data about constraints and triggers for parent and child tables.

These functions are used in event triggers to determine which constraints and triggers need to be added.

# Examples of work

This example uses tables and triggers from [/test/init.sql](/test/init.sql).

## Creating a Parent Table

```sql
-- users table with PRIMARY KEY, UNIQUE, FOREIGN KEY, CONSTRAINT TRIGGER, TRIGGER
CREATE TABLE public.users
(
    id       SERIAL PRIMARY KEY,
    email    VARCHAR(255) NOT NULL UNIQUE,
    username VARCHAR(255) NOT NULL,
    city_id  INT          NOT NULL,
    FOREIGN KEY (city_id) REFERENCES public.cities (id)
);
-- adding CONSTRAINT TRIGGER to users table
CREATE CONSTRAINT TRIGGER "check_email"
    AFTER INSERT OR UPDATE
    ON public.users
    FOR EACH ROW
EXECUTE FUNCTION public.trigger_check_email();
-- adding TRIGGER to users table
CREATE TRIGGER "lower_username"
    BEFORE INSERT OR UPDATE
    ON public.users
    FOR EACH ROW
EXECUTE FUNCTION public.trigger_lower_username();
```

## Creating a Child Table

```sql
-- users child table
CREATE TABLE public.full_users
(
    name VARCHAR(255) NOT NULL,
    bio  VARCHAR(255)
) INHERITS (public.users);
```

Response in the console

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

## Changes to the Parent Table

```sql
-- adding UNIQUE, FOREIGN KEY to users table
ALTER TABLE public.users
    ADD CONSTRAINT "users--username: ukey" UNIQUE (username),
    ADD COLUMN lang_id INT,
    ADD CONSTRAINT "users: lang_id fkey" FOREIGN KEY (lang_id) REFERENCES langs (id);
-- adding CONSTRAINT TRIGGER to users table
CREATE CONSTRAINT TRIGGER "check username"
    AFTER INSERT OR UPDATE
    ON public.users
    FOR EACH ROW
EXECUTE FUNCTION public.trigger_check_username();
-- adding TRIGGER to users table
CREATE TRIGGER "auto bio"
    BEFORE INSERT OR UPDATE
    ON public.users
    FOR EACH ROW
EXECUTE FUNCTION public.trigger_auto_bio();
```

Response in the console

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

## Changes to the Parent Table

```sql
-- deleting UNIQUE (username) from user table
ALTER TABLE public.users
  DROP CONSTRAINT "users--username: ukey";
-- deleting FOREIGN KEY (lang_id) REFERENCES langs (id) from user table
ALTER TABLE public.users
  DROP CONSTRAINT "users: lang_id fkey";
-- deleting city_id column from user table
ALTER TABLE public.users
  DROP COLUMN city_id;
-- deleting CONSTRAINT TRIGGER and TRIGGER from user table
DROP TRIGGER IF EXISTS "check username" ON public.users;
DROP TRIGGER IF EXISTS "auto bio" ON public.users;
```

Response in the console

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

## Creating a table and defining it as a Child table

```sql
-- the table is similar to users table, but without constraint and triggers
CREATE TABLE public.new_users
(
    id       INTEGER      NOT NULL,
    email    VARCHAR(255) NOT NULL,
    username VARCHAR(255) NOT NULL,
    city_id  INT          NOT NULL,
    lang_id  INT          NOT NULL,
    is_new   BOOLEAN      NOT NULL
);
-- defining a table as a child
ALTER TABLE public.new_users
    INHERIT public.users;
```

Response in the console.

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

## Removing Child Table Inheritance

```sql
ALTER TABLE public.new_users
    NO INHERIT public.users;
```

The table will no longer be inherited, but no actions will occur.

# Deleting an extension

```sql
DROP EXTENSION "pg_full_inherit";
```
