CREATE OR REPLACE FUNCTION public.constraint_child_from_parent ("name" TEXT, "parent" TEXT, "child" TEXT)
    RETURNS TEXT
AS $$
BEGIN
    RETURN regexp_replace("name", '^' || "parent", "child");
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION public.constraint_child_from_parent (TEXT, TEXT, TEXT) IS '';
