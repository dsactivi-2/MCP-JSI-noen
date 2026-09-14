-- Benachrichtigung bei Statusaenderung (wie C4-C9 im alten CRM, aber schlank)
-- Achtung: laeuft als Tabellen-Eigentuemer, kein Recht des MCP noetig.

CREATE OR REPLACE FUNCTION trg_kandidat_status_change() RETURNS trigger
LANGUAGE plpgsql AS $t$
BEGIN
  IF EXISTS (SELECT 1 FROM notification_settings WHERE key = 'status_change' AND enabled) THEN
    INSERT INTO status_notifications (candidate_id, old_status, new_status)
    VALUES (NEW.kandidat_id, OLD.kandidat_status, NEW.kandidat_status);
  END IF;
  RETURN NEW;
END;
$t$;

DROP TRIGGER IF EXISTS kandidat_status_change ON idk_kandidati;
CREATE TRIGGER kandidat_status_change
  AFTER UPDATE OF kandidat_status ON idk_kandidati
  FOR EACH ROW
  WHEN (OLD.kandidat_status IS DISTINCT FROM NEW.kandidat_status)
  EXECUTE FUNCTION trg_kandidat_status_change();
