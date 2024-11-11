CREATE FUNCTION public.get_child_trigger_def ("parentdef" TEXT, "parentname" TEXT, "parent" REGCLASS, "child" REGCLASS)
    RETURNS TEXT
AS $$
BEGIN
    RETURN regexp_replace (
            replace ("parentdef", public.get_table_name("parent", TRUE), public.get_table_name("child", TRUE)),
            '(CREATE (CONSTRAINT )?TRIGGER) ' || quote_ident ("parentname"),
            '\1 ' || quote_ident (public.get_child_trigger_name("parentname", "parent", "child")));
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов
