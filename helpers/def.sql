CREATE FUNCTION public.get_child_triggerdef ("parentdef" TEXT, "parentname" TEXT, "parent" TEXT, "child" TEXT)
    RETURNS TEXT
AS $$
BEGIN
    RETURN replace (
            replace ("parentdef", "parent", "child"),
            'CREATE TRIGGER ' || "parentname",
            'CREATE TRIGGER ' || public.get_child_trigger_name("parentname", "parent", "child"));
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов
