
-- Trigger fuer Fortfuehrung der PostNAS-Datenbank, wenn KEINE Historie gefuehrt werden soll.
-- Version
--  2014-01-31 PostNAS 0.7
--  2014-09-08 PostNAS 0.8

CREATE TRIGGER delete_feature_trigger
	BEFORE INSERT ON delete
	FOR EACH ROW
	EXECUTE PROCEDURE delete_feature_kill_silent();

-- 2013-07-10: Erweiterung zur Behandlung der Replace-Saetze in den Beziehungen
-- 2014-01-31: entfaellt, wird ersetzt durch "update_import_id"
--CREATE TRIGGER update_fields
--	BEFORE INSERT ON alkis_beziehungen
--	FOR EACH ROW
--	EXECUTE PROCEDURE update_fields_beziehungen();

-- 2014-01-31: Den Relationen in "alkis_beziehungen" die laufende Nummer des Konverter-Laufes zuzuordnen.
-- Dies ermoeglicht bei Aenderungen das saubere Loeschen alter Relationen im Trigger.
-- 2014-09-08 in PostNAS 0.8 deaktiviert
/*
CREATE TRIGGER update_import_id
	BEFORE INSERT ON alkis_beziehungen
	FOR EACH ROW
	EXECUTE PROCEDURE get_import_id();
*/
