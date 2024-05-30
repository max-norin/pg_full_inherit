-- триггер события для удаления ограничений от родительских таблиц
CREATE FUNCTION public.event_trigger_drop_inherit_constraints ()
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
        -- удаление ограничений
        IF "object".object_type = 'table constraint' THEN
            "schema" = "object".address_names[1];
            "table" = "object".address_names[2];
            -- получение текущей таблицы
            "parent" = format('%1I.%2I', "schema", "table")::REGCLASS::OID;
            -- получение названия удалённого ограничения
            "name" = "object".address_names[3];

            -- цикл по списку детей
            -- relid - дочернаяя таблица
            FOR "child" IN
            -- получение списка детей
            -- https://www.postgresql.org/docs/current/catalog-pg-inherits.html
            SELECT inhrelid FROM pg_inherits WHERE inhparent = "parent"
            LOOP
                -- имя ограничения дочерней таблице
                "name" = public.get_child_constraint_name("name", "parent"::REGCLASS::TEXT, "child"::REGCLASS::TEXT);
                -- удаление ограничения name из дочерней таблицы
                "query" = format('ALTER TABLE %1s DROP CONSTRAINT IF EXISTS %2s;', "child"::REGCLASS, "name");
                RAISE NOTICE USING MESSAGE = format('-- DROP CONSTRAINT %1s FROM %2s TABLE BASED ON DEPENDENCY ON %3s TABLE', "name", "child"::REGCLASS, "parent"::REGCLASS);
                RAISE NOTICE USING MESSAGE = format("query");
                EXECUTE "query";
            END LOOP;
        END IF;
    END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;
