CREATE FUNCTION public.get_constraints ()
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
    -- https://postgresql.org/docs/current/catalog-pg-constraint.html
    -- https://www.postgresql.org/docs/current/catalog-pg-inherits.html
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
STABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов внутри одного SQL запроса
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION public.get_constraints () IS '';
