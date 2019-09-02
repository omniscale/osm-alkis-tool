-- alkis-functions.sql - Trigger-Funktionen für die Fortführung der 
--                       alkis_beziehungen aus Einträgen der delete-Tabelle

-- 2013-07-10: Erweiterung zur Verarbeitung der Replace-Sätze in ALKIS-Beziehungen 

-- 2013-12-10:	In der Function "update_fields_beziehungen" den Fall behandeln, dass ein Objekt einer 
--             neuen Beziehung in keiner Tabelle gefunden wird.
--             Wenn ein einzelnes Objekt fehlt, soll dies keine Auswirkungen auf andere Objekte haben.
--             Füllen von "zu_typename" auskommentiert.

-- 2014-01-31: Deaktivieren von "update_fields_beziehungen", 
--             statt dessen verwenden der "import_id" um alte Relationen zu identifizieren und zu löschen.

-- 2014-08-27: Angleichung des Datenbank-Schema an die NorBIT-Version.
--             Die Trigger-Function "delete_feature_kill()" arbeitet falsch, wenn "gml_id" als "character varying" angelegt ist.
--             Das Format war bisher charachter(16).
--             Zugriff auf die Spalte gml_id umgestellt von "=" auf "like" um den individuellen Timestamp zu ignorieren.

-- 2014-09-04  Trigger-Funktion "delete_feature_kill()" angepasst: keine Tabelle "alkis_beziehungen" mehr.

-- 2014-09-11  Functions auskommentiert oder gelöscht, die "alkis_beziehungen" benötigen:
--               "alkis_mviews()", delete_feature_kill_vers07(), alkis_beziehung_inserted()
--             Trigger-Function "delete_feature_hist" durch aktuelle Version aus OSGeo4W ersetzt.

-- 2014-09-19  FJ: Korrektur "delete_feature_hist()":
--             Ausgehend von Version: https://raw.githubusercontent.com/norBIT/alkisimport/master/alkis-functions.sql
--             Bei der Erstabagabe mit Vollhistorie (ibR) werden mehrere Zwischenstände von Objekten eingelesen.
--             Einige davon wurden bereits mit "endet" ausgeliefert (in replace-Sätzen).
--             Wenn der Trigger ausgelöst wird (in einem zweiten Durchlauf von PostNAS) kann es jeweils
--             mehrerer Vorgänger- und Nachfolger-Objekte mit und ohne "endet IS NULL" geben.

-- 2014-09-23  FJ: Korrektur "delete_feature_kill()":
--             Die neue Hist-Version vereinfachen (endet nicht benötigt) und zum Löschen umbauen.

-- Table/View/Sequence löschen, wenn vorhanden
CREATE OR REPLACE FUNCTION alkis_dropobject(t TEXT) RETURNS varchar AS $$
DECLARE
	c RECORD;
	s varchar;
	r varchar;
	d varchar;
	i integer;
	tn varchar;
BEGIN
	r := '';
	d := '';

	-- drop objects
	FOR c IN SELECT relkind,relname
		FROM pg_class
		JOIN pg_namespace ON pg_class.relnamespace=pg_namespace.oid
		WHERE pg_namespace.nspname='public' AND pg_class.relname=t
		ORDER BY relkind
	LOOP
		IF c.relkind = 'v' THEN
			r := r || d || 'Sicht ' || c.relname || ' gelöscht.';
			EXECUTE 'DROP VIEW ' || c.relname || ' CASCADE';
		ELSIF c.relkind = 'r' THEN
			r := r || d || 'Tabelle ' || c.relname || ' gelöscht.';
			EXECUTE 'DROP TABLE ' || c.relname || ' CASCADE';
		ELSIF c.relkind = 'S' THEN
			r := r || d || 'Sequenz ' || c.relname || ' gelöscht.';
			EXECUTE 'DROP SEQUENCE ' || c.relname;
		ELSIF c.relkind <> 'i' THEN
			r := r || d || 'Typ ' || c.table_type || '.' || c.table_name || ' unerwartet.';
		END IF;
		d := E'\n';
	END LOOP;

	FOR c IN SELECT indexname FROM pg_indexes WHERE schemaname='public' AND indexname=t
	LOOP
		r := r || d || 'Index ' || c.indexname || ' gelöscht.';
		EXECUTE 'DROP INDEX ' || c.indexname;
		d := E'\n';
	END LOOP;

	FOR c IN SELECT proname,proargtypes
		FROM pg_proc
		JOIN pg_namespace ON pg_proc.pronamespace=pg_namespace.oid
		WHERE pg_namespace.nspname='public' AND pg_proc.proname=t
	LOOP
		r := r || d || 'Funktion ' || c.proname || ' gelöscht.';

		s := 'DROP FUNCTION ' || c.proname || '(';
		d := '';

		FOR i IN array_lower(c.proargtypes,1)..array_upper(c.proargtypes,1) LOOP
			SELECT typname INTO tn FROM pg_type WHERE oid=c.proargtypes[i];
			s := s || d || tn;
			d := ',';
		END LOOP;

		s := s || ')';

		EXECUTE s;

		d := E'\n';
	END LOOP;

	FOR c IN SELECT relname,conname
		FROM pg_constraint
		JOIN pg_class ON pg_constraint.conrelid=pg_constraint.oid
		JOIN pg_namespace ON pg_constraint.connamespace=pg_namespace.oid
		WHERE pg_namespace.nspname='public' AND pg_constraint.conname=t
	LOOP
		r := r || d || 'Constraint ' || c.conname || ' von ' || c.relname || ' gelöscht.';
		EXECUTE 'ALTER TABLE ' || c.relname || ' DROP CONSTRAINT ' || c.conname;
		d := E'\n';
	END LOOP;

	RETURN r;
END;
$$ LANGUAGE plpgsql;

-- Alle ALKIS-Tabellen löschen
SELECT alkis_dropobject('alkis_drop');
CREATE FUNCTION alkis_drop() RETURNS varchar AS $$
DECLARE
	c RECORD;
	r VARCHAR;
	d VARCHAR;
BEGIN
	r := '';
	d := '';
	-- drop tables & views
	FOR c IN SELECT table_type,table_name FROM information_schema.tables WHERE table_schema='public' AND ( substr(table_name,1,3) IN ('ax_','ap_','ks_') OR table_name IN ('alkis_beziehungen','delete')) ORDER BY table_type DESC LOOP
		IF c.table_type = 'VIEW' THEN
			r := r || d || 'Sicht ' || c.table_name || ' gelöscht.';
			EXECUTE 'DROP VIEW ' || c.table_name || ' CASCADE';
		ELSIF c.table_type = 'BASE TABLE' THEN
			r := r || d || 'Tabelle ' || c.table_name || ' gelöscht.';
			EXECUTE 'DROP TABLE ' || c.table_name || ' CASCADE';
		ELSE
			r := r || d || 'Typ ' || c.table_type || '.' || c.table_name || ' unerwartet.';
		END IF;
		d := E'\n';
	END LOOP;

	-- clean geometry_columns
	DELETE FROM geometry_columns
		WHERE f_table_schema='public'
		AND ( substr(f_table_name,1,2) IN ('ax_','ap_','ks_')
		 OR f_table_name IN ('alkis_beziehungen','delete') );

	RETURN r;
END;
$$ LANGUAGE plpgsql;

-- Alle ALKIS-Tabellen leeren
SELECT alkis_dropobject('alkis_delete');
CREATE FUNCTION alkis_delete() RETURNS varchar AS $$
DECLARE
	c RECORD;
	r varchar;
	d varchar;
BEGIN
	r := '';
	d := '';

	-- drop views
	FOR c IN
		SELECT table_name
		FROM information_schema.tables
		WHERE table_schema='public' AND table_type='BASE TABLE'
		  AND ( substr(table_name,1,3) IN ('ax_','ap_','ks_')
			OR table_name IN ('alkis_beziehungen','delete') )
	LOOP
		r := r || d || c.table_name || ' wurde geleert.';
		EXECUTE 'DELETE FROM '||c.table_name;
		d := E'\n';
	END LOOP;

	RETURN r;
END;
$$ LANGUAGE plpgsql;

-- Übersicht erzeugen, die alle alkis_beziehungen mit den Typen der beteiligen ALKIS-Objekte versieht
/*
SELECT alkis_dropobject('alkis_mviews');
CREATE FUNCTION alkis_mviews() RETURNS varchar AS $$
DECLARE
	sql TEXT;
	delim TEXT;
	c RECORD;
BEGIN
	SELECT alkis_dropobject('vbeziehungen') INTO sql;
	SELECT alkis_dropobject('vobjekte') INTO sql;

	delim := '';
	sql := 'CREATE VIEW vobjekte AS ';

	FOR c IN SELECT table_name FROM information_schema.columns WHERE column_name='gml_id' AND substr(table_name,1,3) IN ('ax_','ap_','ks_') LOOP
		sql := sql || delim || 'SELECT gml_id,beginnt,''' || c.table_name || ''' AS table_name FROM ' || c.table_name;
		delim := ' UNION ';
	END LOOP;

	EXECUTE sql;

	CREATE VIEW vbeziehungen AS
		SELECT	beziehung_von,(SELECT table_name FROM vobjekte WHERE gml_id=beziehung_von) AS typ_von
			,beziehungsart
			,beziehung_zu,(SELECT table_name FROM vobjekte WHERE gml_id=beziehung_zu) AS typ_zu
		FROM alkis_beziehungen;

	RETURN 'ALKIS-Views erzeugt.';
END;
$$ LANGUAGE plpgsql;
*/

-- Indizes erzeugen
SELECT alkis_dropobject('alkis_update_schema');
CREATE FUNCTION alkis_update_schema() RETURNS varchar AS $$
DECLARE
	sql TEXT;
	c RECORD;
	i RECORD;
	n INTEGER;
BEGIN
	-- Spalten in delete ergänzen
	SELECT count(*) INTO n FROM information_schema.columns WHERE table_schema='public' AND table_name='delete' AND column_name='ignored';
	IF n=0 THEN
		ALTER TABLE "delete" ADD ignored BOOLEAN;
	END IF;

	SELECT count(*) INTO n FROM information_schema.columns WHERE table_schema='public' AND table_name='delete' AND column_name='context';
	IF n=0 THEN
		ALTER TABLE "delete" ADD context VARCHAR;
	END IF;

	SELECT count(*) INTO n FROM information_schema.columns WHERE table_schema='public' AND table_name='delete' AND column_name='safetoignore';
	IF n=0 THEN
		ALTER TABLE "delete" ADD safetoignore VARCHAR;
	END IF;

	SELECT count(*) INTO n FROM information_schema.columns WHERE table_schema='public' AND table_name='delete' AND column_name='replacedby';
	IF n=0 THEN
		ALTER TABLE "delete" ADD replacedBy VARCHAR;
	END IF;

	-- Spalte identifier ergänzen, wo sie fehlt
	FOR c IN SELECT table_name FROM information_schema.columns a WHERE a.column_name='gml_id'
		AND     EXISTS (SELECT * FROM information_schema.columns b WHERE b.column_name='beginnt'    AND a.table_catalog=b.table_catalog AND a.table_schema=b.table_schema AND a.table_name=b.table_name)
		AND NOT EXISTS (SELECT * FROM information_schema.columns b WHERE b.column_name='identifier' AND a.table_catalog=b.table_catalog AND a.table_schema=b.table_schema AND a.table_name=b.table_name)
	LOOP
		EXECUTE 'ALTER TABLE ' || c.table_name || ' ADD identifier character(44)';
	END LOOP;

	-- Spalte endet ergänzen, wo sie fehlt
	FOR c IN SELECT table_name FROM information_schema.columns a WHERE a.column_name='gml_id'
		AND     EXISTS (SELECT * FROM information_schema.columns b WHERE b.column_name='beginnt' AND a.table_catalog=b.table_catalog AND a.table_schema=b.table_schema AND a.table_name=b.table_name)
		AND NOT EXISTS (SELECT * FROM information_schema.columns b WHERE b.column_name='endet'   AND a.table_catalog=b.table_catalog AND a.table_schema=b.table_schema AND a.table_name=b.table_name)
	LOOP
		EXECUTE 'ALTER TABLE ' || c.table_name || ' ADD endet character(20) CHECK (endet>beginnt)';
	END LOOP;

	-- Lebensdauer-Constraint ergänzen
	FOR c IN SELECT table_name FROM information_schema.columns a WHERE a.column_name='gml_id'
		AND EXISTS (SELECT * FROM information_schema.columns b WHERE b.column_name='beginnt' AND a.table_catalog=b.table_catalog AND a.table_schema=b.table_schema AND a.table_name=b.table_name)
		AND EXISTS (SELECT * FROM information_schema.columns b WHERE b.column_name='endet'   AND a.table_catalog=b.table_catalog AND a.table_schema=b.table_schema AND a.table_name=b.table_name)
	LOOP
		SELECT alkis_dropobject(c.table_name||'_lebensdauer');
		EXECUTE 'ALTER TABLE ' || c.table_name || ' ADD CONSTRAINT ' || c.table_name || '_lebensdauer CHECK (beginnt IS NOT NULL AND endet>beginnt)';
	END LOOP;

	-- Indizes aktualisieren
	FOR c IN SELECT table_name FROM information_schema.columns a WHERE a.column_name='gml_id'
		AND EXISTS (SELECT * FROM information_schema.columns b WHERE b.column_name='beginnt' AND a.table_catalog=b.table_catalog AND a.table_schema=b.table_schema AND a.table_name=b.table_name)
	LOOP
		-- Vorhandene Indizes droppen (TODO: Löscht auch die Sonderfälle - entfernen)
		FOR i IN EXECUTE 'SELECT indexname FROM pg_indexes WHERE NOT indexname LIKE ''%_pk'' AND schemaname=''public'' AND tablename='''||c.table_name||'''' LOOP
			EXECUTE 'DROP INDEX ' || i.indexname;
		END LOOP;

		-- Indizes erzeugen
		EXECUTE 'CREATE UNIQUE INDEX ' || c.table_name || '_id ON ' || c.table_name || '(gml_id,beginnt)';
		EXECUTE 'CREATE UNIQUE INDEX ' || c.table_name || '_ident ON ' || c.table_name || '(identifier)';
		EXECUTE 'CREATE INDEX ' || c.table_name || '_gmlid ON ' || c.table_name || '(gml_id)';
		EXECUTE 'CREATE INDEX ' || c.table_name || '_beginnt ON ' || c.table_name || '(beginnt)';
		EXECUTE 'CREATE INDEX ' || c.table_name || '_endet ON ' || c.table_name || '(endet)';
	END LOOP;

	-- Geometrieindizes aktualisieren
	FOR c IN SELECT table_name FROM information_schema.columns a WHERE a.column_name='gml_id'
		AND EXISTS (SELECT * FROM information_schema.columns b WHERE b.column_name='wkb_geometry' AND a.table_catalog=b.table_catalog AND a.table_schema=b.table_schema AND a.table_name=b.table_name)
	LOOP
		EXECUTE 'CREATE INDEX ' || c.table_name || '_geom ON ' || c.table_name || ' USING GIST (wkb_geometry)';
	END LOOP;

	RETURN 'Schema aktualisiert.';
END;
$$ LANGUAGE plpgsql;


-- Im Trigger 'delete_feature_trigger' muss eine dieser beiden Funktionen
-- (delete_feature_hist oder delete_feature_kill) verlinkt werden, je nachdem ob nur
-- aktuelle oder auch historische Objekte in der Datenbank geführt werden sollen.


/*	Beschreibung und Umfeld des "delete_feature_trigger":
	-----------------------------------------------------

Der Konverter "ogr2ogr", in den PostNAS als Eingabe-Modul für das NAS-Format eingebettet ist, 
ist vom Wesen her eigentlich ein 1:1-Konverter.
Üblicherweise liest er ein Eingabe-GIS-Format, analysiert es und erzeugt dann die gleiche Struktur in 
einem Ausgabe-GIS-Format.
Das ALKIS-Format "NAS" als einmaliger Datenauszug (enthält nur Funktion "insert") könnte in diesem 
Rahmen vielleicht auch ohne Trigger umgesetzt werden.

Viel komplexer umzusetzen sind jedoch solche NAS-Daten, die im Rahmen des NBA-Verfahrens von ALKIS abgegeben werden.
		NBA  =  Nutzerbezogene Bestandsdaten-Aktualisierung.
In einem NBA-Verfahren wird eine primäre Datenquelle (ALKIS) mit einem Sekundärbestand (PostGIS) synchronisiert.
Es erfolgt zunächst eine Erstabgabe für einen definierten Zeitpunkt.
Später gibt es Aktualisierungen auf weitere Zeitpunkte. Die dazu übermittelten Differenzdaten enthalten
nicht nur reine Daten (INSERT) sondern auch Anweisungen zur Änderung der zu früheren Zeitpunkten übermittelten Daten.
Diese Änderungs-Anweisungen werden innerhalb des Konverters ogr2ogr nicht komplett verarbeitet.
Er verarbeitet zunächst nur die enthaltenen Datenfelder zum Objekt, die er in neue Zeilen in die Objekt-Tabellen einstellt.

Anschließend werden Informationen zum Objektschlüssel (gml_id) und zur Lebensdauer des Objektes (beginnt) zusammen 
mit der Operation (Kontext = "delete", "update" oder "replace") in die Tabelle "delete" eingetragen.
Dieser Eintrag in "delete" löst den Trigger aus, der sich dann darum kümmert, Löschungen oder 
Änderungen an Vorgängerversionen vorzunehmen.

Im NBA-Verfahren sind verschiedene "Abgabearten" möglich:
Die Abgabeart 1000 hat zum Ziel, im Sekundärbestand jeweils den letzten aktuellen Stand bereit zu stellen.
Die Abgabeart 3100 hat zum Ziel, im Sekundärbestand eine komplette Historie bereit zu stellen, die auch alle
Zwischenstände enthält. Ein nicht mehr gültiges Objekt wird dann mit einem Eintrag in "endet" deaktiviert, 
verbleibt aber in der Datenbank. Bei der Abgabeart 3100 sind bereits in der Erstabgabe Aktualisierungs-
Funktionen (delete, update, replace) enthalten weil mehrere historische Versionen von Objekten geliefert werden.

Eine NBA-Lieferung für ein Gebiet ist in mehrere Dateien aufgeteilt, die nacheinander abgearbeitet werden.
Erst mit der Verarbeitung der letzten Datei einer Lieferung ist die Datenbank wieder konsistent und zeigt den
Zustand zum neuen Abgabezeitpunkt.

Jede dieser NAS-Dateien wird von PostNAS in mehreren Durchläufen vearbeitet.
1. Im ersten Durchlauf wird die 1:1-Konvertierung der Daten vorgenommen. 
   Die Feldinhalte der NAS-Datei werden in neue Zeilen in die Objekttabellen der Datenbank übertragen. 
2. Dann werden in einem weiteren Durchlauf die Operationen "delete", "update" und "replace" verarbeitet.
   Diese werden von PostNAS in die Tabelle "delete" eingetragen, dies löst den Trigger aus.
	
Für die Arbeitsweise des Triggers bedeutet das:

An dem Zeitpunkt, an dem der Trigger ausgelöst wird, stehen bereits alle Daten zu den Objekten in den Objekt-Tabellen.
Darin ist aber möglicherweise das Feld "endet" noch nicht gefüllt. 

Während der Konvertierung der Erstabgabe einer NBA-Abgabe der Abgabeart 3100 können aber Objekte doch schon beendet sein.
Bei einer Erstabgabe der Abgabeart 3100 können mehrere Generation des selben Objektes vorhanden sein, 
die alle in der gleichen NAS-Datei geliefert wurden. 
Das Feld "endet" ist dann nicht geeignet zu entscheiden, welches die letzte (aktuelle) Version ist.

Es kann vorkommen, dass Zwischenversionen in der Objekt-Tabelle bereits beendet sind weil sie direkt mit ihrem 
Endet-Datum geliefert wurden. Dieses wurde bereits beim ersten Durchlauf von ogr2ogr wie ein normales Datenfeld eingetragen.
In Beispieldaten wurde analysiert, dass ein bereits beendetes Objekt in einem "insert" kein "endet" mitbringt. 
Dies muss vom Trigger beendet werden, wenn dieser einen replace für den Nachfolger bekommt.

Im gleichen Bestand wurden jedoch Nachfolger gefunden die mit einem "replace"-Satz gekommen sind 
und bereits beendet waren, weil sie ihrerseits wieder Nachfolger hatten. 

Das jeweils folgende "replace" kann also ein Vorgänger-Objekt mit oder ohne "endet"-Eintrag vorfinden.
Es können auch sowohl Vorgänger- als auch bereits Nachfolger-Versionen eines Objektes vorhanden sein, wenn der Trigger
ausgelöst wird.

Aufgabe des Triggers ist es, zu einem veränderten Objekt jeweils den unmittelbaren Vorgänger zu ermitteln
und - falls noch nicht geschehen - den passenden endet-Eintrag nachzutragen.
Wenn in den Daten kein "endet" mitgeliefert wird, dann wird der Beginn der Folge-Version des Objektes verwendet
um den Vorgänger zu beenden.

Wenn ein Objekt bereits mit endet-Datum geliefert wurde, dann wird dies zwar in die Obkjekt-Tabelle eingetragen,
der endet-Eintrag in dem replace-Satz in der delete-Tabelle, der den Trigger auslöst, ist trotzdem leer.
Es ist überlegen, ob dies im PostNAS-Programm geändert werden sollte.

Aufgrund der Komplexität dieser Mechanismen ist davon auszugehen, dass es Hersteller-spezifische Unterschiede
gibt und auch Unterschiede zuwischen verschiedenen Versions-Ständen des selben Herstellers.
Die Arbeitsweise des Triggers muss daher regelmäßig überprüft werden.

*/

-- Achtung: Für diese Trigger-Version müssen die Schlüsselfelder "gml_id" in allen Tabellen 
--          wieder auf 16 Stellen fix gekürzt werden!

-- Löschsatz verarbeiten (MIT Historie)
-- context='delete'        => "endet" auf aktuelle Zeit setzen
-- context='replace'       => "endet" des ersetzten auf "beginnt" des neuen Objekts setzen
-- context='update'        => "endet" auf übergebene Zeit setzen und "anlass" festhalten
-- Die "gml_id" muss in der Datenbank das Format character(16) haben.
CREATE OR REPLACE FUNCTION delete_feature_hist() RETURNS TRIGGER AS $$
DECLARE
	n INTEGER;
	vbeginnt TEXT;
	replgml TEXT;
	featgml TEXT;
	s TEXT;
BEGIN
	NEW.context := coalesce(lower(NEW.context),'delete');

	IF NEW.anlass IS NULL THEN
		NEW.anlass := '';
	END IF;
	featgml := substr(NEW.featureid, 1, 16); -- gml_id ohne Timestamp

	IF length(NEW.featureid)=32 THEN
		-- beginnt-Zeit der zu ersetzenden Vorgaenger-Version des Objektes
		vbeginnt := substr(NEW.featureid, 17, 4) || '-'
			|| substr(NEW.featureid, 21, 2) || '-'
			|| substr(NEW.featureid, 23, 2) || 'T'
			|| substr(NEW.featureid, 26, 2) || ':'
			|| substr(NEW.featureid, 28, 2) || ':'
			|| substr(NEW.featureid, 30, 2) || 'Z' ;
	ELSIF length(NEW.featureid)=16 THEN
		-- Ältestes nicht gelöschtes Objekt
		EXECUTE 'SELECT min(beginnt) FROM ' || NEW.typename
		        || ' WHERE gml_id=''' || featgml || ''''
		        || ' AND endet IS NULL'
			INTO vbeginnt;

		IF vbeginnt IS NULL THEN
			RAISE EXCEPTION '%: Keinen Kandidaten zum Löschen gefunden.', NEW.featureid;
		END IF;
	ELSE
		RAISE EXCEPTION '%: Identifikator gescheitert.', NEW.featureid;
	END IF;

	IF NEW.context='delete' THEN
		NEW.endet := to_char(CURRENT_TIMESTAMP AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"');

	ELSIF NEW.context='update' THEN
		IF NEW.endet IS NULL THEN
			RAISE EXCEPTION '%: Endedatum nicht gesetzt', NEW.featureid;
		END IF;

	ELSIF NEW.context='replace' THEN
		NEW.safetoignore := lower(NEW.safetoignore);
		replgml := substr(NEW.replacedby, 1, 16); -- ReplcedBy gml_id ohne Timestamp
		IF NEW.safetoignore IS NULL THEN
			RAISE EXCEPTION '%: safeToIgnore nicht gesetzt.', NEW.featureid;
		ELSIF NEW.safetoignore<>'true' AND NEW.safetoignore<>'false' THEN
			RAISE EXCEPTION '%: safeToIgnore ''%'' ungültig (''true'' oder ''false'' erwartet).', NEW.featureid, NEW.safetoignore;
		END IF;

		IF length(NEW.replacedby)=32 AND NEW.replacedby<>NEW.featureid THEN
			NEW.endet := substr(NEW.replacedby, 17, 4) || '-'
				|| substr(NEW.replacedby, 21, 2) || '-'
				|| substr(NEW.replacedby, 23, 2) || 'T'
				|| substr(NEW.replacedby, 26, 2) || ':'
				|| substr(NEW.replacedby, 28, 2) || ':'
				|| substr(NEW.replacedby, 30, 2) || 'Z' ;
		END IF;

		-- Satz-Paarung Vorgänger-Nachfolger in der Objekttabelle suchen.
		-- Der Vorgänger muss noch beendet werden. Der Nachfolger kann bereits beendet sein.
		-- Das "beginn" des Nachfolgers anschließend als "endet" des Vorgaengers verwenden.
		-- Normalfall bei NBA-Aktualisierungslaeufen. v=Vorgänger, n=Nachfolger.
		IF NEW.endet IS NULL THEN
			EXECUTE 'SELECT min(n.beginnt) FROM ' || NEW.typename || ' n'
				|| ' JOIN ' || NEW.typename || ' v ON v.ogc_fid<n.ogc_fid'
				|| ' WHERE v.gml_id=''' || featgml
				|| ''' AND n.gml_id=''' || replgml
				|| ''' AND v.endet IS NULL'
				INTO NEW.endet;
		--	RAISE NOTICE 'endet setzen fuer Vorgaenger % ', NEW.endet;
		END IF;

		-- Satz-Paarung Vorgänger-Nachfolger in der Objekttabelle suchen.
		-- Der Vorgänger ist bereits beendet worden weil "endet" in den Daten gefüllt war.
		-- Dieser Fall kommt bei der Erstabgabe mit Vollhistorie vor.
		IF NEW.endet IS NULL THEN
			EXECUTE 'SELECT min(n.beginnt) FROM ' || NEW.typename || ' n'
				|| ' JOIN ' || NEW.typename || ' v ON v.endet=n.beginnt '
				|| ' WHERE v.gml_id=''' || featgml
				|| ''' AND n.gml_id=''' || replgml
				|| ''' AND v.beginnt=''' || vbeginnt || ''''
				INTO NEW.endet;

			IF NOT NEW.endet IS NULL THEN
			--	RAISE NOTICE '%: Vorgaenger ist schon endet', NEW.featureid;
				NEW.ignored=false;
				RETURN NEW;
			END IF;
		END IF;

		IF NEW.endet IS NULL THEN -- "endet" für den Vorgänger konnte nicht ermittelt werden
			IF NEW.safetoignore='false' THEN
				RAISE EXCEPTION '%: Beginn des ersetzenden Objekts % nicht gefunden.', NEW.featureid, NEW.replacedby;
			END IF;
			NEW.ignored=true;
			RETURN NEW;
		END IF; 
	ELSE
		RAISE EXCEPTION '%: Ungültiger Kontext % (''delete'', ''replace'' oder ''update'' erwartet).', NEW.featureid, NEW.context;
	END IF;

	-- Vorgaenger ALKIS-Objekt nun beenden
	s := 'UPDATE ' || NEW.typename
	  || ' SET endet=''' || NEW.endet || ''' ,anlass=''' || NEW.anlass || ''''
	  || ' WHERE gml_id=''' || featgml || ''' AND beginnt=''' || vbeginnt || '''' ;
	EXECUTE s;
	GET DIAGNOSTICS n = ROW_COUNT;
	-- RAISE NOTICE 'SQL[%]:%', n, s;
	IF n<>1 THEN
		RAISE EXCEPTION '%: % schlug fehl [%]', NEW.featureid, NEW.context, n;
	END IF;

	NEW.ignored := false;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Version PostNAS 0.8 ohne "alkis_beziehungen"-Tabelle
-- Unterschied von "delete_feature_kill" zur Version "delete_feature_hist":
--  Historisch gewordene Objekte werden nicht auf "endet" gesetzt sondern sofort aus der Datenbank gelöscht.

-- Version von 2014-09-04 bis 2014-09-23
-- Ohne Tabelle "alkis_beziehungen".
-- Die gml_id kann in der Datenbenk das Format "character varying" haben (angehängte Beginn-Zeit).
-- Diese Version kennt den NAS-Kontext "update" nicht und kann daher nur die Abgabeart 1000 verarbeiten.
CREATE OR REPLACE FUNCTION delete_feature_kill_abg1000() RETURNS TRIGGER AS $$
DECLARE
	begsql TEXT;
	aktbeg TEXT;
	gml_id TEXT;
BEGIN
	-- Alte Version, die nur die Abgabeart 1000 (ohne replace) verarbeiten kann.
	NEW.typename := lower(NEW.typename); -- Objektart=Tabellen-Name
	NEW.context := lower(NEW.context);   -- Operation 'delete'/'replace'/'update'
	gml_id      := substr(NEW.featureid, 1, 16); -- ID-Teil der gml_id, ohne Timestamp

	IF NEW.context IS NULL THEN
		NEW.context := 'delete'; -- default
	END IF;
	IF NEW.context='delete' THEN -- Löschen des Objektes
		EXECUTE 'DELETE FROM ' || NEW.typename || ' WHERE gml_id like ''' || gml_id || '%''';
		--RAISE NOTICE 'Lösche gml_id % in %', gml_id, NEW.typename;
	ELSE -- Ersetzen des Objektes (Replace). In der Objekt-Tabelle sind jetzt bereits 2 Objekte vorhanden (alt und neu).

		-- beginnt-Wert des aktuellen Objektes ermitteln
		-- besser ?   WHERE substring(gml_id,1,16) = ''' || gml_id || '''
		begsql := 'SELECT max(beginnt) FROM ' || NEW.typename || ' WHERE gml_id like ''' || substr(NEW.replacedBy, 1, 16) || '%'' AND endet IS NULL';
		EXECUTE begsql INTO aktbeg;

		-- Alte Objekte entfernen
		EXECUTE 'DELETE FROM ' || NEW.typename || ' WHERE gml_id like ''' || gml_id || '%'' AND beginnt < ''' || aktbeg || '''';
	END IF;

	NEW.ignored := false;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Version ab 2014-09-23 (PostNAS 0.8)
-- Abwandlung der Hist-Version als Kill-Version.
-- Die "gml_id" muss in der Datenbank das Format character(16) haben.
-- Dies kann auch Abgabeart 3100 verarbeiten. Historische Objekte werden aber sofort entfernt.
CREATE OR REPLACE FUNCTION delete_feature_kill() RETURNS TRIGGER AS $$
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
		RAISE EXCEPTION '%: % schlug fehl [%]', NEW.featureid, NEW.context, n;
		-- dieser Satz kommt nicht in die delete-Tabelle?
	END IF;

	NEW.ignored := false;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Wenn die Datenbank MIT Historie angelegt wurde, kann nach dem Laden hiermit aufgeräumt werden.
CREATE OR REPLACE FUNCTION alkis_delete_all_endet() RETURNS void AS $$
DECLARE
	c RECORD;
BEGIN
	-- In allen Tabellen die Objekte löschen, die ein Ende-Datum haben
	FOR c IN
		SELECT table_name
		 FROM information_schema.columns a
		WHERE a.column_name='endet'
            AND a.is_updatable='YES' -- keine Views, die endet-Spalte haben
		ORDER BY table_name
	LOOP
		EXECUTE 'DELETE FROM ' || c.table_name || ' WHERE NOT endet IS NULL';
		-- RAISE NOTICE 'Lösche ''endet'' in: %', c.table_name;
	END LOOP;
END;
$$ LANGUAGE plpgsql;


-- Wenn die Datenbank ohne Historie geführt wird, ist das Feld "identifier" verzichtbar.
-- Diese wird nur von der Trigger-Version für die Version MIT Historie verwendet.
-- Es kann aus allen Tabellen entfernt werden.
CREATE OR REPLACE FUNCTION alkis_drop_all_identifier() RETURNS void AS $$
DECLARE
	c RECORD;
BEGIN
	FOR c IN
		SELECT table_name
		FROM information_schema.columns a
		WHERE a.column_name='identifier'
		ORDER BY table_name
	LOOP
		EXECUTE 'ALTER TABLE ' || c.table_name || ' DROP COLUMN identifier';
		RAISE NOTICE 'Entferne ''identifier'' aus: %', c.table_name;
	END LOOP;
END;
$$ LANGUAGE plpgsql;


-- Funktion zum Ermitteln der letzten import_id
CREATE OR REPLACE FUNCTION get_import_id() RETURNS TRIGGER AS $$
BEGIN
	EXECUTE 'SELECT max(id) FROM import' INTO NEW.import_id;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- 2014-09-22 Kopie aus Norbit-Github
-- Funktioniert nicht wenn Schlüsseltabellen mit "ax_" beginnen wie die Objekt-Tabellen.
-- Darin wird dann z.B. die Splate "endet" gesucht.
-- ToDo: besseres Namens-Schema für Tabellen.
--   z.B. Umbenennen "ax_buchungsstelle_buchungsart" -> "v_bs_buchungsart"
CREATE OR REPLACE FUNCTION alkis_hist_check() RETURNS varchar AS $$
DECLARE
	c RECORD;
	n INTEGER;
	r VARCHAR;
BEGIN
	FOR c IN SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND substr(table_name,1,3) IN ('ax_','ap_','ks_') AND table_type='BASE TABLE'
	LOOP
		EXECUTE 'SELECT count(*) FROM ' || c.table_name || ' WHERE endet IS NULL GROUP BY gml_id HAVING count(*)>1' INTO n;
		IF n>1 THEN
			r := coalesce(r||E'\n','') || c.table_name || ': ' || n || ' Objekte, die in mehreren Versionen nicht beendet sind.';
		END IF;

		EXECUTE 'SELECT count(*) FROM ' || c.table_name || ' WHERE beginnt>=endet' INTO n;
		IF n>1 THEN
			r := coalesce(r||E'\n','') || c.table_name || ': ' || n || ' Objekte mit ungültiger Lebensdauer.';
		END IF;

		EXECUTE 'SELECT count(*)'
			|| ' FROM ' || c.table_name || ' a'
			|| ' JOIN ' || c.table_name || ' b ON a.gml_id=b.gml_id AND a.ogc_fid<>b.ogc_fid AND a.beginnt<b.endet AND a.endet>b.beginnt'
			INTO n;
		IF n>0 THEN
			r := coalesce(r||E'\n','') || c.table_name || ': ' || n || ' Lebensdauerüberschneidungen.';
		END IF;
	END LOOP;

	RETURN r;
END;
$$ LANGUAGE plpgsql;

-- Aufruf: SELECT alkis_hist_check();

