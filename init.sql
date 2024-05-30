CREATE EVENT TRIGGER "add_inherit_constraints" ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE', 'ALTER TABLE')
EXECUTE PROCEDURE public.event_trigger_add_inherit_constraints ();

CREATE EVENT TRIGGER "drop_inherit_constraints" ON sql_drop
    WHEN TAG IN ('ALTER TABLE')
EXECUTE PROCEDURE public.event_trigger_drop_inherit_constraints ();


CREATE EVENT TRIGGER "add_inherit_triggers" ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE', 'ALTER TABLE', 'CREATE TRIGGER')
EXECUTE PROCEDURE public.event_trigger_add_inherit_triggers ();

CREATE EVENT TRIGGER "drop_inherit_triggers" ON sql_drop
    WHEN TAG IN ('DROP TRIGGER')
EXECUTE PROCEDURE public.event_trigger_drop_inherit_triggers ();
