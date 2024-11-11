/*
-- =================== GET_TABLE_NAME ===================
*/
CREATE FUNCTION @extschema@.get_table_name ("relid" REGCLASS, "is_full" BOOLEAN = TRUE)
    RETURNS TEXT
AS $$
BEGIN
    RETURN (
            SELECT CASE WHEN "is_full" THEN format('%I.%I', n.nspname, c.relname)
                    ELSE format('%I', c.relname)
                   END
            FROM pg_class c JOIN pg_namespace n on c.relnamespace = n.oid
            WHERE c.oid = "relid");
END
$$
LANGUAGE plpgsql
RETURNS NULL ON NULL INPUT;
/*
=================== NAME ===================
*/
DROP FUNCTION @extschema@.get_child_constraint_name ("name" TEXT, "parent" TEXT, "child" TEXT);

CREATE FUNCTION @extschema@.get_child_constraint_name ("name" TEXT, "parent" REGCLASS, "child" REGCLASS)
    RETURNS TEXT
AS $$
BEGIN
    RETURN regexp_replace("name", '^' || @extschema@.get_table_name("parent", FALSE), @extschema@.get_table_name("child", FALSE));
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

DROP FUNCTION @extschema@.get_child_trigger_name ("name" TEXT, "parent" TEXT, "child" TEXT);

CREATE FUNCTION @extschema@.get_child_trigger_name ("name" TEXT, "parent" REGCLASS, "child" REGCLASS)
    RETURNS TEXT
AS $$
BEGIN
    RETURN "name";
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;
/*
=================== DEF ===================
*/
DROP FUNCTION @extschema@.get_child_trigger_def ("parentdef" TEXT, "parentname" TEXT, "parent" TEXT, "child" TEXT);

CREATE FUNCTION @extschema@.get_child_trigger_def ("parentdef" TEXT, "parentname" TEXT, "parent" REGCLASS, "child" REGCLASS)
    RETURNS TEXT
AS $$
BEGIN
    RETURN regexp_replace (
            replace ("parentdef", @extschema@.get_table_name("parent", TRUE), @extschema@.get_table_name("child", TRUE)),
            '(CREATE (CONSTRAINT )?TRIGGER) ' || quote_ident ("parentname"),
            '\1 ' || quote_ident (@extschema@.get_child_trigger_name("parentname", "parent", "child")));
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;
/*
=================== GET_INHERIT_TRIGGERS ===================
*/
CREATE OR REPLACE FUNCTION @extschema@.get_inherit_triggers ()
    RETURNS TABLE
(
    "parentid"     OID,
    "parentrelid"  OID,
    "parentname"   TEXT,
    "parentdef"    TEXT,
    "childid"      OID,
    "childrelid"   OID,
    "childname"    TEXT,
    "childdef"     TEXT,
    "is_inherited" BOOL
)
AS $$
BEGIN
    RETURN QUERY
        WITH "triggers" AS (
            SELECT "t"."oid", "t"."tgrelid", "t"."tgname", pg_get_triggerdef("t"."oid") AS "tgdef"
            FROM "pg_trigger" "t"
            WHERE "t"."tgisinternal" = FALSE)
        SELECT "pc"."oid"               AS "parentid",
               "i"."inhparent"          AS "parentrelid",
               "pc"."tgname"::TEXT      AS "parentname",
               "pc"."tgdef"             AS "parentdef",
               "cc"."oid"               AS "childid",
               "i"."inhrelid"           AS "childrelid",
               "cc"."tgname"::TEXT      AS "childname",
               "cc"."tgdef"             AS "childdef",
               "cc"."tgdef" IS NOT NULL AS "is_inherited"
        FROM "pg_inherits" "i"
                 LEFT JOIN "triggers" "pc" ON "i"."inhparent" = "pc"."tgrelid"
                 LEFT JOIN "triggers" "cc" ON "i"."inhrelid" = "cc"."tgrelid"
                    AND @extschema@.get_child_trigger_def("pc"."tgdef", "pc"."tgname":: TEXT, "i"."inhparent"::REGCLASS, "i"."inhrelid"::REGCLASS) = "cc"."tgdef"
        WHERE "pc"."oid" IS NOT NULL OR "cc"."oid" IS NOT NULL;
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;
/*
=================== EVENT_TRIGGER_ADD_INHERIT_CONSTRAINTS ===================
*/
CREATE OR REPLACE FUNCTION @extschema@.event_trigger_add_inherit_constraints ()
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
                SELECT * FROM @extschema@.get_inherit_constraints() "c"
                WHERE "c"."childrelid" = "child" AND "c"."is_inherited" = FALSE
                LIMIT 1;
        ELSEIF "command".command_tag = 'ALTER TABLE' THEN
            "parent" = "command".objid;
            "child" = "command".objid;
            OPEN "constraints" FOR
                SELECT * FROM @extschema@.get_inherit_constraints() "c"
                WHERE ("c"."parentrelid" = "parent" OR "c"."childrelid" = "child")
                  AND "c"."is_inherited" = FALSE
                LIMIT 1;
        ELSE
            CONTINUE;
        END IF;

        LOOP
            FETCH NEXT FROM "constraints" INTO "constraint";
            EXIT WHEN "constraint" IS NULL;

            "name" = @extschema@.get_child_constraint_name("constraint"."parentname", "constraint"."parentrelid"::REGCLASS, "constraint"."childrelid"::REGCLASS);
            "query" = format('ALTER TABLE %1s ADD CONSTRAINT %2I %3s;', "constraint"."childrelid"::REGCLASS, "name", "constraint"."parentdef");
            RAISE NOTICE USING MESSAGE = format('-- ADD CONSTRAINT %1I TO %2s TABLE FROM %3s TABLE', "name", "constraint"."childrelid"::REGCLASS, "constraint"."parentrelid"::REGCLASS);
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
CREATE OR REPLACE FUNCTION @extschema@.event_trigger_add_inherit_triggers ()
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
                SELECT * FROM @extschema@.get_inherit_triggers() "t"
                WHERE "t"."childrelid" = "child" AND "t"."is_inherited" = FALSE;
        ELSEIF "command".command_tag = 'ALTER TABLE' THEN
            "child" = "command".objid;
            OPEN "triggers" FOR
                SELECT * FROM @extschema@.get_inherit_triggers() "t"
                WHERE "t"."childrelid" = "child" AND "t"."is_inherited" = FALSE;
        ELSEIF "command".command_tag = 'CREATE TRIGGER' THEN
            "triggerid" = "command".objid;
            OPEN "triggers" FOR
                SELECT * FROM @extschema@.get_inherit_triggers() "t"
                WHERE "t"."parentid" = "triggerid" AND "t"."is_inherited" = FALSE;
        ELSE
            CONTINUE;
        END IF;

        LOOP
            FETCH NEXT FROM "triggers" INTO "trigger";
            EXIT WHEN "trigger" IS NULL;

            "name" = @extschema@.get_child_trigger_name("trigger"."parentname", "trigger"."parentrelid"::REGCLASS, "trigger"."childrelid"::REGCLASS);
            "query" = @extschema@.get_child_trigger_def("trigger"."parentdef", "trigger"."parentname", "trigger"."parentrelid"::REGCLASS, "trigger"."childrelid"::REGCLASS);
            RAISE NOTICE USING MESSAGE = format('-- ADD TRIGGER %1I TO %2s TABLE FROM %3s TABLE', "name", "trigger"."childrelid"::REGCLASS, "trigger"."parentrelid"::REGCLASS);
            RAISE NOTICE USING MESSAGE = "query";
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
CREATE OR REPLACE FUNCTION @extschema@.event_trigger_drop_inherit_constraints ()
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
                "name" = @extschema@.get_child_constraint_name("name", "parent"::REGCLASS, "child"::REGCLASS);
                "query" = format('ALTER TABLE %1s DROP CONSTRAINT IF EXISTS %2I;', "child"::REGCLASS, "name");
                RAISE NOTICE USING MESSAGE = format('-- DROP CONSTRAINT %1I FROM %2s TABLE BASED ON DEPENDENCY ON %3s TABLE', "name", "child"::REGCLASS, "parent"::REGCLASS);
                RAISE NOTICE USING MESSAGE = "query";
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
CREATE OR REPLACE FUNCTION @extschema@.event_trigger_drop_inherit_triggers ()
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
                "name" = @extschema@.get_child_trigger_name("name", "parent"::REGCLASS, "child"::REGCLASS);
                "query" = format('DROP TRIGGER IF EXISTS %1I ON %2s;', "name", "child"::REGCLASS);
                RAISE NOTICE USING MESSAGE = format('-- DROP TRIGGER %1I FROM %2s TABLE BASED ON DEPENDENCY ON %3s TABLE', "name", "child"::REGCLASS, "parent"::REGCLASS);
                RAISE NOTICE USING MESSAGE = "query";
                EXECUTE "query";
            END LOOP;
        END IF;
    END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;
