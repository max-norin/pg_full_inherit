CREATE TABLE public.cities
(
    id   SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE public.langs
(
    id   SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE
);


CREATE FUNCTION public.trigger_check_email()
    RETURNS TRIGGER
AS
$$
BEGIN
    IF (strpos(NEW.email, '@') = 0) THEN
        RAISE EXCEPTION 'email is not valid';
    END IF;

    RETURN NEW;
END
$$
    LANGUAGE plpgsql
    VOLATILE
    SECURITY DEFINER;

CREATE FUNCTION public.trigger_lower_username()
    RETURNS TRIGGER
AS
$$
BEGIN
    NEW.username = lower(NEW.username);

    RETURN NEW;
END
$$
    LANGUAGE plpgsql
    VOLATILE
    SECURITY DEFINER;

CREATE FUNCTION public.trigger_check_username()
    RETURNS TRIGGER
AS
$$
BEGIN
    IF (NEW.username ~* '^[a-z0-9]+$') THEN
        RAISE EXCEPTION 'username is not valid';
    END IF;

    RETURN NEW;
END
$$
    LANGUAGE plpgsql
    VOLATILE
    SECURITY DEFINER;

CREATE FUNCTION public.trigger_auto_bio()
    RETURNS TRIGGER
AS
$$
BEGIN
    IF (NEW.bio IS NULL OR length(NEW.bio) = 0) THEN
        NEW.bio = '----';
    END IF;

    RETURN NEW;
END
$$
    LANGUAGE plpgsql
    VOLATILE
    SECURITY DEFINER;
