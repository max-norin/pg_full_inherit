CREATE EVENT TRIGGER "add_constraints_from_parent_tables" ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE', 'ALTER TABLE')
EXECUTE PROCEDURE public.event_trigger_add_constraints_from_parent_tables ();

CREATE EVENT TRIGGER "drop_constraints_from_parent_tables" ON sql_drop
    WHEN TAG IN ('ALTER TABLE')
EXECUTE PROCEDURE public.event_trigger_drop_constraints_from_parent_tables ();


CREATE EVENT TRIGGER "add_triggers_from_parent_tables" ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE', 'ALTER TABLE', 'CREATE TRIGGER')
EXECUTE PROCEDURE public.event_trigger_add_triggers_from_parent_tables ();

CREATE EVENT TRIGGER "drop_triggers_from_parent_tables" ON sql_drop
    WHEN TAG IN ('DROP TRIGGER')
EXECUTE PROCEDURE public.event_trigger_drop_triggers_from_parent_tables ();
