-- триггер события для добавление ограничений от родительских таблиц
-- в основом используется для создания REFERENCES
CREATE FUNCTION public.event_trigger_add_constraints_from_parent_tables ()
    RETURNS EVENT_TRIGGER
    AS $$
DECLARE
    "command"              RECORD;
    "parent"               OID;
    "child"                OID;
    "constraint"           RECORD;
    "name"                 TEXT;
    "query"                TEXT;
    "constraints"          REFCURSOR;
BEGIN
    FOR "command" IN
    -- описание значений переменной command
    -- https://www.postgresql.org/docs/current/functions-event-triggers.html#PG-EVENT-TRIGGER-DDL-COMMAND-END-FUNCTIONS
    SELECT * FROM pg_event_trigger_ddl_commands ()
    LOOP
        -- не обрабатывать запрос, если запрос внутри расширения
        IF "command".in_extension = TRUE THEN
            CONTINUE;
        END IF;

        -- если создается таблица
        IF "command".command_tag = 'CREATE TABLE' THEN
            -- получение текущей дочерней таблицы
            "child" = "command".objid;
            -- добавление ограничений в курсор constraints
            -- LIMIT 1 - потому что запрос ALTER TABLE в цикле ниже
            -- запускает опять этот же триггер и снова выполняется эта команда
            -- происходит рекурсия, которую нельзя контролировать,
            -- так как нет указателя на текущую глубину рекурсии
            OPEN "constraints" FOR
                SELECT * FROM get_constraints() "c"
                WHERE "c"."childrelid" = "child" AND "c"."is_inherited" = FALSE
                LIMIT 1;
        -- если редактируется таблица
        ELSEIF "command".command_tag = 'ALTER TABLE' THEN
            -- получение текущей родительской таблицы
            -- при добавлении ограничения
            "parent" = "command".objid;
            -- получение текущей дочерней таблицы
            -- при изменении наследования
            "child" = "command".objid;
            -- добавление ограничений в курсор constraints
            -- LIMIT 1 - потому что запрос ALTER TABLE в цикле ниже
            -- запускает опять этот же триггер и снова выполняется эта команда
            -- происходит рекурсия, которую нельзя контролировать,
            -- так как нет указателя на текущую глубину рекурсии
            OPEN "constraints" FOR
                SELECT * FROM get_constraints() "c"
                WHERE ("c"."parentrelid" = "parent" OR "c"."childrelid" = "child")
                  AND "c"."is_inherited" = FALSE
                LIMIT 1;
        ELSE
            -- пропустить обработку дальше, так как могут быть
            -- CREATE SEQUENCE, ALTER SEQUENCE, CREATE INDEX
            CONTINUE;
        END IF;

        LOOP
            FETCH NEXT FROM "constraints" INTO "constraint";
            -- завершить цикл если constraint пустой
            EXIT WHEN "constraint" IS NULL;
            -- имя для ограничения к дочерней таблицы
            "name" = public.get_child_constraint_name("constraint"."parentname", "constraint"."parentrelid"::REGCLASS::TEXT, "constraint"."childrelid"::REGCLASS::TEXT);
            -- запрос на добавление ограничения name в таблицу childid
            "query" = format('ALTER TABLE %1I ADD CONSTRAINT %2I %3s;', "constraint"."childrelid"::REGCLASS, "name", "constraint"."def");
            RAISE NOTICE USING MESSAGE = format('-- ADD CONSTRAINT %1I TO %2I TABLE FROM %3I TABLE', "name", "constraint"."childrelid"::REGCLASS, "constraint"."parentrelid"::REGCLASS);
            RAISE NOTICE USING MESSAGE = "query";
            EXECUTE "query";
        END LOOP;

        -- закрыть курсор для освобождения памяти
        CLOSE "constraints";
    END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;
