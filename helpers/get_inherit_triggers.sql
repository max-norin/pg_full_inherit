CREATE FUNCTION public.get_inherit_triggers ()
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
    -- https://www.postgresql.org/docs/current/catalog-pg-trigger.html
    -- https://www.postgresql.org/docs/current/catalog-pg-inherits.html
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
                      AND public.get_child_trigger_def("pc"."tgdef", "pc"."tgname":: TEXT, "i"."inhparent"::REGCLASS::TEXT, "i"."inhrelid"::REGCLASS::TEXT) = "cc"."tgdef"
        WHERE "pc"."oid" IS NOT NULL OR "cc"."oid" IS NOT NULL;
END
$$
LANGUAGE plpgsql
STABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов внутри одного SQL запроса
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов
