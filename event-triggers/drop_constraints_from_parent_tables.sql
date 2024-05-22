-- триггер события для добавление ограничений от родительских таблиц
-- в основом используется для создания REFERENCES
CREATE FUNCTION public.event_trigger_drop_constraints_from_parent_tables ()
    RETURNS EVENT_TRIGGER
    AS $$
DECLARE
    "object"               RECORD;
    "parent"               OID;
    "child"                OID;
    "name"                 TEXT;
    "query"                 TEXT;
    "schema"               TEXT;
    "table"                TEXT;
BEGIN
    FOR object IN SELECT * FROM pg_event_trigger_dropped_objects()
        LOOP
            IF NOT "object".original THEN
                CONTINUE;
            END IF;
            -- удаление ограничений
            IF "object".object_type = 'table constraint' THEN
                "schema" = "object".address_names[1];
                "table" = "object".address_names[2];
                -- получение текущей таблицы
                "parent" = format('%1I.%2I', "schema", "table")::REGCLASS::OID;
                -- получние названия удалённого ограничения
                "name" = "object".address_names[3];

                -- цикл по списку детей
                -- relid - дочернаяя таблица
                FOR "child" IN
                -- получение списка детей
                -- https://www.postgresql.org/docs/current/catalog-pg-inherits.html
                SELECT inhrelid FROM pg_inherits WHERE inhparent = "parent"
                    LOOP
                        -- имя ограничения в дочерней таблице
                        "name" = public.constraint_child_from_parent("name", "parent"::REGCLASS::TEXT, "child"::REGCLASS::TEXT);
                        "query" = format('ALTER TABLE %1I ADD CONSTRAINT %2I %3s;', "child"::REGCLASS, "name", "constraint".def);
                        RAISE NOTICE USING MESSAGE = format('-- DROP CONSTRAINT %1s FROM %2s TABLE BASED ON DEPENDENCY ON %3s TABLE', "name", "child"::REGCLASS, "parent"::REGCLASS);
                        -- удаление ограничения текущую таблицы из таблицы дочерней таблицы
                        EXECUTE format('ALTER TABLE %1s DROP CONSTRAINT IF EXISTS %2s;', "child"::REGCLASS, "name");
                    END LOOP;
            END IF;
        END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;

-- CREATE EVENT TRIGGER "drop_constraints_from_parent_tables" ON sql_drop
--     WHEN TAG IN ('ALTER TABLE', 'DROP TRIGGER')
-- EXECUTE PROCEDURE public.event_trigger_drop_constraints_from_parent_tables ();
