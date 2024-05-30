/*
=================== NAME ===================
*/
CREATE FUNCTION public.get_child_constraint_name ("name" TEXT, "parent" TEXT, "child" TEXT)
    RETURNS TEXT
AS $$
BEGIN
    RETURN regexp_replace("name", '^' || "parent", "child");
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION public.get_child_constraint_name (TEXT, TEXT, TEXT) IS '';

CREATE FUNCTION public.get_child_trigger_name ("name" TEXT, "parent" TEXT, "child" TEXT)
    RETURNS TEXT
AS $$
BEGIN
    RETURN "name";
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION public.get_child_trigger_name (TEXT, TEXT, TEXT) IS '';
/*
=================== GET_INHERIT_CONSTRAINTS ===================
*/
CREATE FUNCTION public.get_inherit_constraints ()
    RETURNS TABLE
            (
                "def"          TEXT,
                "parentid"     OID,
                "parentrelid"  OID,
                "parentname"   TEXT,
                "childid"      OID,
                "childrelid"   OID,
                "childname"    TEXT,
                "is_inherited" BOOL
            )
AS $$
BEGIN
    RETURN QUERY
        WITH "constraints" AS (
            SELECT "c"."oid", "c"."conrelid", "c"."conname", pg_get_constraintdef("c"."oid") AS "condef"
            FROM "pg_constraint" "c"
            WHERE "c"."contype" IN ('f', 'p', 'u'))
        SELECT "pc"."condef"             AS "def",
               "pc"."oid"                AS "parentid",
               "i"."inhparent"           AS "parentrelid",
               "pc"."conname"::TEXT      AS "parentname",
               "cc"."oid"                AS "childid",
               "i"."inhrelid"            AS "childrelid",
               "cc"."conname"::TEXT      AS "childname",
               "cc"."condef" IS NOT NULL AS "is_inherited"
        FROM "pg_inherits" "i"
                 LEFT JOIN "constraints" "pc" ON "i"."inhparent" = "pc"."conrelid"
                 LEFT JOIN "constraints" "cc" ON "i"."inhrelid" = "cc"."conrelid" AND "pc"."condef" = "cc"."condef"
        WHERE "pc"."oid" IS NOT NULL OR "cc"."oid" IS NOT NULL;
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION public.get_inherit_constraints () IS '';
/*
=================== GET_INHERIT_TRIGGERS ===================
*/
CREATE FUNCTION public.get_inherit_triggers ()
    RETURNS TABLE
            (
                "def"          TEXT,
                "parentid"     OID,
                "parentrelid"  OID,
                "parentname"   TEXT,
                "childid"      OID,
                "childrelid"   OID,
                "childname"    TEXT,
                "is_inherited" BOOL
            )
AS $$
BEGIN
    RETURN QUERY
        WITH "triggers" AS (
            SELECT "t"."oid", "t"."tgrelid", "t"."tgname", pg_get_triggerdef("t"."oid") AS "tgdef"
            FROM "pg_trigger" "t"
            WHERE "t"."tgisinternal" = FALSE)
        SELECT "pc"."tgdef"             AS "def",
               "pc"."oid"               AS "parentid",
               "i"."inhparent"          AS "parentrelid",
               "pc"."tgname"::TEXT      AS "parentname",
               "cc"."oid"               AS "childid",
               "i"."inhrelid"           AS "childrelid",
               "cc"."tgname"::TEXT      AS "childname",
               "cc"."tgdef" IS NOT NULL AS "is_inherited"
        FROM "pg_inherits" "i"
                 LEFT JOIN "triggers" "pc" ON "i"."inhparent" = "pc"."tgrelid"
                 LEFT JOIN "triggers" "cc" ON "i"."inhrelid" = "cc"."tgrelid"
            AND "pc"."tgdef" = replace ("cc"."tgdef", "i"."inhrelid"::REGCLASS::TEXT, "i"."inhparent"::REGCLASS::TEXT)
        WHERE "pc"."oid" IS NOT NULL OR "cc"."oid" IS NOT NULL;
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION public.get_inherit_triggers () IS '';
/*
=================== EVENT_TRIGGER_ADD_INHERIT_CONSTRAINTS ===================
*/
CREATE FUNCTION public.event_trigger_add_inherit_constraints ()
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
    SELECT * FROM pg_event_trigger_ddl_commands ()
    LOOP
        IF "command".in_extension = TRUE THEN
            CONTINUE;
        END IF;

        IF "command".command_tag = 'CREATE TABLE' THEN
            "child" = "command".objid;
            OPEN "constraints" FOR
                SELECT * FROM get_inherit_constraints() "c"
                WHERE "c"."childrelid" = "child" AND "c"."is_inherited" = FALSE
                LIMIT 1;
        ELSEIF "command".command_tag = 'ALTER TABLE' THEN
            "parent" = "command".objid;
            "child" = "command".objid;
            OPEN "constraints" FOR
                SELECT * FROM get_inherit_constraints() "c"
                WHERE ("c"."parentrelid" = "parent" OR "c"."childrelid" = "child")
                  AND "c"."is_inherited" = FALSE
                LIMIT 1;
        ELSE
            CONTINUE;
        END IF;

        LOOP
            FETCH NEXT FROM "constraints" INTO "constraint";
            EXIT WHEN "constraint" IS NULL;

            "name" = public.get_child_constraint_name("constraint"."parentname", "constraint"."parentrelid"::REGCLASS::TEXT, "constraint"."childrelid"::REGCLASS::TEXT);
            "query" = format('ALTER TABLE %1I ADD CONSTRAINT %2I %3s;', "constraint"."childrelid"::REGCLASS, "name", "constraint"."def");
            RAISE NOTICE USING MESSAGE = format('-- ADD CONSTRAINT %1I TO %2I TABLE FROM %3I TABLE', "name", "constraint"."childrelid"::REGCLASS, "constraint"."parentrelid"::REGCLASS);
            RAISE NOTICE USING MESSAGE = "query";
            EXECUTE "query";
        END LOOP;
        CLOSE "constraints";
    END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;
/*
=================== EVENT_TRIGGER_ADD_INHERIT_TRIGGERS ===================
*/
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
    SELECT * FROM pg_event_trigger_ddl_commands ()
    LOOP
        IF "command".in_extension = TRUE THEN
            CONTINUE;
        END IF;

        IF "command".command_tag = 'CREATE TABLE' THEN
            "child" = "command".objid;
            OPEN "triggers" FOR
                SELECT * FROM get_inherit_triggers() "t"
                WHERE "t"."childrelid" = "child" AND "t"."is_inherited" = FALSE;
        ELSEIF "command".command_tag = 'ALTER TABLE' THEN
            "child" = "command".objid;
            OPEN "triggers" FOR
                SELECT * FROM get_inherit_triggers() "t"
                WHERE "t"."childrelid" = "child" AND "t"."is_inherited" = FALSE;
        ELSEIF "command".command_tag = 'CREATE TRIGGER' THEN
            "triggerid" = "command".objid;
            OPEN "triggers" FOR
                SELECT * FROM get_inherit_triggers() "t"
                WHERE "t"."parentid" = "triggerid" AND "t"."is_inherited" = FALSE;
        ELSE
            CONTINUE;
        END IF;

        LOOP
            FETCH NEXT FROM "triggers" INTO "trigger";
            EXIT WHEN "trigger" IS NULL;

            "name" = public.get_child_trigger_name("trigger"."parentname", "trigger"."parentrelid"::REGCLASS::TEXT, "trigger"."childrelid"::REGCLASS::TEXT);
            "query" = replace ("trigger"."def", "trigger"."parentrelid"::REGCLASS::TEXT, "trigger"."childrelid"::REGCLASS::TEXT) || ';';
            RAISE NOTICE USING MESSAGE = format('-- ADD TRIGGER %1I TO %2I TABLE FROM %3I TABLE', "name", "trigger"."childrelid"::REGCLASS, "trigger"."parentrelid"::REGCLASS);
            RAISE NOTICE USING MESSAGE = format("query");
            EXECUTE "query";
        END LOOP;
        CLOSE "triggers";
    END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;
/*
=================== EVENT_TRIGGER_DROP_INHERIT_CONSTRAINTS ===================
*/
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
    SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        IF "object".object_type = 'table constraint' THEN
            "schema" = "object".address_names[1];
            "table" = "object".address_names[2];
            "parent" = format('%1I.%2I', "schema", "table")::REGCLASS::OID;
            "name" = "object".address_names[3];
            FOR "child" IN
            SELECT inhrelid FROM pg_inherits WHERE inhparent = "parent"
            LOOP
                "name" = public.get_child_constraint_name("name", "parent"::REGCLASS::TEXT, "child"::REGCLASS::TEXT);
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
/*
=================== EVENT_TRIGGER_DROP_INHERIT_TRIGGERS ===================
*/
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
    SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        IF "object".object_type = 'trigger' THEN
            "schema" = "object".address_names[1];
            "table" = "object".address_names[2];
            "parent" = format('%1I.%2I', "schema", "table")::REGCLASS::OID;
            "name" = "object".address_names[3];
            FOR "child" IN
            SELECT inhrelid FROM pg_inherits WHERE inhparent = "parent"
            LOOP
                "name" = public.get_child_trigger_name("name", "parent"::REGCLASS::TEXT, "child"::REGCLASS::TEXT);
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
/*
=================== INIT ===================
*/
CREATE EVENT TRIGGER "add_inherit_constraints" ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE', 'ALTER TABLE')
EXECUTE PROCEDURE public.event_trigger_add_inherit_constraints ();

CREATE EVENT TRIGGER "drop_inherit_constraints" ON sql_drop
    WHEN TAG IN ('ALTER TABLE')
EXECUTE PROCEDURE public.event_trigger_drop_inherit_constraints ();

CREATE EVENT TRIGGER "add_inherit_triggers" ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE', 'ALTER TABLE', 'CREATE TRIGGER')
EXECUTE PROCEDURE public.event_trigger_add_inherit_triggers ();

CREATE EVENT TRIGGER "drop_inherit_triggers" ON sql_drop
    WHEN TAG IN ('DROP TRIGGER')
EXECUTE PROCEDURE public.event_trigger_drop_inherit_triggers ();