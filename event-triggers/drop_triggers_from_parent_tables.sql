-- триггер события для добавление ограничений от родительских таблиц
-- в основом используется для создания REFERENCES
CREATE FUNCTION public.event_trigger_drop_triggers_from_parent_tables ()
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
    FOR object IN
    SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        IF NOT "object"."original" THEN
            CONTINUE;
        END IF;
        -- удаление ограничений
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
                -- имя триггера в дочерней таблице
                "name" = public.get_child_trigger_name("name", "parent"::REGCLASS::TEXT, "child"::REGCLASS::TEXT);
                -- удаление ограничения name из дочерней таблицы
                "query" = format('DROP TRIGGER IF EXISTS %1s ON %2s;', "name", "child"::REGCLASS);
                RAISE NOTICE USING MESSAGE = format('-- DROP TRIGGER %1s FROM %2s TABLE BASED ON DEPENDENCY ON %3s TABLE', "name", "child"::REGCLASS, "parent"::REGCLASS);
                RAISE NOTICE USING MESSAGE = format("query");
                EXECUTE "query";
            END LOOP;
        END IF;
    END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;
