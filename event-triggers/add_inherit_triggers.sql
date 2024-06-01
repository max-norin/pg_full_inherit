-- триггер события для добавление триггеров от родительских таблиц
CREATE FUNCTION public.event_trigger_add_inherit_triggers ()
    RETURNS EVENT_TRIGGER
    AS $$
DECLARE
    "command"              RECORD;
    "triggerid"            OID;
    "child"                OID;
    "trigger"              RECORD;
    "name"                 TEXT;
    "query"                TEXT;
    "triggers"             REFCURSOR;
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
            -- добавление ограничений в курсор triggers
            OPEN "triggers" FOR
                SELECT * FROM public.get_inherit_triggers() "t"
                WHERE "t"."childrelid" = "child" AND "t"."is_inherited" = FALSE;
        -- если редактируется таблица
        ELSEIF "command".command_tag = 'ALTER TABLE' THEN
            -- получение текущей дочерней таблицы
            -- для обработки, когда изменяется наследование таблицы
            "child" = "command".objid;
            -- добавление ограничений в курсор triggers
            OPEN "triggers" FOR
                SELECT * FROM public.get_inherit_triggers() "t"
                WHERE "t"."childrelid" = "child" AND "t"."is_inherited" = FALSE;
        -- если создается триггер
        ELSEIF "command".command_tag = 'CREATE TRIGGER' THEN
            -- "command".objid - OID триггера
            "triggerid" = "command".objid;
            -- добавление ограничений в курсор triggers
            OPEN "triggers" FOR
                SELECT * FROM public.get_inherit_triggers() "t"
                WHERE "t"."parentid" = "triggerid" AND "t"."is_inherited" = FALSE;
        ELSE
            -- пропустить обработку дальше, так как могут быть
            -- CREATE SEQUENCE, ALTER SEQUENCE, CREATE INDEX
            CONTINUE;
        END IF;

        LOOP
            FETCH NEXT FROM "triggers" INTO "trigger";
            -- завершить цикл если trigger пустой
            EXIT WHEN "trigger" IS NULL;
            -- имя для триггера дочерней таблицы
            "name" = public.get_child_trigger_name("trigger"."parentname", "trigger"."parentrelid"::REGCLASS::TEXT, "trigger"."childrelid"::REGCLASS::TEXT);
            -- запрос на добавление триггера в таблицу childrelid
            "query" = public.get_child_trigger_def("trigger"."parentdef", "trigger"."parentname", "trigger"."parentrelid"::REGCLASS::TEXT, "trigger"."childrelid"::REGCLASS::TEXT);
            RAISE NOTICE USING MESSAGE = format('-- ADD TRIGGER %1I TO %2I TABLE FROM %3I TABLE', "name", "trigger"."childrelid"::REGCLASS, "trigger"."parentrelid"::REGCLASS);
            RAISE NOTICE USING MESSAGE = format("query");
            EXECUTE "query";
        END LOOP;

        -- закрыть курсор для освобождения памяти
        CLOSE "triggers";
    END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;
