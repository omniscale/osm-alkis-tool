-- Variante von delete_feature_kill. Fehlende Objekte im Datenbestand führen hier
-- nicht zu einer Exception. Hintergrund: Wenn Objekt-Geometrie ungültig war und deshalb
-- nicht importiert werden konnte und anschließend geändert oder gelöscht wird, dann würde
-- dies zu einem Abbruch des Imports führen.
CREATE OR REPLACE FUNCTION delete_feature_kill_silent() RETURNS TRIGGER AS $$
DECLARE
    n INTEGER;
    vbeginnt TEXT;
    replgml TEXT;
    featgml TEXT;
    s TEXT;
BEGIN
    -- Version 2014-09-23, replace führt auch zum Löschen des Vorgängerobjektes
    NEW.context := coalesce(lower(NEW.context),'delete');

    IF NEW.anlass IS NULL THEN
        NEW.anlass := '';
    END IF;

    -- gml_id mit urn:adv:oid: prefix (Smallworld)
    IF length(NEW.featureid)=44 AND substr(NEW.featureid, 1, 12) = 'urn:adv:oid:' THEN
        NEW.featureid = substr(NEW.featureid, 13);
    END IF;

    featgml := substr(NEW.featureid, 1, 16); -- gml_id ohne Timestamp

    IF length(NEW.featureid)=32 THEN
        -- beginnt-Zeit der zu löschenden Vorgaenger-Version des Objektes
        vbeginnt := substr(NEW.featureid, 17, 4) || '-'
            || substr(NEW.featureid, 21, 2) || '-'
            || substr(NEW.featureid, 23, 2) || 'T'
            || substr(NEW.featureid, 26, 2) || ':'
            || substr(NEW.featureid, 28, 2) || ':'
            || substr(NEW.featureid, 30, 2) || 'Z' ;
    ELSIF length(NEW.featureid)=16 THEN
        -- Ältestes nicht gelöschtes Objekt
        EXECUTE 'SELECT min(beginnt) FROM ' || NEW.typename
            || ' WHERE gml_id=''' || featgml || '''' || ' AND endet IS NULL'
            INTO vbeginnt;

        IF vbeginnt IS NULL THEN
            RAISE EXCEPTION '%: Keinen Kandidaten zum Löschen gefunden.', NEW.featureid;
        END IF;
    ELSE
        RAISE EXCEPTION '%: Identifikator gescheitert.', NEW.featureid;
    END IF;

    IF NEW.context='delete' THEN
    ELSIF NEW.context='update' THEN
    ELSIF NEW.context='replace' THEN
        NEW.safetoignore := lower(NEW.safetoignore);
        IF NEW.safetoignore IS NULL THEN
            RAISE EXCEPTION '%: safeToIgnore nicht gesetzt.', NEW.featureid;
        ELSIF NEW.safetoignore<>'true' AND NEW.safetoignore<>'false' THEN
            RAISE EXCEPTION '%: safeToIgnore ''%'' ungültig (''true'' oder ''false'' erwartet).', NEW.featureid, NEW.safetoignore;
        END IF;
    ELSE
        RAISE EXCEPTION '%: Ungültiger Kontext % (''delete'', ''replace'' oder ''update'' erwartet).', NEW.featureid, NEW.context;
    END IF;

    -- Vorgaenger ALKIS-Objekt Loeschen
    s := 'DELETE FROM ' || NEW.typename || ' WHERE gml_id=''' || featgml || ''' AND beginnt=''' || vbeginnt || '''' ;
    EXECUTE s;
    GET DIAGNOSTICS n = ROW_COUNT;
    -- RAISE NOTICE 'SQL[%]:%', n, s;
    IF n<>1 THEN
        -- XXX: WARNING statt EXCEPTION
        RAISE WARNING '%: % schlug fehl [%]', NEW.featureid, NEW.context, n;
        -- dieser Satz kommt nicht in die delete-Tabelle?
    END IF;

    NEW.ignored := false;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
