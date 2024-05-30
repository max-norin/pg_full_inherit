CREATE FUNCTION public.get_child_constraint_name ("name" TEXT, "parent" TEXT, "child" TEXT)
    RETURNS TEXT
AS $$
BEGIN
    RETURN regexp_replace("name", '^' || "parent", "child");
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION public.get_child_constraint_name (TEXT, TEXT, TEXT) IS '';

CREATE FUNCTION public.get_child_trigger_name ("name" TEXT, "parent" TEXT, "child" TEXT)
    RETURNS TEXT
AS $$
BEGIN
    RETURN "name";
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION public.get_child_trigger_name (TEXT, TEXT, TEXT) IS '';
