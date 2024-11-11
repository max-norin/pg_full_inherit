CREATE FUNCTION public.get_table_name ("relid" REGCLASS, "is_full" BOOLEAN = TRUE)
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
