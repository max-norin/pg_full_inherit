CREATE FUNCTION public.get_child_trigger_def ("parentdef" TEXT, "parentname" TEXT, "parent" TEXT, "child" TEXT)
    RETURNS TEXT
AS $$
BEGIN
    RETURN regexp_replace (
            replace ("parentdef", "parent", "child"),
            '(CREATE (CONSTRAINT )?TRIGGER) ' || "parentname",
            '\1 ' || abstract.get_child_trigger_name("parentname", "parent", "child"));
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов
