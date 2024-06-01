-- триггер события для удаления триггеров от родительских таблиц
CREATE FUNCTION public.event_trigger_drop_inherit_triggers ()
    RETURNS EVENT_TRIGGER
    AS $$
DECLARE
    "object"               RECORD;
    "parent"               OID;
    "child"                OID;
    "name"                 TEXT;
    "query"                TEXT;
    "schema"               TEXT;
    "table"                TEXT;
BEGIN
    FOR "object" IN
    -- описание значений переменной object
    -- https://www.postgresql.org/docs/current/functions-event-triggers.html#PG-EVENT-TRIGGER-SQL-DROP-FUNCTIONS
    SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        -- удаление триггера
        IF "object".object_type = 'trigger' THEN
            "schema" = "object".address_names[1];
            "table" = "object".address_names[2];
            -- получение текущей таблицы
            "parent" = format('%1I.%2I', "schema", "table")::REGCLASS::OID;
            -- получение названия удалённого триггера
            "name" = "object".address_names[3];

            -- цикл по списку детей
            -- relid - дочернаяя таблица
            FOR "child" IN
            -- получение списка детей
            -- https://www.postgresql.org/docs/current/catalog-pg-inherits.html
            SELECT inhrelid FROM pg_inherits WHERE inhparent = "parent"
            LOOP
                -- имя триггера дочерней таблице
                "name" = public.get_child_trigger_name("name", "parent"::REGCLASS::TEXT, "child"::REGCLASS::TEXT);
                -- удаление триггер name из дочерней таблицы
                "query" = format('DROP TRIGGER IF EXISTS %1I ON %2I;', "name", "child"::REGCLASS);
                RAISE NOTICE USING MESSAGE = format('-- DROP TRIGGER %1I FROM %2I TABLE BASED ON DEPENDENCY ON %3I TABLE', "name", "child"::REGCLASS, "parent"::REGCLASS);
                RAISE NOTICE USING MESSAGE = format("query");
                EXECUTE "query";
            END LOOP;
        END IF;
    END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;
