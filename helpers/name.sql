CREATE FUNCTION public.get_child_constraint_name ("name" TEXT, "parent" REGCLASS, "child" REGCLASS)
    RETURNS TEXT
AS $$
BEGIN
    RETURN regexp_replace("name", '^' || public.get_table_name("parent", FALSE), public.get_table_name("child", FALSE));
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

CREATE FUNCTION public.get_child_trigger_name ("name" TEXT, "parent" REGCLASS, "child" REGCLASS)
    RETURNS TEXT
AS $$
BEGIN
    RETURN "name";
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов
