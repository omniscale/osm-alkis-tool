--
-- *****************************
--       A  L   K   I   S
-- *****************************
--
-- Datenbankstruktur PostNAS 0.8
--

-- Damit die Includes (\i) funktionieren muß psql im Verzeichnis ausgeführt
-- werden in dem das Skript liegt, z.B. per
-- (cd /pfad/zu/postnas; psql -f alkis_PostNAS_schema.sql)

-- Variable für das Koordinatensystem übergeben mit "psql .. -v alkis_epsg="25832"


-- Stand
-- -----

-- 2013-07-10 FJ  Erweiterung alkis_beziehungen nach Vorschlag Marvin Brandt (Kreis Unna)
--                Füllen der Felder langfristig durch PostNAS (Erweiterung?)
--                Vorläufig mit Trigger-Funktions "update_fields_beziehungen"

-- 2014-01-24 FJ  Feld "ax_datenerhebung_punktort" in "Punktort/TA/AG/AU" nach Vorschlag Marvin Brandt (Kreis Unna)

-- 2014-01-29 FJ  Spalte "zeitpunktderentstehung" an allen Vorkommen auf Format "character varying".
--                Alte auskommentierte Varianten entrümpelt.
--                Tabs durch Space ersetzt und Code wieder hübsch ausgerichtet.

-- 2014-01-31 FJ  Erweiterungen Marvin Brand (Unna) fuer sauberes Entfernen alter Beziehungen bei "replace".
--                Lösung über import_id.

-- 2014-07-31 AE  kommentar auf geometry_columns entfernt - ist in PostGIS 2 keine Tabelle mehr

-- 2014-08-27 FJ  Relationen-Verbindungs-Spalten direkt in den Objekt-Tabellen statt über Tabelle "alkis_relationen".
--                Übergangsweise wird beides geführt bis alle Programme und Views umgestellt wurden.
--                Spalten "advstandardmodell" und "sonstigesmodell" sind immer ein Array ( character varying[] ).
--                Beginn der Angleichung an die jetzt freie norBIT-Version:
--                Kommentar zur Tabelle systematischer aufbauen.
--                Zielformat: '[Objektbereich /] [Objektartengruppe]: ([N]REO|ZUSO) "Name" ist ...'

-- 2014-09-04 FJ * Getestet mit ogr2ogr compiliert aus GDAL Revision 27631 (2.0.0dev)
--               * Entfernen der Tabelle "alkis_beziehungen".
--               * Anpassungen und Korrekturen zum Angleich an die Norbit-Version.
--                 u.a.: land, stelle, strassenschluessel: varchar statt integer.
--                 Dann konsequenterweise aber auch: regierungsbezirk, kreis, gemeinde, schluesselgesamt, bezirk.
--                 Diese Felder werden von PostNAS als Integer generiert, wenn kein Schema vorgegeben wird.
--                 Die Inhalte sind zwar numerisch, laut Objektartenkatalog sind das aber CharacterString.
--               * Sortierung der Tabellen in dieser Datei nach Objektartengruppen + Kennung analog der Gliederung des Objektartenkatalogs.
--                 Dies war in Vers. 0.7 begonnen aber noch nicht fertig gestellt worden.
--               * Übernahme der Objektartengruppe in den Kommentar zur Tabelle.

-- 2014-09-12 FJ Indizierung der ersten 16 Zeichen der gml_id, wenn diese Ziel einer ALKIS-Beziehung ist.
--               "delete"-Tabelle aus Norbit-Version passend zum Hist-Trigger.

-- 2014-09-17 FJ Die aus der Norbit-Version übernommene Änderung des Formates von "gml_id" auf "character variyng".
--               wieder rückgängig machen. Dies ist auch dort inzwischen revertiert worden und die aktuelle
--               Trigger-Function "delete_feature_hist()" arbeitet fehlerhaft, wenn die gml_id länger als 16 Zeichen sind.
--               Aktuell: "gml_id character(16) NOT NULL"

-- 2014-09-23 FJ Zählfelder für Kontext-Funktionen in der import-Tabelle

-- 2014-10-14 FJ "ax_wirtschaftlicheeinheit.anlass" von integer zu character. Sonst Trigger-Fehler bei "delete".

-- 2015-02-18 FJ "ax_gelaendekante.wkb_geometry" von 'LINESTRING' nach 'GEOMETRY'

-- 2015-05-26 FJ Spalte "gdalvers" in Tabelle "import"

--  Dies Schema kann NICHT mehr mit der gdal-Version 1.9 verwendet werden.

-- ALKIS-Dokumentation (NRW):
--  http://www.bezreg-koeln.nrw.de/extra/33alkis/alkis_nrw.htm
--  http://www.bezreg-koeln.nrw.de/extra/33alkis/geoinfodok.htm
--  http://www.bezreg-koeln.nrw.de/extra/33alkis/dokumente/GeoInfoDok/ALKIS/ALKIS_OK_V6-0.html

  SET client_encoding = 'UTF8';
  SET default_with_oids = false;

-- Abbruch bei Fehlern
\set ON_ERROR_STOP

-- T u n i n g :
--   Vorschlag: Die Tabelle 'spatial_ref_sys' einer PostGIS-Datenbank auf
--   die notwendigen Koordinatensysteme reduzieren. Das löscht >3000 Eintraege.
/*
   DELETE FROM spatial_ref_sys
   WHERE srid NOT
   IN (2397, 2398, 2399, 4326,    25830, 25831, 25832, 25833, 25834,  31466, 31467, 31468, 31469);
   --  Krassowski        lat/lon  UTM                                 GK
*/

-- Stored Procedures laden
\i alkis-functions.sql
\i alkis-functions-ext.sql

-- ===========================================================
-- PostNAS-Hilfstabellen
-- ===========================================================
-- Diese sind kein Bestandteil des ALKIS-Objektartenkataloges.


-- Importtabelle für Verarbeitungs-Zähler.
-- Wurde ursprünglich eingeführt für den Trigger zur Pflege der "alkis_beziehungen".
-- Ist seit Version PostNAS 0.8 nur noch eine Metadaten-Tabelle zum Aktualisierungs-Verlauf einer Datenbank.
-- Für die Funktion von Konverter oder Auskunft-Programmen ist diese Tabelle nicht notwendig.
-- Das Script "konv_batch.sh" aktualisiert diese Tabelle.
-- Wenn dies Script verwendet wird, ist die import-Tabelle nützlich um nachzuschauen,
-- wann welcher Ordner mit Daten in diese Datenbank konvertiert wurde.
CREATE TABLE import (
  id serial NOT NULL,
  datum timestamp without time zone,
  verzeichnis text,
  importart text,
  gdalvers text,
  anz_delete integer,
  anz_update integer,
  anz_replace integer,
  CONSTRAINT import_pk PRIMARY KEY (id)
);

-- Spalte nachtragen:
-- ALTER TABLE import ADD COLUMN gdalvers text;

CREATE UNIQUE INDEX import_id ON import USING btree (id);

COMMENT ON TABLE  import             IS 'PostNAS: Verwaltung der Import-Programmläufe. Wird nicht vom Konverter gefüllt sondern aus der Start-Prozedur (z.B. konv_batch.sh).';
COMMENT ON COLUMN import.id          IS 'Laufende Nummer der Konverter-Datei-Verarbeitung.';
COMMENT ON COLUMN import.datum       IS 'Zeitpunkt des Beginns des Konverter-Laufes für einen Stapel von NAS-Dateien.';
COMMENT ON COLUMN import.verzeichnis IS 'Ort von dem die NAS-Dateien verarbeitet wurden.';
COMMENT ON COLUMN import.importart   IS 'Modus des Konverter-Laufes: e="Erstladen" oder a="NBA-Aktualisierung"';
COMMENT ON COLUMN import.gdalvers    IS 'GDAL-Programmversion mit der der Import erfolgte.';

COMMENT ON COLUMN import.anz_delete  IS 'Anzahl von delete-Funktionen in der delete-Tabelle nach Ende eines Konvertierungs-Laufes';
COMMENT ON COLUMN import.anz_update  IS 'Anzahl von update-Funktionen in der delete-Tabelle nach Ende eines Konvertierungs-Laufes';
COMMENT ON COLUMN import.anz_replace IS 'Anzahl von replace-Funktionen in der delete-Tabelle nach Ende eines Konvertierungs-Laufes';


-- Tabelle "delete" für Lösch- und Fortführungsdatensätze.
-- Über diese Tabelle werden Aktualisierungen des Bestandes gesteuert.
-- Der Konverter ogr2ogr (PostNAS) trägt die NAS-Operatuonen "delete", "replace" und "update" hier ein.
-- Die weitere ALKIS-spezifische Ausführung dieser Operationen muss durch Trigger auf dieser Tabelle erfolgen.
-- Das betrifft z.B. das Löschen von Objekten, die über die NAS-Update-Funktion einen "endet"-Eintrag bekommen haben.
-- 2014-09-12: "anlass" und "endet" hinzugefügt. Aktueller Trigger (hist) für NAS-"update" benötigt diese Spalten.
CREATE TABLE "delete" (
  ogc_fid serial NOT NULL,
  typename character varying,
  featureid character varying,
  context character varying, -- delete/replace/update
  safetoignore character varying, -- replace.safetoignore 'true'/'false'
  replacedBy character varying, -- gmlid
  anlass character varying,       -- update.anlass
  endet character(20),            -- update.endet
  ignored boolean DEFAULT false, -- Satz wurde nicht verarbeitet
  CONSTRAINT delete_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('delete','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX delete_fid ON "delete"(featureid);

COMMENT ON TABLE "delete"             IS 'PostNAS: Hilfstabelle für das Speichern von Löschinformationen.';
COMMENT ON COLUMN delete.typename     IS 'Objektart, also Name der Tabelle, aus der das Objekt zu löschen ist.';
COMMENT ON COLUMN delete.featureid    IS 'Zusammen gesetzt aus GML-ID (16) und Zeitstempel.';
COMMENT ON COLUMN delete.context      IS 'Operation ''delete'', ''replace'' oder ''update''';
COMMENT ON COLUMN delete.safetoignore IS 'Attribut safeToIgnore von wfsext:Replace';
COMMENT ON COLUMN delete.replacedBy   IS 'gml_id des Objekts, das featureid ersetzt';
COMMENT ON COLUMN delete.anlass       IS 'update.anlass';
COMMENT ON COLUMN delete.endet        IS 'update.endet';
COMMENT ON COLUMN delete.ignored      IS 'Löschsatz wurde ignoriert';


-- B e z i e h u n g e n
-- ----------------------------------------------
-- Zentrale Tabelle fuer alle Relationen im Buchwerk.
-- Seit PostNAS 0.8 entfallen. Wird aber von PostNAS wieder angelegt, wenn sie fehlt.
-- Die Fremdschlüssel 'beziehung_von' und 'beziehung_zu' verweisen auf die ID des Objekte (gml_id).
-- Zusätzlich enthält 'beziehungsart' noch ein Verb für die Art der Beziehung.
/*
CREATE TABLE alkis_beziehungen (
  ogc_fid serial NOT NULL,
  beziehung_von character varying,
  beziehungsart character varying,
  beziehung_zu character varying,
  import_id integer,
  CONSTRAINT alkis_beziehungen_pk PRIMARY KEY (ogc_fid)
);

CREATE INDEX alkis_beziehungen_von_idx ON alkis_beziehungen USING btree (beziehung_von);
CREATE INDEX alkis_beziehungen_zu_idx  ON alkis_beziehungen USING btree (beziehung_zu);
CREATE INDEX alkis_beziehungen_art_idx ON alkis_beziehungen USING btree (beziehungsart);

SELECT AddGeometryColumn('alkis_beziehungen','dummy',:alkis_epsg,'POINT',2);

COMMENT ON TABLE  alkis_beziehungen               IS 'PostNAS: zentrale Multi-Verbindungstabelle';
COMMENT ON COLUMN alkis_beziehungen.beziehung_von IS 'Join auf Feld gml_id verschiedener Tabellen';
COMMENT ON COLUMN alkis_beziehungen.beziehung_zu  IS 'Join auf Feld gml_id verschiedener Tabellen';
COMMENT ON COLUMN alkis_beziehungen.beziehungsart IS 'Typ der Beziehung zwischen der von- und zu-Tabelle';
COMMENT ON COLUMN alkis_beziehungen.import_id     IS 'laufende Nummer des Konverter-Laufes aus "import.id".';
*/


-- S o n s t i g e s   B a u w e r k
-- ----------------------------------
-- Wird von PostNAS generiert, ist aber keiner Objektartengruppe zuzuordnen.
CREATE TABLE ks_sonstigesbauwerk (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  sonstigesmodell character varying[],
  anlass character varying,
  bauwerksfunktion integer,
  CONSTRAINT ks_sonstigesbauwerk_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ks_sonstigesbauwerk','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ks_sonstigesbauwerk_geom_idx ON ks_sonstigesbauwerk USING gist (wkb_geometry);

COMMENT ON TABLE  ks_sonstigesbauwerk IS '??: (REO) "Sonstiges Bauwerk"';


-- Löschtrigger setzen
-- -------------------

-- Option (A) ohne Historie:
--  - Symlink von alkis-trigger-kill.sql auf alkis-trigger.sql setzen
--    (Default; macht datenbank_anlegen.sh ggf. automatisch)
--  - Lösch- und Änderungssätze werden ausgeführt und die alten Objekte werden sofort entfernt

-- Option (B) mit Historie:
--  - Symlink von alkis-trigger-hist.sql auf alkis-trigger.sql setzen
--  - Bei Lösch- und Änderungssätzen werden die Objekte nicht gelöscht, sondern im Feld 'endet'
--    als ungegangen markiert (Für aktuelle Objekte gilt: WHERE endet IS NULL)

\i alkis-trigger.sql


--*** ############################################################
--*** Objektbereich: AAA Basisschema
--*** ############################################################

--** Objektartengruppe: AAA_Praesentationsobjekte
--   ===================================================================

-- A P   P P O
-- ----------------------------------------------
-- Objektart: AP_PPO Kennung: 02310
CREATE TABLE ap_ppo (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,

  signaturnummer character varying, -- ap_gpo
  darstellungsprioritaet integer, -- ap_gpo
  art character varying,            -- ap_gpo

  drehwinkel double precision,
  skalierung double precision,

  -- Beziehungen:
  dientzurdarstellungvon character varying[], -- -> aa_objekt
  CONSTRAINT ap_ppo_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ap_ppo','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POINT/MULTIPOLYGON

CREATE        INDEX ap_ppo_geom_idx   ON ap_ppo USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ap_ppo_gml        ON ap_ppo USING btree (gml_id, beginnt);
CREATE        INDEX ap_ppo_endet      ON ap_ppo USING btree (endet);
CREATE        INDEX ap_ppo_dzdv       ON ap_ppo USING gin   (dientzurdarstellungvon);

COMMENT ON TABLE  ap_ppo        IS 'AAA-Präsentationsobjekte: (REO) "PPO" Punktförmiges Präsentationsobjekt';
COMMENT ON COLUMN ap_ppo.gml_id IS 'Identifikator, global eindeutig';

-- ap_gpo:
COMMENT ON COLUMN ap_ppo.signaturnummer IS 'SNR Signaturnummer gemäß Signaturenkatalog. Die Signaturnummer wird nur dann angegeben, wenn für einen Sachverhalt mehrere Signaturnummern zulässig sind.';
COMMENT ON COLUMN ap_ppo.darstellungsprioritaet IS 'DPR Darstellungspriorität für Elemente der Signatur. Eine gegenüber den Festlegungen des Signaturenkatalogs abweichende Priorität wird über dieses Attribut definiert und nicht über eine neue Signatur.';
COMMENT ON COLUMN ap_ppo.art            IS 'ART "Art" gibt die Kennung des Attributs an, das mit dem Präsentationsobjekt dargestellt werden soll.';

COMMENT ON COLUMN ap_ppo.drehwinkel     IS 'DWI Drehwinkel';
COMMENT ON COLUMN ap_ppo.skalierung     IS 'SKA Skalierungsfaktor für Symbole.';

COMMENT ON COLUMN ap_ppo.dientzurdarstellungvon IS '-> Beziehung zu aa_objekt (0..*): Durch den Verweis auf einen Set beliebiger AFIS-ALKIS-ATKIS-Objekte gibt das Präsentationsobjekt an, zu wessen Präsentation es dient. Dieser Verweis kann für Fortführungen ausgenutzt werden oder zur Unterdrückung von Standardpräsentationen der zugrundeliegenden ALKIS-ATKIS-Objekte.
Ein Verweis auf ein AA_Objekt vom Typ AP_GPO ist nicht zugelassen.';


-- A P   L P O
-- ----------------------------------------------
-- Objektart: AP_LPO Kennung: 02320
CREATE TABLE ap_lpo (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,

  signaturnummer character varying, -- ap_gpo
  darstellungsprioritaet integer, -- ap_gpo
  art character varying, -- ap_gpo

  -- Beziehungen:
  dientzurdarstellungvon character varying[], -- -> aa_objekt
  CONSTRAINT ap_lpo_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ap_lpo','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/MULTILINESTRING

CREATE INDEX ap_lpo_geom_idx   ON ap_lpo USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ap_lpo_gml ON ap_lpo USING btree (gml_id, beginnt);
CREATE INDEX ap_lpo_gml16      ON ap_lpo USING btree (substring(gml_id,1,16)); -- ALKIS-Relation
CREATE INDEX ap_lpo_endet      ON ap_lpo USING btree (endet);
CREATE INDEX ap_lpo_dzdv       ON ap_lpo USING gin   (dientzurdarstellungvon);

COMMENT ON TABLE  ap_lpo        IS 'AAA-Präsentationsobjekte: (REO) "LPO" Linienförmiges Präsentationsobjekt';
COMMENT ON COLUMN ap_lpo.gml_id IS 'Identifikator, global eindeutig';

-- ap_gpo:
COMMENT ON COLUMN ap_lpo.signaturnummer IS 'SNR Signaturnummer gemäß Signaturenkatalog. Die Signaturnummer wird nur dann angegeben, wenn für einen Sachverhalt mehrere Signaturnummern zulässig sind.';
COMMENT ON COLUMN ap_lpo.darstellungsprioritaet IS 'DPR Darstellungspriorität für Elemente der Signatur. Eine gegenüber den Festlegungen des Signaturenkatalogs abweichende Priorität wird über dieses Attribut definiert und nicht über eine neue Signatur.';
COMMENT ON COLUMN ap_lpo.art            IS 'ART "Art" gibt die Kennung des Attributs an, das mit dem Präsentationsobjekt dargestellt werden soll.';

COMMENT ON COLUMN ap_lpo.dientzurdarstellungvon IS '-> Beziehung zu aa_objekt (0..*): Durch den Verweis auf einen Set beliebiger AFIS-ALKIS-ATKIS-Objekte gibt das Präsentationsobjekt an, zu wessen Präsentation es dient. Dieser Verweis kann für Fortführungen ausgenutzt werden oder zur Unterdrückung von Standardpräsentationen der zugrundeliegenden ALKIS-ATKIS-Objekte.
Ein Verweis auf ein AA_Objekt vom Typ AP_GPO ist nicht zugelassen.';


-- A P   P T O
-- ----------------------------------------------
-- Objektart: AP_PTO Kennung: 02341
CREATE TABLE ap_pto (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,

  schriftinhalt character varying, -- Label: anzuzeigender Text
  fontsperrung double precision,
  skalierung double precision,
  horizontaleausrichtung character varying,
  vertikaleausrichtung character varying,

  signaturnummer character varying, -- ap_gpo
  darstellungsprioritaet integer, -- ap_gpo
  art character varying,            -- ap_gpo

  drehwinkel double precision, -- falsche Masseinheit für Mapserver, im View umrechnen
  -- Beziehungen:
  dientzurdarstellungvon character varying[], -- -> aa_objekt
  hat character varying, -- -> ap_lpo
  CONSTRAINT ap_pto_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ap_pto','wkb_geometry',:alkis_epsg,'POINT',2);

CREATE INDEX ap_pto_geom_idx   ON ap_pto USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ap_pto_gml ON ap_pto USING btree (gml_id, beginnt);
CREATE INDEX ap_pto_art_idx    ON ap_pto USING btree (art);
CREATE INDEX ap_pto_endet_idx  ON ap_pto USING btree (endet);
CREATE INDEX ap_pto_sn_idx     ON ap_pto USING btree (signaturnummer);
CREATE INDEX ap_pto_dzdv       ON ap_pto USING gin   (dientzurdarstellungvon);
CREATE INDEX ap_pto_hat        ON ap_pto USING btree (hat);

COMMENT ON TABLE  ap_pto               IS 'AAA-Präsentationsobjekte: (REO) "PTO" Textförmiges Präsentationsobjekt mit punktförmiger Textgeometrie ';
COMMENT ON COLUMN ap_pto.gml_id        IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ap_pto.schriftinhalt IS 'SIT Label: anzuzeigender Text';

COMMENT ON COLUMN ap_pto.fontsperrung  IS 'FSP Die Zeichensperrung steuert den zusätzlichen Raum, der zwischen 2 aufeinanderfolgende Zeichenkörper geschoben wird.';
COMMENT ON COLUMN ap_pto.skalierung    IS 'SKA Skalierungsfaktor für die Schriftgröße.';
COMMENT ON COLUMN ap_pto.horizontaleausrichtung IS 'FHA Gibt die Ausrichtung des Textes bezüglich der Textgeometrie an. Wertearten: linksbündig, rechtsbündig, zentrisch';
COMMENT ON COLUMN ap_pto.vertikaleausrichtung   IS 'FVA Die vertikale Ausrichtung eines Textes gibt an, ob die Bezugsgeometrie die Basis (Grundlinie) des Textes, die Mitte oder obere Buchstabenbegrenzung betrifft. Wertearten: Basis, Mitte, oben';

-- ap_gpo:
COMMENT ON COLUMN ap_pto.signaturnummer IS 'SNR Signaturnummer gemäß Signaturenkatalog. Die Signaturnummer wird nur dann angegeben, wenn für einen Sachverhalt mehrere Signaturnummern zulässig sind.';
COMMENT ON COLUMN ap_pto.darstellungsprioritaet IS 'DPR Darstellungspriorität für Elemente der Signatur. Eine gegenüber den Festlegungen des Signaturenkatalogs abweichende Priorität wird über dieses Attribut definiert und nicht über eine neue Signatur.';
COMMENT ON COLUMN ap_pto.art            IS 'ART "Art" gibt die Kennung des Attributs an, das mit dem Präsentationsobjekt dargestellt werden soll.';

COMMENT ON COLUMN ap_pto.dientzurdarstellungvon IS '-> Beziehung zu aa_objekt (0..*): Durch den Verweis auf einen Set beliebiger AFIS-ALKIS-ATKIS-Objekte gibt das Präsentationsobjekt an, zu wessen Präsentation es dient. Dieser Verweis kann für Fortführungen ausgenutzt werden oder zur Unterdrückung von Standardpräsentationen der zugrundeliegenden ALKIS-ATKIS-Objekte.
Ein Verweis auf ein AA_Objekt vom Typ AP_GPO ist nicht zugelassen.';
COMMENT ON COLUMN ap_pto.hat           IS '-> Beziehung zu ap_lpo (0..1): Die Relation ermöglicht es, einem textförmigen Präsentationsobjekt ein linienförmiges Präsentationsobjekt zuzuweisen. Einziger bekannter Anwendungsfall ist der Zuordnungspfeil.
Die Anwendung dieser Relation ist nur zugelassen, wenn sie im entsprechenden Signaturenkatalog beschrieben ist.';

COMMENT ON INDEX ap_pto_art_idx        IS 'Suchindex auf häufig benutztem Filterkriterium';


-- A P   L T O
-- ----------------------------------------------
-- Objektart: AP_LTO Kennung: 02342
CREATE TABLE ap_lto (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schriftinhalt character varying,
  fontsperrung double precision,
  skalierung double precision,
  horizontaleausrichtung character varying,
  vertikaleausrichtung character varying,

  signaturnummer character varying, -- ap_gpo
  darstellungsprioritaet integer, -- ap_gpo
  art character varying, -- ap_gpo

  -- Beziehungen:
  dientzurdarstellungvon character varying[], -- -> aa_objekt
  hat character varying, -- -> ap_lpo
  CONSTRAINT ap_lto_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ap_lto','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/MULTILINESTRING

CREATE INDEX ap_lto_geom_idx   ON ap_lto USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ap_lto_gml ON ap_lto USING btree (gml_id, beginnt);
CREATE INDEX ap_lto_dzdv       ON ap_lto USING gin   (dientzurdarstellungvon);
CREATE INDEX ap_lto_endet_idx  ON ap_lto USING btree (endet);
CREATE INDEX ap_lto_hat        ON ap_lto USING btree (hat);

COMMENT ON TABLE  ap_lto        IS 'AAA-Präsentationsobjekte: (REO) "LTO" Textförmiges Präsentationsobjekt mit linienförmiger Textgeometrie';
COMMENT ON COLUMN ap_lto.gml_id IS 'Identifikator, global eindeutig';

-- ap_gpo:
COMMENT ON COLUMN ap_lto.signaturnummer IS 'SNR Signaturnummer gemäß Signaturenkatalog. Die Signaturnummer wird nur dann angegeben, wenn für einen Sachverhalt mehrere Signaturnummern zulässig sind.';
COMMENT ON COLUMN ap_lto.darstellungsprioritaet IS 'DPR Darstellungspriorität für Elemente der Signatur. Eine gegenüber den Festlegungen des Signaturenkatalogs abweichende Priorität wird über dieses Attribut definiert und nicht über eine neue Signatur.';
COMMENT ON COLUMN ap_lto.art            IS 'ART "Art" gibt die Kennung des Attributs an, das mit dem Präsentationsobjekt dargestellt werden soll.';

COMMENT ON COLUMN ap_lto.dientzurdarstellungvon IS '-> Beziehung zu aa_objekt (0..*): Durch den Verweis auf einen Set beliebiger AFIS-ALKIS-ATKIS-Objekte gibt das Präsentationsobjekt an, zu wessen Präsentation es dient. Dieser Verweis kann für Fortführungen ausgenutzt werden oder zur Unterdrückung von Standardpräsentationen der zugrundeliegenden ALKIS-ATKIS-Objekte.
Ein Verweis auf ein AA_Objekt vom Typ AP_GPO ist nicht zugelassen.';
COMMENT ON COLUMN ap_lto.hat    IS '-> Beziehung zu ap_lpo (0..1): Die Relation ermöglicht es, einem textförmigen Präsentationsobjekt ein linienförmiges Präsentationsobjekt zuzuweisen. Einziger bekannter Anwendungsfall ist der Zuordnungspfeil.
Die Anwendung dieser Relation ist nur zugelassen, wenn sie im entsprechenden Signaturenkatalog beschrieben ist. ';


-- A P  D a r s t e l l u n g
-- ----------------------------------------------
-- Objektart: AP_Darstellung Kennung: 02350
CREATE TABLE ap_darstellung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,

  signaturnummer character varying, -- ap_gpo
  darstellungsprioritaet integer, -- ap_gpo
  art character varying, -- ap_gpo

  positionierungsregel integer,
  -- Beziehungen:
  dientzurdarstellungvon character varying[], -- -> aa_objekt
  CONSTRAINT ap_darstellung_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ap_darstellung','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ap_darstellung_gml ON ap_darstellung USING btree (gml_id, beginnt);
CREATE INDEX ap_darstellung_endet_idx  ON ap_darstellung USING btree (endet);
CREATE INDEX ap_darstellung_dzdv       ON ap_darstellung  USING gin  (dientzurdarstellungvon);

COMMENT ON TABLE  ap_darstellung        IS 'AAA-Präsentationsobjekte: (NREO) "AP-Darstellung"';
COMMENT ON COLUMN ap_darstellung.gml_id IS 'Identifikator, global eindeutig';

-- ap_gpo:
COMMENT ON COLUMN ap_darstellung.signaturnummer IS 'SNR Signaturnummer gemäß Signaturenkatalog. Die Signaturnummer wird nur dann angegeben, wenn für einen Sachverhalt mehrere Signaturnummern zulässig sind.';
COMMENT ON COLUMN ap_darstellung.darstellungsprioritaet IS 'DPR Darstellungspriorität für Elemente der Signatur. Eine gegenüber den Festlegungen des Signaturenkatalogs abweichende Priorität wird über dieses Attribut definiert und nicht über eine neue Signatur.';
COMMENT ON COLUMN ap_darstellung.art            IS 'ART "Art" gibt die Kennung des Attributs an, das mit dem Präsentationsobjekt dargestellt werden soll.';

COMMENT ON COLUMN ap_darstellung.positionierungsregel IS 'PNR In diesem Attribut wird durch Verweis auf eine Regel im Signaturenkatalog beschrieben, wie Signaturen zu positionieren sind. Eine Positionierungsregel definiert z.B. welchen Abstand Bäumchen in einem Wald haben und ob die Verteilung regelmäßig oder zufällig ist.';

COMMENT ON COLUMN ap_darstellung.dientzurdarstellungvon IS '-> Beziehung zu aa_objekt (0..*): Durch den Verweis auf einen Set beliebiger AFIS-ALKIS-ATKIS-Objekte gibt das Präsentationsobjekt an, zu wessen Präsentation es dient. Dieser Verweis kann für Fortführungen ausgenutzt werden oder zur Unterdrückung von Standardpräsentationen der zugrundeliegenden ALKIS-ATKIS-Objekte.
Ein Verweis auf ein AA_Objekt vom Typ AP_GPO ist nicht zugelassen.';


--*** ############################################################
--*** Objektbereich: Flurstücke, Lage, Punkte
--*** ############################################################

--** Objektartengruppe: Angaben zu Festpunkten der Landesvermessung

--** Objektartengruppe: Angaben zum Flurstück
--   ===================================================================

-- F l u r s t u e c k
-- ----------------------------------------------
-- Objektart: AX_Flurstueck Kennung: 11001
CREATE TABLE ax_flurstueck (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),

  -- GID: AX_Flurstueck_Kerndaten
  -- 'Flurstück_Kerndaten' enthält Eigenschaften des Flurstücks, die auch für andere Flurstücksobjektarten gelten (z.B. Historisches Flurstück).
  land character varying, --
  gemarkungsnummer character varying, --
  flurnummer integer,                   -- Teile des Flurstückskennzeichens
  zaehler integer,                      --    (redundant zu flurstueckskennzeichen)
  nenner integer,                     --
  flurstuecksfolge character varying,
  -- daraus abgeleitet:
  flurstueckskennzeichen character(20), -- Inhalt rechts mit __ auf 20 aufgefüllt
  amtlicheflaeche double precision, -- AFL
  abweichenderrechtszustand character varying DEFAULT 'false', -- ARZ
  rechtsbehelfsverfahren character varying DEFAULT 'false', -- RBV
  zweifelhafterFlurstuecksnachweis character varying DEFAULT 'false', -- ZFM Boolean
  zeitpunktderentstehung character varying,-- ZDE  Inhalt jjjj-mm-tt  besser Format date ?
  gemeinde character varying,
  -- GID: ENDE AX_Flurstueck_Kerndaten

  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  name character varying[],
  regierungsbezirk character varying,
  kreis character varying,
  stelle character varying[],
  angabenzumabschnittflurstueck character varying[],
  kennungschluessel character varying[],
  flaechedesabschnitts double precision[],
  angabenzumabschnittnummeraktenzeichen integer[],
  angabenzumabschnittbemerkung character varying[],
  -- Beziehungen:
--beziehtsichaufflurstueck character varying[], -- <- ax_flurstueck (invers)
  zeigtauf character varying[], -- -> ax_lagebezeichnungohnehausnummer
  istgebucht character varying, -- -> ax_buchungsstelle
  weistauf character varying[], -- -> ax_lagebezeichnungmithausnummer
  gehoertanteiligzu character varying[], -- -> ax_flurstueck
  CONSTRAINT ax_flurstueck_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_flurstueck','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_flurstueck_geom_idx   ON ax_flurstueck USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_flurstueck_gml ON ax_flurstueck USING btree (gml_id, beginnt);
CREATE INDEX ax_flurstueck_gml16      ON ax_flurstueck USING btree (substring(gml_id,1,16)); -- ALKIS-Relation
CREATE INDEX ax_flurstueck_lgfzn      ON ax_flurstueck USING btree (land, gemarkungsnummer, flurnummer, zaehler, nenner);
CREATE INDEX ax_flurstueck_arz        ON ax_flurstueck USING btree (abweichenderrechtszustand);

--EATE INDEX ax_flurstueck_bsaf       ON ax_flurstueck USING gin   (beziehtsichaufflurstueck);
CREATE INDEX ax_flurstueck_gaz        ON ax_flurstueck USING gin   (gehoertanteiligzu);
CREATE INDEX ax_flurstueck_ig         ON ax_flurstueck USING btree (istgebucht);
CREATE INDEX ax_flurstueck_kennz      ON ax_flurstueck USING btree (flurstueckskennzeichen);
CREATE INDEX ax_flurstueck_wa         ON ax_flurstueck USING gin   (weistauf);
CREATE INDEX ax_flurstueck_za         ON ax_flurstueck USING gin   (zeigtauf);

COMMENT ON TABLE  ax_flurstueck               IS 'Angaben zum Flurstück: (REO) "Flurstück" ist ein Teil der Erdoberfläche, der von einer im Liegenschaftskataster festgelegten Grenzlinie umschlossen und mit einer Nummer bezeichnet ist. Es ist die Buchungseinheit des Liegenschaftskatasters.';
COMMENT ON COLUMN ax_flurstueck.gml_id        IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_flurstueck.flurnummer    IS 'FLN "Flurnummer" ist die von der Katasterbehörde zur eindeutigen Bezeichnung vergebene Nummer einer Flur, die eine Gruppe von zusammenhängenden Flurstücken innerhalb einer Gemarkung umfasst.';
COMMENT ON COLUMN ax_flurstueck.zaehler       IS 'ZAE  Dieses Attribut enthält den Zähler der Flurstücknummer';
COMMENT ON COLUMN ax_flurstueck.nenner        IS 'NEN  Dieses Attribut enthält den Nenner der Flurstücknummer';
COMMENT ON COLUMN ax_flurstueck.flurstueckskennzeichen IS '"Flurstückskennzeichen" ist ein von der Katasterbehörde zur eindeutigen Bezeichnung des Flurstücks vergebenes Ordnungsmerkmal.
Die Attributart setzt sich aus den nachfolgenden expliziten Attributarten in der angegebenen Reihenfolge zusammen:
 1.  Land (2 Stellen)
 2.  Gemarkungsnummer (4 Stellen)
 3.  Flurnummer (3 Stellen)
 4.  Flurstücksnummer
 4.1 Zähler (5 Stellen)
 4.2 Nenner (4 Stellen)
 5.  Flurstücksfolge (2 Stellen)
Die Elemente sind rechtsbündig zu belegen, fehlende Stellen sind mit führenden Nullen zu belegen.
Da die Flurnummer und die Flurstücksfolge optional sind, sind aufgrund der bundeseinheitlichen Definition im Flurstückskennzeichen die entsprechenden Stellen, sofern sie nicht belegt sind, durch Unterstrich "_" ersetzt.
Gleiches gilt für Flurstücksnummern ohne Nenner, hier ist der fehlende Nenner im Flurstückskennzeichen durch Unterstriche zu ersetzen.';
COMMENT ON COLUMN ax_flurstueck.amtlicheflaeche           IS 'AFL "Amtliche Fläche" ist der im Liegenschaftskataster festgelegte Flächeninhalt des Flurstücks in [qm]. Flurstücksflächen kleiner 0,5 qm können mit bis zu zwei Nachkommastellen geführt werden, ansonsten ohne Nachkommastellen.';
COMMENT ON COLUMN ax_flurstueck.abweichenderrechtszustand IS 'ARZ "Abweichender Rechtszustand" ist ein Hinweis darauf, dass außerhalb des Grundbuches in einem durch Gesetz geregelten Verfahren der Bodenordnung (siehe Objektart "Bau-, Raum- oder Bodenordnungsrecht", AA "Art der Festlegung", Werte 1750, 1770, 2100 bis 2340) ein neuer Rechtszustand eingetreten ist und das amtliche Verzeichnis der jeweiligen ausführenden Stelle maßgebend ist.';
COMMENT ON COLUMN ax_flurstueck.zweifelhafterFlurstuecksnachweis IS 'ZFM "Zweifelhafter Flurstücksnachweis" ist eine Kennzeichnung eines Flurstücks, dessen Angaben nicht zweifelsfrei berichtigt werden können.';
COMMENT ON COLUMN ax_flurstueck.rechtsbehelfsverfahren    IS 'RBV "Rechtsbehelfsverfahren" ist der Hinweis darauf, dass bei dem Flurstück ein laufendes Rechtsbehelfsverfahren anhängig ist.';
COMMENT ON COLUMN ax_flurstueck.zeitpunktderentstehung    IS 'ZDE "Zeitpunkt der Entstehung" ist der Zeitpunkt, zu dem das Flurstück fachlich entstanden ist.';
COMMENT ON COLUMN ax_flurstueck.gemeinde                  IS 'Gemeindekennzeichen zur Zuordnung der Flustücksdaten zu einer Gemeinde.';
COMMENT ON COLUMN ax_flurstueck.name                      IS 'Array mit Fortführungsjahr und -Nummer';
COMMENT ON COLUMN ax_flurstueck.regierungsbezirk          IS 'Regierungsbezirk';
COMMENT ON COLUMN ax_flurstueck.kreis                     IS 'Kreis';
-- COMMENT ON COLUMN ax_flurstueck.beziehtsichaufflurstueck  IS '<- Beziehung zu ax_flurstueck (0..*):
-- Es handelt sich um die inverse Relationsrichtung.';
COMMENT ON COLUMN ax_flurstueck.zeigtauf                  IS '-> Beziehung zu ax_lagebezeichnungohnehausnummer (0..*): ''Flurstück'' zeigt auf ''Lagebezeichnung ohne Hausnummer''.';
COMMENT ON COLUMN ax_flurstueck.istgebucht                IS '-> Beziehung zu ax_buchungsstelle (1): Ein (oder mehrere) Flurstück(e) ist (sind) unter genau einer Buchungsstelle gebucht. Bei Anteilsbuchungen ist dies nur dann möglich, wenn ein fiktives Buchungsblatt angelegt wird. Wird ein fiktives Buchunsblatt verwendet, ist die Kardinalität dieser Attributart 1..1.';
COMMENT ON COLUMN ax_flurstueck.weistauf                  IS '-> Beziehung zu ax_lagebezeichnungmithausnummer (0..*): ''Flurstück'' weist auf ''Lagebezeichnung mit Hausnummer''.';
COMMENT ON COLUMN ax_flurstueck.gehoertanteiligzu         IS '-> Beziehung zu ax_flurstueck (0..*): ''Flurstück'' gehört anteilig zu ''Flurstück''. Die Relationsart kommt nur vor bei Flurstücken, die eine Relation zu einer Buchungsstelle mit einer der Buchungsarten Anliegerweg, Anliegergraben oder Anliegerwasserlauf aufweisen.';

COMMENT ON INDEX  ax_flurstueck_kennz                     IS 'Suche nach Flurstückskennzeichen';


-- B e s o n d e r e   F l u r s t u e c k s g r e n z e
-- -----------------------------------------------------
-- Objektart: AX_BesondereFlurstuecksgrenze Kennung: 11002
CREATE TABLE ax_besondereflurstuecksgrenze (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artderflurstuecksgrenze integer[],
  CONSTRAINT ax_besondereflurstuecksgrenze_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_besondereflurstuecksgrenze','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/MULTILINESTRING

CREATE        INDEX ax_besondereflurstuecksgrenze_geom_idx  ON ax_besondereflurstuecksgrenze USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_besondereflurstuecksgrenze_gml       ON ax_besondereflurstuecksgrenze USING btree (gml_id, beginnt);
CREATE        INDEX ax_besondereflurstuecksgrenze_adfg      ON ax_besondereflurstuecksgrenze USING gin   (artderflurstuecksgrenze);

COMMENT ON TABLE  ax_besondereflurstuecksgrenze        IS 'Angaben zum Flurstück: (REO) "Besondere Flurstücksgrenze" ist ein Teil der Grenzlinie eines Flurstücks, der von genau zwei benachbarten Grenzpunkten begrenzt wird und für den besondere Informationen vorliegen.';
COMMENT ON COLUMN ax_besondereflurstuecksgrenze.gml_id IS 'Identifikator, global eindeutig';


-- G r e n z p u n k t
-- ----------------------------------------------
-- Objektart: AX_Grenzpunkt Kennung: 11003
CREATE TABLE ax_grenzpunkt (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  punktkennung character varying,
  land character varying,
  stelle character varying,
  abmarkung_marke integer,
  festgestelltergrenzpunkt character varying,
  besonderepunktnummer character varying,
  bemerkungzurabmarkung integer,
  sonstigeeigenschaft character varying[],
  art character varying,
  name character varying[],
  zeitpunktderentstehung character varying,
  relativehoehe double precision,
  -- Beziehungen:
  zeigtauf character varying, -- -> ax_grenzpunkt
  CONSTRAINT ax_grenzpunkt_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_grenzpunkt','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_grenzpunkt_gml ON ax_grenzpunkt USING btree (gml_id, beginnt);
CREATE INDEX ax_grenzpunkt_gml16 ON ax_grenzpunkt USING btree (substring(gml_id,1,16)); -- ALKIS-Relation
CREATE INDEX ax_grenzpunkt_abmm  ON ax_grenzpunkt USING btree (abmarkung_marke);
CREATE INDEX ax_grenzpunkt_za    ON ax_grenzpunkt USING btree (zeigtauf);

COMMENT ON TABLE  ax_grenzpunkt        IS 'Angaben zum Flurstück: (ZUSO) "Grenzpunkt" ist ein den Grenzverlauf bestimmender, meist durch Grenzzeichen gekennzeichneter Punkt.';
COMMENT ON COLUMN ax_grenzpunkt.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_grenzpunkt.zeigtauf IS '-> Beziehung zu ax_grenzpunkt (0..1): Ein von der Geometrie der Flurstücksfläche abweichender ''Grenzpunkt'' (Sonderfall des indirekt abgemarkten Grenzpunktes) zeigt auf einen ''Grenzpunkt'', der in der Flurstücksgrenze liegt.';


--** Objektartengruppe: Angaben zur Lage
--   ===================================================================

-- L a g e b e z e i c h n u n g   o h n e   H a u s n u m m e r
-- -------------------------------------------------------------
-- Objektart: AX_LagebezeichnungOhneHausnummer Kennung: 12001
CREATE TABLE ax_lagebezeichnungohnehausnummer (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  unverschluesselt character varying, -- Gewanne
  land character varying,
  regierungsbezirk character varying,
  kreis character varying,
  gemeinde character varying,
  lage character varying, -- Strassenschluessel
  zusatzzurlagebezeichnung character varying,
  -- Beziehungen:
--beschreibt character varying[], -- <- ax_historischesflurstueckohneraumbezug
--gehoertzu character varying[], -- <- ax_flurstueck
  CONSTRAINT ax_lagebezeichnungohnehausnummer_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_lagebezeichnungohnehausnummer','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_lagebezeichnungohnehausnummer_gml ON ax_lagebezeichnungohnehausnummer USING btree (gml_id, beginnt);
CREATE INDEX ax_lagebezeichnungohnehausnummer_gml16      ON ax_lagebezeichnungohnehausnummer USING btree (substring(gml_id,1,16)); -- ALKIS-Relation
CREATE INDEX ax_lagebezeichnungohnehausnummer_key        ON ax_lagebezeichnungohnehausnummer USING btree (land, regierungsbezirk, kreis, gemeinde,lage);
--EATE INDEX ax_lagebezeichnungohnehausnummer_beschreibt ON ax_lagebezeichnungohnehausnummer USING gin (beschreibt);
--EATE INDEX ax_lagebezeichnungohnehausnummer_gehoertzu  ON ax_lagebezeichnungohnehausnummer USING gin (gehoertzu);

COMMENT ON TABLE  ax_lagebezeichnungohnehausnummer        IS 'Angaben zur Lage: (NREO) "Lagebezeichnung ohne Hausnummer" ist die ortsübliche oder amtlich festgesetzte Benennung der Lage von Flurstücken, die keine Hausnummer haben (z.B. Namen und Bezeichnungen von Gewannen, Straßen, Gewässern).';
COMMENT ON COLUMN ax_lagebezeichnungohnehausnummer.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_lagebezeichnungohnehausnummer.land       IS 'Schlüssel des Bundeslandes';
COMMENT ON COLUMN ax_lagebezeichnungohnehausnummer.regierungsbezirk IS 'Schlüssel des Regierungsbezirkes im Bundesland';
COMMENT ON COLUMN ax_lagebezeichnungohnehausnummer.kreis      IS 'Schlüssel des Kreises im Regierungsbezirkes';
COMMENT ON COLUMN ax_lagebezeichnungohnehausnummer.gemeinde   IS 'Schlüssel der Gemeinde im Kreis';
COMMENT ON COLUMN ax_lagebezeichnungohnehausnummer.lage       IS 'Straßenschlüssel in der Gemeinde';
--MMENT ON COLUMN ax_lagebezeichnungohnehausnummer.zusatzzurlagebezeichnung IS '__';

--COMMENT ON COLUMN ax_lagebezeichnungohnehausnummer.beschreibt IS '<- Beziehung zu ax_historischesflurstueckohneraumbezug (0..*):
--Es handelt sich um die inverse Relationsrichtung.';
--COMMENT ON COLUMN ax_lagebezeichnungohnehausnummer.gehoertzu  IS '<- Beziehung zu ax_flurstueck (1..*): Eine ''Lagebezeichnung ohne Hausnummer'' gehört zu einem oder mehreren ''Flurstücken''.
--Es handelt sich um die inverse Relationsrichtung.';


-- L a g e b e z e i c h n u n g   m i t   H a u s n u m m e r
-- -----------------------------------------------------------
-- Objektart: AX_LagebezeichnungOhneHausnummer Kennung: 12001
CREATE TABLE ax_lagebezeichnungmithausnummer (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  land character varying,
  regierungsbezirk character varying,
  kreis character varying,
  gemeinde character varying,
  lage character varying, -- Strassenschluessel
  hausnummer character varying, -- Nummer (blank) Zusatz
  -- Beziehungen:
--hat character varying[], -- <- ax_historischesflurstueckohneraumbezug
--beziehtsichauf character varying, -- <- ax_gebaeude
--beziehtsichauchauf character varying, -- <- ax_georeferenziertegebaeudeadresse
--gehoertzu character varying[], -- <- ax_flurstueck
--weistzum character varying, -- <- ax_turm
  CONSTRAINT ax_lagebezeichnungmithausnummer_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_lagebezeichnungmithausnummer','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_lagebezeichnungmithausnummer_gml ON ax_lagebezeichnungmithausnummer USING btree (gml_id, beginnt);
CREATE INDEX ax_lagebezeichnungmithausnummer_gml16      ON ax_lagebezeichnungmithausnummer USING btree (substring(gml_id,1,16)); -- ALKIS-Relation
CREATE INDEX ax_lagebezeichnungmithausnummer_lage       ON ax_lagebezeichnungmithausnummer USING btree (gemeinde, lage);
--EATE INDEX ax_lagebezeichnungmithausnummer_hat        ON ax_lagebezeichnungmithausnummer USING gin   (hat);
--EATE INDEX ax_lagebezeichnungmithausnummer_bsa        ON ax_lagebezeichnungmithausnummer USING btree (beziehtsichauf);
--EATE INDEX ax_lagebezeichnungmithausnummer_bsaa       ON ax_lagebezeichnungmithausnummer USING btree (beziehtsichauchauf);
--EATE INDEX ax_lagebezeichnungmithausnummer_gehoertzu  ON ax_lagebezeichnungmithausnummer USING gin   (gehoertzu);
--EATE INDEX ax_lagebezeichnungmithausnummer_weistzum   ON ax_lagebezeichnungmithausnummer USING btree (weistzum);

COMMENT ON TABLE  ax_lagebezeichnungmithausnummer       IS 'Angaben zur Lage: (NREO) "Lagebezeichnung mit Hausnummer" ist die ortsübliche oder amtlich festgesetzte Benennung der Lage von Flurstücken und Gebäuden, die eine Lagebezeichnung mit Hausnummer haben.';
-- Hinweis zur Ableitung einer punktförmigen Geometrie zur Verortung der Hausnummer:
-- Bei einer abweichenden Positionierung von der Standardposition liegt ein Präsentationsobjekt (Text) vor aus dem diese abgeleitet werden kann.
COMMENT ON COLUMN ax_lagebezeichnungmithausnummer.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_lagebezeichnungmithausnummer.land       IS 'Schlüssel des Bundeslandes';
COMMENT ON COLUMN ax_lagebezeichnungmithausnummer.regierungsbezirk IS 'Schlüssel des Regierungsbezirkes im Bundesland';
COMMENT ON COLUMN ax_lagebezeichnungmithausnummer.kreis      IS 'Schlüssel des Kreises im Regierungsbezirkes';
COMMENT ON COLUMN ax_lagebezeichnungmithausnummer.gemeinde   IS 'Schlüssel der Gemeinde im Kreis';
COMMENT ON COLUMN ax_lagebezeichnungmithausnummer.lage       IS 'Straßenschlüssel in der Gemeinde';
COMMENT ON COLUMN ax_lagebezeichnungmithausnummer.hausnummer IS 'Hausnummer und Hausnummernzusatz';

--COMMENT ON COLUMN ax_lagebezeichnungmithausnummer.hat IS '<- Beziehung zu ax_historischesflurstueckohneraumbezug (0..*):
--Es handelt sich um die inverse Relationsrichtung.';
--COMMENT ON COLUMN ax_lagebezeichnungmithausnummer.beziehtsichauf IS '<- Beziehung zu ax_gebaeude (0..1): Eine ''Lagebezeichnung mit Hausnummer'' bezieht sich auf ein ''Gebäude''.
--Es handelt sich um die inverse Relationsrichtung.';
--COMMENT ON COLUMN ax_lagebezeichnungmithausnummer.beziehtsichauchauf IS '<- Beziehung zu ax_georeferenziertegebaeudeadresse (0..1):
--Es handelt sich um die inverse Relationsrichtung.';
--COMMENT ON COLUMN ax_lagebezeichnungmithausnummer.gehoertzu IS '<- Beziehung zu ax_flurstueck (1..*): Eine ''Lagebezeichnung mit Hausnummer'' gehört zu einem oder mehreren ''Flurstücken''.
--Es handelt sich um die inverse Relationsrichtung.';
--COMMENT ON COLUMN ax_lagebezeichnungmithausnummer.weistzum IS '<- Beziehung zu ax_turm (0..1): Eine ''Lagebezeichnung mit Hausnummer'' weist zum ''Turm''.
--Es handelt sich um die inverse Relationsrichtung.';


-- L a g e b e z e i c h n u n g   m i t  P s e u d o n u m m e r
-- --------------------------------------------------------------
-- Objektart: AX_LagebezeichnungMitPseudonummer Kennung: 12003
-- Nebengebäude: lfd-Nummer eines Nebengebäudes zu einer (Pseudo-) Hausnummer
CREATE TABLE ax_lagebezeichnungmitpseudonummer (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  land character varying,
  regierungsbezirk character varying,
  kreis character varying,
  gemeinde character varying,
  lage character varying, -- Strassenschluessel
  pseudonummer character varying,
  laufendenummer character varying, -- leer, Zahl, "P2"
  -- Beziehungen:
--gehoertzu character varying, -- <- ax_gebaeude
  CONSTRAINT ax_lagebezeichnungmitpseudonummer_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_lagebezeichnungmitpseudonummer','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_lagebezeichnungmitpseudonummer_gml ON ax_lagebezeichnungmitpseudonummer USING btree (gml_id, beginnt);
CREATE INDEX ax_lagebezeichnungmitpseudonummer_gml16      ON ax_lagebezeichnungmitpseudonummer USING btree (substring(gml_id,1,16)); -- ALKIS-Relation
--EATE INDEX ax_lagebezeichnungmitpseudonummer_gehoertzu  ON ax_lagebezeichnungmitpseudonummer USING btree (gehoertzu);

COMMENT ON TABLE  ax_lagebezeichnungmitpseudonummer        IS 'Angaben zur Lage: (NREO) "Lagebezeichnung mit Pseudonummer" ist die von der Katasterbehörde für ein bestehendes oder geplantes Gebäude vergebene Lagebezeichnung und ggf. einem Adressierungszusatz, wenn von der Gemeinde für das Gebäude keine Lagebezeichnung mit Hausnummer vergeben wurde (z.B. Kirche, Nebengebäude).';
-- Dies sind die Nebengebäude, die zu einen Hauptgebäude (mit Hausnummer) durchnummeriert sind.
COMMENT ON COLUMN ax_lagebezeichnungmitpseudonummer.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_lagebezeichnungmitpseudonummer.land       IS 'Schlüssel des Bundeslandes';
COMMENT ON COLUMN ax_lagebezeichnungmitpseudonummer.regierungsbezirk IS 'Schlüssel des Regierungsbezirkes im Bundesland';
COMMENT ON COLUMN ax_lagebezeichnungmitpseudonummer.kreis      IS 'Schlüssel des Kreises im Regierungsbezirkes';
COMMENT ON COLUMN ax_lagebezeichnungmitpseudonummer.gemeinde   IS 'Schlüssel der Gemeinde im Kreis';
COMMENT ON COLUMN ax_lagebezeichnungmitpseudonummer.lage       IS 'Straßenschlüssel in der Gemeinde';

COMMENT ON COLUMN ax_lagebezeichnungmitpseudonummer.pseudonummer   IS '(Pseudo-) Hausnummer des zugehörigen Hauptgebäudes';
COMMENT ON COLUMN ax_lagebezeichnungmitpseudonummer.laufendenummer IS 'laufende Nummer des Nebengebäudes';

--COMMENT ON COLUMN ax_lagebezeichnungmitpseudonummer.gehoertzu IS '<- Beziehung zu ax_gebaeude (1): Eine ''Lagebezeichnung mit Pseudonummer'' gehört zu einem ''Gebäude''.
--Es handelt sich um die inverse Relationsrichtung.';


-- Georeferenzierte  G e b ä u d e a d r e s s e
-- ----------------------------------------------
-- Objektart: AX_GeoreferenzierteGebaeudeadresse Kennung: 12006
CREATE TABLE ax_georeferenziertegebaeudeadresse (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  qualitaetsangaben integer, -- zb: "1000" (= Massstab)
  land character varying, -- "05" = NRW
  regierungsbezirk character varying,
  kreis character varying,
  gemeinde character varying,
  ortsteil integer,
  postleitzahl character varying, -- mit fuehrenden Nullen
  ortsnamepost character varying,
  zusatzortsname character varying,
  strassenname character varying,
  strassenschluessel character varying, -- max. 5 Stellen
  hausnummer character varying, -- meist 3 Stellen
  adressierungszusatz character varying, -- Hausnummernzusatz-Buchstabe
  -- Beziehungen:
  hatauch character varying, -- <- ax_lagebezeichnungmithausnummer
  CONSTRAINT ax_georeferenziertegebaeudeadresse_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_georeferenziertegebaeudeadresse','wkb_geometry',:alkis_epsg,'POINT',2);

CREATE INDEX ax_georeferenziertegebaeudeadresse_geom_idx ON ax_georeferenziertegebaeudeadresse USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_georeferenziertegebaeudeadresse_gml ON ax_georeferenziertegebaeudeadresse USING btree (gml_id, beginnt);
CREATE INDEX ax_georeferenziertegebaeudeadresse_adr ON ax_georeferenziertegebaeudeadresse USING btree (strassenschluessel, hausnummer, adressierungszusatz);

COMMENT ON TABLE  ax_georeferenziertegebaeudeadresse        IS 'Angaben zur Lage: (REO) "Georeferenzierte Gebäudeadresse" enthält alle Informationen für die Ausgabe der amtlichen Hauskoordinate. Die Abgabe erfolgt über Bestandsdatenauszug bzw. NBA-Verfahren. Das bisherige Verfahren zur Abgabe der Hauskoordinaten kann durch eine XSLT-Transformation erzeugt werden.';
COMMENT ON COLUMN ax_georeferenziertegebaeudeadresse.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_georeferenziertegebaeudeadresse.hatauch IS '<- Beziehung zu ax_lagebezeichnungmithausnummer (1): Die inverse Relation wird optional belegt, damit keine Implementierung unmittelbar zur Umstellung auf das neue Verfahren zur Ableitung der Hauskoordinate gezwungen wird.';


--** Objektartengruppe: Angaben zum Netzpunkt
--   ===================================================================

-- A u f n a h m e p u n k t
-- ----------------------------------------------
-- Objektart: AX_Aufnahmepunkt Kennung: 13001
CREATE TABLE ax_aufnahmepunkt (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  punktkennung character varying, -- integer ist zu klein,
  land character varying,
  stelle character varying,
  sonstigeeigenschaft character varying[],
  vermarkung_marke integer,
  relativehoehe double precision,
  -- Beziehungen:
  hat character varying[], -- -> ax_sicherungspunkt
  CONSTRAINT ax_aufnahmepunkt_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_aufnahmepunkt','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_aufnahmepunkt_gml ON ax_aufnahmepunkt USING btree (gml_id, beginnt);
CREATE        INDEX ax_aufnahmepunkt_hat ON ax_aufnahmepunkt USING gin   (hat);

COMMENT ON TABLE  ax_aufnahmepunkt        IS 'Angaben zum Netzpunkt: (ZUSO) "Aufnahmepunkt" ist ein Punkt des Lagefestpunktfeldes - Aufnahmepunktfeld und dient der örtlichen Aufnahme von Objektpunkten.
Das Aufnahmepunktfeld ist eine Verdichtungsstufe des Lagefestpunktfeldes - Trigonometrisches Festpunktfeld (Grundlagenvermessung).';
COMMENT ON COLUMN ax_aufnahmepunkt.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_aufnahmepunkt.hat IS '-> Beziehung zu ax_sicherungspunkt (0..*): ''Aufnahmepunkt'' hat ''Sicherungspunkt''.';


-- S i c h e r u n g s p u n k t
-- ----------------------------------------------
-- Objektart: AX_Sicherungspunkt Kennung: 13002
CREATE TABLE ax_sicherungspunkt (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  name character varying,
  punktkennung character varying,
  land character varying,
  stelle character varying,
  sonstigeeigenschaft character varying[],
  vermarkung_marke integer,
  relativehoehe double precision,
  -- Beziehungen:
--beziehtsichauf character varying, -- <- ax_sonstigervermessungspunkt
--gehoertzu character varying, -- <- ax_aufnahmepunkt
  CONSTRAINT ax_sicherungspunkt_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_sicherungspunkt','dummy',:alkis_epsg,'POINT',2);

COMMENT ON TABLE  ax_sicherungspunkt IS 'Angaben zum Netzpunkt: (ZUSO "Sicherungspunkt") ist ein Punkt des Aufnahmepunktfeldes, der vermarkt ist und der Sicherung eines Aufnahmepunktes dient.';

--COMMENT ON COLUMN ax_sicherungspunkt.beziehtsichauf IS '<- Beziehung zu ax_sonstigervermessungspunkt (0..1): "Sicherungspunkt" bezieht sich auf "Sonstiger Vermessungspunkt"
--Es handelt sich um die inverse Relationsrichtung.';
--COMMENT ON COLUMN ax_sicherungspunkt.gehoertzu      IS '<- Beziehung zu ax_aufnahmepunkt (0..1): ''Sicherungspunkt'' gehört zu ''Aufnahmepunkt''.
--Es handelt sich um die inverse Relationsrichtung.';


-- s o n s t i g e r   V e r m e s s u n g s p u n k t
-- ---------------------------------------------------
-- Objektart: AX_SonstigerVermessungspunkt Kennung: 13003
CREATE TABLE ax_sonstigervermessungspunkt (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  vermarkung_marke integer,
  punktkennung character varying, -- integer,
  art character varying,
  land character varying,
  stelle character varying,
  sonstigeeigenschaft character varying[],
  relativehoehe double precision,
  -- Beziehungen:
  hat character varying[], --> ax_sicherungspunkt
  CONSTRAINT ax_sonstigervermessungspunkt_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_sonstigervermessungspunkt','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_sonstigervermessungspunkt_gml ON ax_sonstigervermessungspunkt USING btree (gml_id, beginnt);
CREATE INDEX ax_sonstigervermessungspunkt_hat  ON ax_sonstigervermessungspunkt  USING gin  (hat);

COMMENT ON TABLE  ax_sonstigervermessungspunkt        IS 'Angaben zum Netzpunkt: (ZUSO) "sonstiger Vermessungspunkt" ist ein Punkt des Aufnahmepunktfeldes, der weder Aufnahmepunkt noch Sicherungspunkt ist (z. B. Polygonpunkt, Liniennetzpunkt).';
COMMENT ON COLUMN ax_sonstigervermessungspunkt.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_sonstigervermessungspunkt.hat IS '-> Beziehung zu ax_sicherungspunkt (0..*): "Sonstiger Vermessungspunkt" hat "Sicherungspunkt"';

-- Objektart: AX_Netzpunkt Kennung: 13004
-- ** Tabelle bisher noch nicht generiert

--** Objektartengruppe: Angaben zum Punktort
--   ===================================================================

-- AX_Punktort
-- -----------
-- "Punktort" definiert die räumliche Position oder die ebene Lage oder die Höhe eines Objektes
-- der Objektarten "Lagefestpunkt, Höhenfestpunkt, Schwerefestpunkt, Referenzstationspunkt,
-- Grenzpunkt, Besonderer Gebäudepunkt, Aufnahmepunkt, Sicherungspunkt, Sonstiger Vermessungspunkt,
-- Besonderer topographischer Punkt, Besonderer Bauwerkspunkt" in einem Bezugssystem
-- (nach ISO 19111). Es sind keine zusammengesetzten Bezugssysteme (ISO 19111, Ziffer 6.2.3) zugelassen.
-- Bei AX_Punktort handelt es sich um die abstrakte Verallgemeinerung der drei Punktortvarianten
-- 'Punktort AG', 'Punktort AU' und 'Punktort TA', die sich jeweils in ihrer geometrischen Ausprägung
-- entsprechend dem AAA-Basisschema unterscheiden.
-- Jedes Objekt Punktort kann nur zu einem Punktobjekt gehören, auch wenn mehrere Punkte aufeinander fallen.
-- Es handelt sich um eine abstrakte Objektart.

-- P u n k t o r t   AG
-- ----------------------------------------------
-- Objektart: AX_PunktortAG Kennung: 14002
CREATE TABLE ax_punktortag (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art character varying[],
  name character varying[],
  kartendarstellung character varying,
  ax_datenerhebung_punktort integer,
  genauigkeitsstufe integer,
  vertrauenswuerdigkeit integer,
  koordinatenstatus integer,
  hinweise character varying,
  -- Beziehungen:
  istteilvon character varying, --> ?
  CONSTRAINT ax_punktortag_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_punktortag','wkb_geometry',:alkis_epsg,'POINT',2);

CREATE INDEX ax_punktortag_geom_idx   ON ax_punktortag USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_punktortag_gml ON ax_punktortag USING btree (gml_id, beginnt);
CREATE INDEX ax_punktortag_itv_idx    ON ax_punktortag USING btree (istteilvon);

COMMENT ON TABLE  ax_punktortag        IS 'Angaben zum Punktort: (REO) "Punktort AG" ist ein Punktort mit redundanzfreier Geometrie (Besonderer Gebäudepunkt, Besonderer Bauwerkspunkt) innerhalb eines Geometriethemas.';
COMMENT ON COLUMN ax_punktortag.gml_id IS 'Identifikator, global eindeutig';


-- P u n k t o r t   A U
-- ----------------------------------------------
-- Objektart: AX_PunktortAU Kennung: 14003
CREATE TABLE ax_punktortau (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  kartendarstellung character varying, -- AX_Punktort Boolean
  ax_datenerhebung_punktort integer,
  name character varying[],
  individualname character varying,
  vertrauenswuerdigkeit integer,
  genauigkeitsstufe integer,
  koordinatenstatus integer, -- AX_Punktort
--ueberpruefungsdatum         -- AX_Punktort
--qualitaetsangaben           -- AX_Punktort
  hinweise character varying, -- AX_Punktort
  -- Beziehungen:
  istteilvon character varying,
  CONSTRAINT ax_punktortau_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_punktortau','wkb_geometry',:alkis_epsg,'POINT',3); -- 0,0,Höhe

CREATE INDEX ax_punktortau_geom_idx   ON ax_punktortau USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_punktortau_gml ON ax_punktortau USING btree (gml_id, beginnt);
CREATE INDEX ax_punktortau_itv_idx    ON ax_punktortau USING btree (istteilvon);

COMMENT ON TABLE  ax_punktortau        IS 'Angaben zum Punktort: (REO) "Punktort AU" ist ein Punktort mit unabhängiger Geometrie ohne Zugehörigkeit zu einem Geometriethema.
Er kann zu ZUSOs der folgenden Objektarten gehören: Grenzpunkt, Besonderer Gebäudepunkt, Besonderer Bauwerkspunkt, Aufnahmepunkt, Sicherungspunkt, Sonstiger Vermessungspunkt, Besonderer topographischer Punkt, Lagefestpunkt, Höhenfestpunkt, Schwerefestpunkt, Referenzstationspunkt.';
COMMENT ON COLUMN ax_punktortau.gml_id IS 'Identifikator, global eindeutig';


-- P u n k t o r t   T A
-- ----------------------------------------------
-- Objektart: AX_PunktortTA Kennung: 14004
CREATE TABLE ax_punktortta (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  kartendarstellung character varying,
  description integer,
  ax_datenerhebung_punktort integer,
  art character varying[],
  name character varying[],
  genauigkeitsstufe integer,
  vertrauenswuerdigkeit integer,
  koordinatenstatus integer,
  hinweise character varying,
  -- Beziehungen:
  istteilvon character varying,
  CONSTRAINT ax_punktortta_pk   PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_punktortta','wkb_geometry',:alkis_epsg,'POINT',2);

CREATE INDEX ax_punktortta_geom_idx   ON ax_punktortta USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_punktortta_gml ON ax_punktortta USING btree (gml_id, beginnt);
CREATE INDEX ax_punktortta_endet_idx  ON ax_punktortta USING btree (endet);
CREATE INDEX ax_punktortta_itv_idx    ON ax_punktortta USING btree (istteilvon);

COMMENT ON TABLE  ax_punktortta        IS 'Angaben zum Punktort: (REO) "Punktort TA" ist ein Punktort, der in der Flurstücksgrenze liegt und einen Grenzpunkt verortet.';
COMMENT ON COLUMN ax_punktortta.gml_id IS 'Identifikator, global eindeutig';


--** Objektartengruppe: Fortführungsnachweis
--   ===================================================================

-- F o r t f u e h r u n g s n a c h w e i s / D e c k b l a t t
-- --------------------------------------------------------------
-- Objektart: AX_FortfuehrungsnachweisDeckblatt Kennung: 15001
CREATE TABLE ax_fortfuehrungsnachweisdeckblatt (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  uri character varying, -- wirklich?
  fortfuehrungsfallnummernbereich character varying,
  land character varying,
  gemarkungsnummer character varying,
  laufendenummer integer,
  titel character varying,
  erstelltam character varying, -- Datum jjjj-mm-tt
  fortfuehrungsentscheidungam character varying,
  fortfuehrungsentscheidungvon character varying, -- Bearbeiter-Name und -Titel
  bemerkung character varying,
  -- Beziehungen:
  beziehtsichauf character varying, -- Index drauf?
  CONSTRAINT ax_fortfuehrungsnachweisdeckblatt_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_fortfuehrungsnachweisdeckblatt','dummy',:alkis_epsg,'POINT',2);

COMMENT ON TABLE  ax_fortfuehrungsnachweisdeckblatt IS 'Fortführungsnachweis: (NREO) "Fortfuehrungsnachweis-Deckblatt" enthält alle administrativen Angaben für einen Fortführungsnachweis.';


-- F o r t f u e h r u n g s f a l l
-- ---------------------------------
-- Objektart: AX_Fortfuehrungsfall Kennung: 15002
CREATE TABLE ax_fortfuehrungsfall (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  uri character varying,
  fortfuehrungsfallnummer integer,
  laufendenummer integer,
  ueberschriftimfortfuehrungsnachweis integer[],
  anzahlderfortfuehrungsmitteilungen integer,
  -- Beziehungen:
  zeigtaufaltesflurstueck character varying[], -- Format wie flurstueckskennzeichen (20) als Array
  zeigtaufneuesflurstueck character varying[], -- Format wie flurstueckskennzeichen (20) als Array
  bemerkung character varying,
  CONSTRAINT ax_fortfuehrungsfall_pk PRIMARY KEY (ogc_fid)
);
SELECT AddGeometryColumn('ax_fortfuehrungsfall','dummy',:alkis_epsg,'POINT',2);

COMMENT ON TABLE  ax_fortfuehrungsfall IS 'Fortführungsnachweis: (NREO) "Fortfuehrungsfall" beschreibt die notwendigen Angaben zum Aufbau eines Fortführungsnachweises. Er legt die Reihenfolge der zu verändernden Flurstücke innerhalb eines Fortführungsnachweises fest (Aufbau des Fortführungsnachweises).';


--** Objektartengruppe: Angaben zur Reservierung
--   ===================================================================

-- R e s e r v i e r u n g
-- -----------------------
-- Objektart: AX_Reservierung Kennung: 16001
CREATE TABLE ax_reservierung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art integer,
  nummer character varying,
  land character varying,
  stelle character varying,
  ablaufderreservierung character varying,
  antragsnummer character varying,
  auftragsnummer character varying,
  CONSTRAINT ax_reservierung_pk PRIMARY KEY (ogc_fid)
);
SELECT AddGeometryColumn('ax_reservierung','dummy',:alkis_epsg,'POINT',2);

COMMENT ON TABLE  ax_reservierung IS 'Angaben zur Reservierung: (NREO) "Reservierung" enthält Ordnungsnummern des Liegenschaftskatasters, die für eine durchzuführende Vermessungssache reserviert sind.';

-- 2016-01-14 olt@omniscale.de: improves diff import speed
CREATE UNIQUE INDEX ax_reservierung_gml ON ax_reservierung USING btree (gml_id, beginnt);

-- P u n k t k e n n u n g   U n t e r g e g a n g e n
-- ---------------------------------------------------
-- Objektart: AX_PunktkennungUntergegangen Kennung: 16002
CREATE TABLE ax_punktkennunguntergegangen (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  punktkennung character varying,
  art integer,
  CONSTRAINT ax_punktkennunguntergegangen_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_punktkennunguntergegangen','dummy',:alkis_epsg,'POINT',2);

COMMENT ON TABLE  ax_punktkennunguntergegangen IS 'Angaben zur Reservierung: (NREO) "Punktkennung, untergegangen" enthält Punktkennungen, die untergegangen sind.';

-- Objektart: AX_PunktkennungVergleichend Kennung: 16003
-- 'Punktkennung vergleichend' (NREO) enthält vorläufige Punktkennungen.


--** Objektartengruppe: Angaben zur Historie
--   ===================================================================

-- Historisches Flurstück (ALKIS)
-- ------------------------------
-- Objektart: AX_HistorischesFlurstueck Kennung: 17001
-- Die "neue" Historie, die durch Fortführungen innerhalb von ALKIS entstanden ist.
CREATE TABLE ax_historischesflurstueck (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art character varying[],
  name character varying[],

  -- GID: AX_Flurstueck_Kerndaten
  -- 'Flurstück_Kerndaten' enthält Eigenschaften des Flurstücks, die auch für andere Flurstücksobjektarten gelten (z.B. Historisches Flurstück).
  land character varying, --
  gemarkungsnummer character varying,
  flurnummer integer,
  zaehler integer,
  nenner integer,
  -- daraus abgeleitet:
  flurstueckskennzeichen character(20), -- Inhalt rechts mit __ auf 20 aufgefüllt
  amtlicheflaeche double precision, -- AFL
  abweichenderrechtszustand character varying DEFAULT 'false', -- ARZ
  zweifelhafterflurstuecksnachweis character varying DEFAULT 'false', -- ZFM Boolean
  rechtsbehelfsverfahren character varying DEFAULT 'false', -- RBV
  zeitpunktderentstehung character(10), -- ZDE  Inhalt jjjj-mm-tt  besser Format date ?
  zeitpunktderhistorisierung character varying, -- oder (10) ?
  gemeinde character varying,
  -- GID: ENDE AX_Flurstueck_Kerndaten

  regierungsbezirk character varying,
  kreis character varying,
  vorgaengerflurstueckskennzeichen character varying[],
  nachfolgerflurstueckskennzeichen character varying[],
  blattart integer,
  buchungsart character varying,
  buchungsblattkennzeichen character varying[],
  bezirk character varying,
  buchungsblattnummermitbuchstabenerweiterung character varying[],
  laufendenummerderbuchungsstelle integer,
  CONSTRAINT ax_historischesflurstueck_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_historischesflurstueck','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/MULTIPOLYGON

CREATE INDEX ax_historischesflurstueck_geom_idx   ON ax_historischesflurstueck USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_historischesflurstueck_gml ON ax_historischesflurstueck USING btree (gml_id, beginnt);
CREATE INDEX ax_historischesflurstueck_kennz      ON ax_historischesflurstueck USING btree (flurstueckskennzeichen);

-- Suche nach Vorgänger / Nachfolger
CREATE INDEX idx_histfs_vor  ON ax_historischesflurstueck USING btree (vorgaengerflurstueckskennzeichen);
CREATE INDEX idx_histfs_nach ON ax_historischesflurstueck USING btree (vorgaengerflurstueckskennzeichen);

  COMMENT ON TABLE  ax_historischesflurstueck        IS 'Angaben zur Historie: (REO) "Historisches Flurstück" ist ein fachlich nicht mehr aktuelles Flurstück, das im Rahmen der Historisierung in ALKIS entsteht (ALKIS-Standardhistorie).';
  COMMENT ON COLUMN ax_historischesflurstueck.gml_id IS 'Identifikator, global eindeutig';
  COMMENT ON COLUMN ax_historischesflurstueck.flurnummer                IS 'FLN "Flurnummer" ist die von der Katasterbehörde zur eindeutigen Bezeichnung vergebene Nummer einer Flur, die eine Gruppe von zusammenhängenden Flurstücken innerhalb einer Gemarkung umfasst.';
  COMMENT ON COLUMN ax_historischesflurstueck.zaehler                   IS 'ZAE  Dieses Attribut enthält den Zähler der Flurstücknummer';
  COMMENT ON COLUMN ax_historischesflurstueck.nenner                    IS 'NEN  Dieses Attribut enthält den Nenner der Flurstücknummer';
  COMMENT ON COLUMN ax_historischesflurstueck.flurstueckskennzeichen    IS '"Flurstückskennzeichen" ist ein von der Katasterbehörde zur eindeutigen Bezeichnung des Flurstücks vergebenes Ordnungsmerkmal.
Die Attributart setzt sich aus den nachfolgenden expliziten Attributarten in der angegebenen Reihenfolge zusammen:
 1.  Land (2 Stellen)
 2.  Gemarkungsnummer (4 Stellen)
 3.  Flurnummer (3 Stellen)
 4.  Flurstücksnummer
 4.1 Zähler (5 Stellen)
 4.2 Nenner (4 Stellen)
 5.  Flurstücksfolge (2 Stellen)
Die Elemente sind rechtsbündig zu belegen, fehlende Stellen sind mit führenden Nullen zu belegen.
Da die Flurnummer und die Flurstücksfolge optional sind, sind aufgrund der bundeseinheitlichen Definition im Flurstückskennzeichen die entsprechenden Stellen, sofern sie nicht belegt sind, durch Unterstrich "_" ersetzt.
Gleiches gilt für Flurstücksnummern ohne Nenner, hier ist der fehlende Nenner im Flurstückskennzeichen durch Unterstriche zu ersetzen.';
  COMMENT ON COLUMN ax_historischesflurstueck.amtlicheflaeche           IS 'AFL "Amtliche Fläche" ist der im Liegenschaftskataster festgelegte Flächeninhalt des Flurstücks in [qm]. Flurstücksflächen kleiner 0,5 qm können mit bis zu zwei Nachkommastellen geführt werden, ansonsten ohne Nachkommastellen.';
  COMMENT ON COLUMN ax_historischesflurstueck.abweichenderrechtszustand IS 'ARZ "Abweichender Rechtszustand" ist ein Hinweis darauf, dass außerhalb des Grundbuches in einem durch Gesetz geregelten Verfahren der Bodenordnung (siehe Objektart "Bau-, Raum- oder Bodenordnungsrecht", AA "Art der Festlegung", Werte 1750, 1770, 2100 bis 2340) ein neuer Rechtszustand eingetreten ist und das amtliche Verzeichnis der jeweiligen ausführenden Stelle maßgebend ist.';
  COMMENT ON COLUMN ax_historischesflurstueck.zweifelhafterFlurstuecksnachweis IS 'ZFM "Zweifelhafter Flurstücksnachweis" ist eine Kennzeichnung eines Flurstücks, dessen Angaben nicht zweifelsfrei berichtigt werden können.';
  COMMENT ON COLUMN ax_historischesflurstueck.rechtsbehelfsverfahren    IS 'RBV "Rechtsbehelfsverfahren" ist der Hinweis darauf, dass bei dem Flurstück ein laufendes Rechtsbehelfsverfahren anhängig ist.';
  COMMENT ON COLUMN ax_historischesflurstueck.zeitpunktderentstehung    IS 'ZDE "Zeitpunkt der Entstehung" ist der Zeitpunkt, zu dem das Flurstück fachlich entstanden ist.';
  COMMENT ON COLUMN ax_historischesflurstueck.gemeinde                  IS 'GDZ "Gemeindekennzeichen zur Zuordnung der Flustücksdaten zu einer Gemeinde.';

  COMMENT ON INDEX ax_historischesflurstueck_kennz IS 'Suche nach Flurstückskennzeichen';
  COMMENT ON INDEX idx_histfs_vor                  IS 'Suchen nach Vorgänger-Flurstück';
  COMMENT ON INDEX idx_histfs_nach                 IS 'Suchen nach Nachfolger-Flurstück';


-- H i s t o r i s c h e s   F l u r s t ü c k   A L B
-- ---------------------------------------------------
-- Objektart: AX_HistorischesFlurstueckALB Kennung: 17002

-- Variante A: "Standardhistorie" (statt ax_historischesflurstueckohneraumbezug)

-- Die "alte" Historie, die schon aus dem Vorgängerverfahren ALB übernommen wurde.
-- Vorgänger-Nachfolger-Beziehungen, ohne Geometrie

CREATE TABLE ax_historischesflurstueckalb (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  name character varying[],

  -- GID: AX_Flurstueck_Kerndaten
  -- 'Flurstück_Kerndaten' enthält Eigenschaften des Flurstücks, die auch für andere Flurstücksobjektarten gelten (z.B. Historisches Flurstück).
  land character varying, --
  gemarkungsnummer character varying,
  flurnummer integer,
  zaehler integer,
  nenner integer,
  flurstuecksfolge character varying,
  -- daraus abgeleitet:
  flurstueckskennzeichen character(20), -- Inhalt rechts mit __ auf 20 aufgefüllt

  amtlicheflaeche double precision, -- AFL
  abweichenderrechtszustand character varying DEFAULT 'false', -- ARZ
  zweifelhafterFlurstuecksnachweis character varying DEFAULT 'false', -- ZFM Boolean
  rechtsbehelfsverfahren character varying DEFAULT 'false', -- RBV
  zeitpunktderentstehung character(10), -- ZDE  jjjj-mm-tt
  gemeinde character varying,
  -- GID: ENDE AX_Flurstueck_Kerndaten

  blattart integer,
  buchungsart character varying[],
  buchungsblattkennzeichen character varying[],
  bezirk character varying,
  buchungsblattnummermitbuchstabenerweiterung character varying[],
  laufendenummerderbuchungsstelle character varying[],
  zeitpunktderentstehungdesbezugsflurstuecks character varying,
  laufendenummerderfortfuehrung character varying,
  fortfuehrungsart character varying,
  vorgaengerflurstueckskennzeichen character varying[],
  nachfolgerflurstueckskennzeichen character varying[],
  CONSTRAINT ax_historischesflurstueckalb_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_historischesflurstueckalb','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_historischesflurstueckalb_gml ON ax_historischesflurstueckalb USING btree (gml_id, beginnt);
CREATE INDEX idx_histfsalb_vor   ON ax_historischesflurstueckalb USING btree (vorgaengerflurstueckskennzeichen);
CREATE INDEX idx_histfsalb_nach  ON ax_historischesflurstueckalb USING btree (nachfolgerflurstueckskennzeichen);

  COMMENT ON TABLE  ax_historischesflurstueckalb        IS 'Angaben zur Historie: (NREO) "Historisches Flurstück ALB" ist ein nicht mehr aktuelles Flurstück, das schon im ALB historisch geworden ist und nach ALKIS migriert wird und in der ALKIS-Standardhistorie geführt wird.';
  COMMENT ON COLUMN ax_historischesflurstueckalb.gml_id IS 'Identifikator, global eindeutig';
  COMMENT ON COLUMN ax_historischesflurstueckalb.flurnummer                IS 'FLN "Flurnummer" ist die von der Katasterbehörde zur eindeutigen Bezeichnung vergebene Nummer einer Flur, die eine Gruppe von zusammenhängenden Flurstücken innerhalb einer Gemarkung umfasst.';
  COMMENT ON COLUMN ax_historischesflurstueckalb.zaehler                   IS 'ZAE  Dieses Attribut enthält den Zähler der Flurstücknummer';
  COMMENT ON COLUMN ax_historischesflurstueckalb.nenner                    IS 'NEN  Dieses Attribut enthält den Nenner der Flurstücknummer';
  COMMENT ON COLUMN ax_historischesflurstueckalb.flurstueckskennzeichen    IS '"Flurstückskennzeichen" ist ein von der Katasterbehörde zur eindeutigen Bezeichnung des Flurstücks vergebenes Ordnungsmerkmal.
Die Attributart setzt sich aus den nachfolgenden expliziten Attributarten in der angegebenen Reihenfolge zusammen:
 1.  Land (2 Stellen)
 2.  Gemarkungsnummer (4 Stellen)
 3.  Flurnummer (3 Stellen)
 4.  Flurstücksnummer
 4.1 Zähler (5 Stellen)
 4.2 Nenner (4 Stellen)
 5.  Flurstücksfolge (2 Stellen)
Die Elemente sind rechtsbündig zu belegen, fehlende Stellen sind mit führenden Nullen zu belegen.
Da die Flurnummer und die Flurstücksfolge optional sind, sind aufgrund der bundeseinheitlichen Definition im Flurstückskennzeichen die entsprechenden Stellen, sofern sie nicht belegt sind, durch Unterstrich "_" ersetzt.
Gleiches gilt für Flurstücksnummern ohne Nenner, hier ist der fehlende Nenner im Flurstückskennzeichen durch Unterstriche zu ersetzen.';
  COMMENT ON COLUMN ax_historischesflurstueckalb.amtlicheflaeche           IS 'AFL "Amtliche Fläche" ist der im Liegenschaftskataster festgelegte Flächeninhalt des Flurstücks in [qm]. Flurstücksflächen kleiner 0,5 qm können mit bis zu zwei Nachkommastellen geführt werden, ansonsten ohne Nachkommastellen.';
  COMMENT ON COLUMN ax_historischesflurstueckalb.abweichenderrechtszustand IS 'ARZ "Abweichender Rechtszustand" ist ein Hinweis darauf, dass außerhalb des Grundbuches in einem durch Gesetz geregelten Verfahren der Bodenordnung (siehe Objektart "Bau-, Raum- oder Bodenordnungsrecht", AA "Art der Festlegung", Werte 1750, 1770, 2100 bis 2340) ein neuer Rechtszustand eingetreten ist und das amtliche Verzeichnis der jeweiligen ausführenden Stelle maßgebend ist.';
  COMMENT ON COLUMN ax_historischesflurstueckalb.zweifelhafterFlurstuecksnachweis IS 'ZFM "Zweifelhafter Flurstücksnachweis" ist eine Kennzeichnung eines Flurstücks, dessen Angaben nicht zweifelsfrei berichtigt werden können.';
  COMMENT ON COLUMN ax_historischesflurstueckalb.rechtsbehelfsverfahren    IS 'RBV "Rechtsbehelfsverfahren" ist der Hinweis darauf, dass bei dem Flurstück ein laufendes Rechtsbehelfsverfahren anhängig ist.';
  COMMENT ON COLUMN ax_historischesflurstueckalb.zeitpunktderentstehung    IS 'ZDE "Zeitpunkt der Entstehung" ist der Zeitpunkt, zu dem das Flurstück fachlich entstanden ist.';
  COMMENT ON COLUMN ax_historischesflurstueckalb.gemeinde                  IS 'Gemeindekennzeichen zur Zuordnung der Flustücksdaten zu einer Gemeinde.';

  COMMENT ON INDEX idx_histfsalb_vor IS 'Suchen nach Vorgänger-Flurstück';
  COMMENT ON INDEX idx_histfsalb_vor IS 'Suchen nach Nachfolger-Flurstück';


-- Variante B: "Vollhistorie" (statt ax_historischesflurstueckalb)
-- H i s t o r i s c h e s   F l u r s t ü c k  O h n e   R a u m b e z u g
-- ------------------------------------------------------------------------
-- Objektart: AX_HistorischesFlurstueckOhneRaumbezug Kennung: 17003
CREATE TABLE ax_historischesflurstueckohneraumbezug (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  name character varying[],

  -- GID: AX_Flurstueck_Kerndaten
  -- 'Flurstück_Kerndaten' enthält Eigenschaften des Flurstücks, die auch für andere Flurstücksobjektarten gelten (z.B. Historisches Flurstück).
  land character varying, --
  gemarkungsnummer character varying,
  flurnummer integer,
  zaehler integer,
  nenner integer,
  -- daraus abgeleitet:
  flurstueckskennzeichen character(20), -- Inhalt rechts mit __ auf 20 aufgefüllt
  amtlicheflaeche double precision, -- AFL
  abweichenderrechtszustand character varying, -- ARZ
  zweifelhafterFlurstuecksnachweis character varying, -- ZFM
  rechtsbehelfsverfahren integer, -- RBV
  zeitpunktderentstehung character varying, -- ZDE  Inhalt jjjj-mm-tt  besser Format date ?
  gemeinde character varying,
  -- GID: ENDE AX_Flurstueck_Kerndaten

  nachfolgerflurstueckskennzeichen character varying[],
  vorgaengerflurstueckskennzeichen character varying[],
  -- Beziehungen:
  gehoertanteiligzu character varying[], --> ax_historischesflurstueckohneraumbezug
  weistauf character varying[], --> ax_lagebezeichnungmithausnummer
  zeigtauf character varying[], --> ax_lagebezeichnungohnehausnummer
  istgebucht character varying, --> ax_buchungsstelle
  CONSTRAINT ax_historischesflurstueckohneraumbezug_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_historischesflurstueckohneraumbezug','dummy',:alkis_epsg,'POINT',2);
CREATE INDEX ax_hist_fs_ohne_kennz ON ax_historischesflurstueckohneraumbezug USING btree (flurstueckskennzeichen);
COMMENT ON INDEX ax_hist_fs_ohne_kennz IS 'Suche nach Flurstückskennzeichen';

CREATE INDEX idx_histfsor_vor  ON ax_historischesflurstueckohneraumbezug USING btree (vorgaengerflurstueckskennzeichen);
CREATE INDEX idx_histfsor_nach ON ax_historischesflurstueckohneraumbezug USING btree (vorgaengerflurstueckskennzeichen);

CREATE INDEX ax_hist_gaz ON ax_historischesflurstueckohneraumbezug  USING gin   (gehoertanteiligzu);
CREATE INDEX ax_hist_ig  ON ax_historischesflurstueckohneraumbezug  USING btree (istgebucht);
CREATE INDEX ax_hist_wa  ON ax_historischesflurstueckohneraumbezug  USING gin   (weistauf);
CREATE INDEX ax_hist_za  ON ax_historischesflurstueckohneraumbezug  USING gin   (zeigtauf);

COMMENT ON TABLE  ax_historischesflurstueckohneraumbezug        IS 'Angaben zur Historie: (NREO) "Historisches Flurstück ohne Raumbezug" ist ein nicht mehr aktuelles Flurstück, das schon im ALB historisch geworden ist, nach ALKIS migriert und im Rahmen der Vollhistorie geführt wird.';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.gml_id IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.flurnummer                IS 'FLN "Flurnummer" ist die von der Katasterbehörde zur eindeutigen Bezeichnung vergebene Nummer einer Flur, die eine Gruppe von zusammenhängenden Flurstücken innerhalb einer Gemarkung umfasst.';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.zaehler                   IS 'ZAE  Dieses Attribut enthält den Zähler der Flurstücknummer';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.nenner                    IS 'NEN  Dieses Attribut enthält den Nenner der Flurstücknummer';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.flurstueckskennzeichen    IS '"Flurstückskennzeichen" ist ein von der Katasterbehörde zur eindeutigen Bezeichnung des Flurstücks vergebenes Ordnungsmerkmal.
Die Attributart setzt sich aus den nachfolgenden expliziten Attributarten in der angegebenen Reihenfolge zusammen:
 1.  Land (2 Stellen)
 2.  Gemarkungsnummer (4 Stellen)
 3.  Flurnummer (3 Stellen)
 4.  Flurstücksnummer
 4.1 Zähler (5 Stellen)
 4.2 Nenner (4 Stellen)
 5.  Flurstücksfolge (2 Stellen)
Die Elemente sind rechtsbündig zu belegen, fehlende Stellen sind mit führenden Nullen zu belegen.
Da die Flurnummer und die Flurstücksfolge optional sind, sind aufgrund der bundeseinheitlichen Definition im Flurstückskennzeichen die entsprechenden Stellen, sofern sie nicht belegt sind, durch Unterstrich "_" ersetzt.
Gleiches gilt für Flurstücksnummern ohne Nenner, hier ist der fehlende Nenner im Flurstückskennzeichen durch Unterstriche zu ersetzen.';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.amtlicheflaeche           IS 'AFL "Amtliche Fläche" ist der im Liegenschaftskataster festgelegte Flächeninhalt des Flurstücks in [qm]. Flurstücksflächen kleiner 0,5 qm können mit bis zu zwei Nachkommastellen geführt werden, ansonsten ohne Nachkommastellen.';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.abweichenderrechtszustand IS 'ARZ "Abweichender Rechtszustand" ist ein Hinweis darauf, dass außerhalb des Grundbuches in einem durch Gesetz geregelten Verfahren der Bodenordnung (siehe Objektart "Bau-, Raum- oder Bodenordnungsrecht", AA "Art der Festlegung", Werte 1750, 1770, 2100 bis 2340) ein neuer Rechtszustand eingetreten ist und das amtliche Verzeichnis der jeweiligen ausführenden Stelle maßgebend ist.';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.zweifelhafterFlurstuecksnachweis IS 'ZFM "Zweifelhafter Flurstücksnachweis" ist eine Kennzeichnung eines Flurstücks, dessen Angaben nicht zweifelsfrei berichtigt werden können.';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.rechtsbehelfsverfahren    IS 'RBV "Rechtsbehelfsverfahren" ist der Hinweis darauf, dass bei dem Flurstück ein laufendes Rechtsbehelfsverfahren anhängig ist.';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.zeitpunktderentstehung    IS 'ZDE "Zeitpunkt der Entstehung" ist der Zeitpunkt, zu dem das Flurstück fachlich entstanden ist.';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.gemeinde                  IS 'Gemeindekennzeichen zur Zuordnung der Flustücksdaten zu einer Gemeinde.';
--MMENT ON COLUMN ax_historischesflurstueckohneraumbezug.anlass                    IS '?';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.name                      IS 'Array mit Fortführungsjahr und -Nummer';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.nachfolgerflurstueckskennzeichen
 IS '"Nachfolger-Flurstückskennzeichen" ist die Bezeichnung der Flurstücke, die dem Objekt "Historisches Flurstück ohne Raumbezug" direkt nachfolgen.
Array mit Kennzeichen im Format der Spalte "flurstueckskennzeichen"';

COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.vorgaengerflurstueckskennzeichen
  IS '"Vorgänger-Flurstückskennzeichen" ist die Bezeichnung der Flurstücke, die dem Objekt "Historisches Flurstück ohne Raumbezugs" direkt vorangehen.
Array mit Kennzeichen im Format der Spalte "flurstueckskennzeichen"';

COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.gehoertanteiligzu IS '-> Beziehung zu ax_historischesflurstueckohneraumbezug (0..*): ''Flurstück ohne Raumbezug'' gehört anteilig zu ''Flurstück ohne Raumbezug''. Die Relationsart kommt nur vor bei Flurstücken, die eine Relation zu einer Buchungsstelle mit einer der Buchungsarten Anliegerweg, Anliegergraben oder Anliegerwasserlauf aufweist.';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.weistauf   IS '-> Beziehung zu ax_lagebezeichnungmithausnummer (0..*): ''Flurstück ohne Raumbezug'' weist auf ''Lagebezeichnung mit Hausnummer''.';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.zeigtauf   IS '-> Beziehung zu ax_lagebezeichnungohnehausnummer (0..*): ''Flurstück ohne Raumbezug'' zeigt auf ''Lagebezeichnung ohne Hausnummer''.';
COMMENT ON COLUMN ax_historischesflurstueckohneraumbezug.istgebucht IS '-> Beziehung zu ax_buchungsstelle (0..1): Ein (oder mehrere) Flurstück(e) ist (sind) unter einer Buchungsstelle gebucht.';


-- *** ############################################################
-- *** Objektbereich: Eigentümer
-- *** ############################################################

-- ** Objektartengruppe: Personen- und Bestandsdaten
--   ===================================================================

-- P e r s o n
-- ----------------------------------------------
-- Objektart: AX_Person Kennung: 21001
CREATE TABLE ax_person (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  nachnameoderfirma character varying,
  anrede integer,
  vorname character varying,
  geburtsname character varying,
  geburtsdatum character varying,
  namensbestandteil character varying,
  akademischergrad character varying,
  -- Beziehungen:
  hat character varying[], -- -> ax_anschrift
--weistauf character varying[], -- <- ax_namensnummer
  wirdvertretenvon character varying[], -- -> ax_vertretung
  gehoertzu character varying[], -- -> ax_personengruppe
--uebtaus character varying[], -- <- ax_vertretung
--besitzt character varying[], -- <- ax_gebaeude
--zeigtauf character varying, -- <- ax_person
--benennt character varying[], -- <- ax_verwaltung
  CONSTRAINT ax_person_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_person','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX id_ax_person_gml ON ax_person USING btree (gml_id, beginnt);
CREATE INDEX        ax_person_gml16  ON ax_person USING btree (substring(gml_id,1,16)); -- ALKIS-Relation

CREATE INDEX ax_person_hat  ON ax_person  USING gin  (hat);
--EATE INDEX ax_person_wa   ON ax_person  USING gin  (weistauf);
CREATE INDEX ax_person_wvv  ON ax_person  USING gin  (wirdvertretenvon);
CREATE INDEX ax_person_gz   ON ax_person  USING gin  (gehoertzu);
--EATE INDEX ax_person_ua   ON ax_person  USING gin  (uebtaus);
--EATE INDEX ax_person_bes  ON ax_person  USING gin  (besitzt);
--EATE INDEX ax_person_za   ON ax_person  USING btree (zeigtauf);
--EATE INDEX ax_person_ben  ON ax_person  USING gin  (benennt);

COMMENT ON TABLE  ax_person           IS 'Personen- und Bestandsdaten: (NREO) "Person" ist eine natürliche oder juristische Person und kann z.B. in den Rollen Eigentümer, Erwerber, Verwalter oder Vertreter in Katasterangelegenheiten geführt werden.';
COMMENT ON COLUMN ax_person.gml_id    IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_person.namensbestandteil IS 'enthält z.B. Titel wie "Baron"';
COMMENT ON COLUMN ax_person.anrede    IS '"Anrede" ist die Anrede der Person. Diese Attributart ist optional, da Körperschaften und juristischen Person auch ohne Anrede angeschrieben werden können.';
COMMENT ON COLUMN ax_person.akademischergrad IS '"Akademischer Grad" ist der akademische Grad der Person (z.B. Dipl.-Ing., Dr., Prof. Dr.)';

COMMENT ON COLUMN ax_person.hat       IS '-> Beziehung zu ax_anschrift (0..*): Die ''Person'' hat ''Anschrift''.';
--COMMENT ON COLUMN ax_person.weistauf  IS '<- Beziehung zu ax_namensnummer (0..*): Durch die Relation ''Person'' weist auf ''Namensnummer'' wird ausgedrückt, dass die Person als Eigentümer, Erbbauberechtigter oder künftiger Erwerber unter der Namensnummer eines Buchungsblattes eingetragen ist.
--Es handelt sich um die inverse Relationsrichtung.';
COMMENT ON COLUMN ax_person.wirdvertretenvon IS '-> Beziehung zu ax_vertretung (0..*): Die ''Person'' wird von der ''Vertretung'' in Katasterangelegenheiten vertreten.';
COMMENT ON COLUMN ax_person.gehoertzu IS '-> Beziehung zu ax_personengruppe (0..*): ''Person'' gehört zu ''Personengruppe''.';
--COMMENT ON COLUMN ax_person.uebtaus   IS '<- Beziehung zu ax_vertretung (0..*): Die ''Person'' übt die ''Vertretung'' in Katasterangelegenheiten aus.
--Es handelt sich um die inverse Relationsrichtung.';
--COMMENT ON COLUMN ax_person.besitzt   IS '<- Beziehung zu ax_gebaeude (0..*):
--Es handelt sich um die inverse Relationsrichtung.';
--COMMENT ON COLUMN ax_person.zeigtauf  IS '-> Beziehung zu ax_person (0..1): Die ''Person'' zeigt auf eine ''Person'' mit abweichenden Eigenschaften derselben Person. Für ein und dieselbe Person wurden zwei Objekte ''Person'' mit unterschiedlichen Attributen (z.B. Nachnamen durch Heirat geändert) angelegt. Bei Verwendung der Vollhistorie mit Hilfe des Versionierungskonzeptes werden diese Eigenschaften in verschiedenen Versionen geführt.
--Diese Relation wird dann nicht verwendet.';
--COMMENT ON COLUMN ax_person.benennt   IS '<- Beziehung zu ax_verwaltung (0..*): Die Relation ''Person'' benennt ''Verwaltung'' weist der Verwaltung eine Person zu.
--Es handelt sich um die inverse Relationsrichtung.';


--AX_Personengruppe
-- Objektart: AX_Personengruppe Kennung: 21002
-- 'Personengruppe' ist die Zusammenfassung von Personen unter einem Ordnungsbegriff.
-- ** Tabelle bisher noch nicht generiert

-- CREATE INDEX ax_personengruppe_gml16 ON ax_personengruppe USING btree (substring(gml_id,1,16)); -- ALKIS-Relation


-- A n s c h r i f t
-- ----------------------------------------------
-- Objektart: AX_Anschrift Kennung: 21003
CREATE TABLE ax_anschrift (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  ort_post character varying,
  postleitzahlpostzustellung character varying,
  strasse character varying,
  hausnummer character varying,
  bestimmungsland character varying,
  postleitzahlpostfach character varying,
  postfach character varying,
  ortsteil character varying,
  weitereAdressen character varying[],
  telefon character varying,
  fax character varying,
  organisationname character varying,
  -- Beziehungen:
--beziehtsichauf character varying[], -- <- ax_dienststelle
--gehoertzu character varying[], -- <- ax_person
  CONSTRAINT ax_anschrift_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_anschrift','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_anschrift_gml  ON ax_anschrift  USING btree (gml_id, beginnt);
CREATE INDEX       ax_anschrift_gml16 ON ax_anschrift  USING btree (substring(gml_id,1,16)); -- ALKIS-Relation
--EATE        INDEX ax_anschrift_bsa  ON ax_anschrift  USING gin   (beziehtsichauf);
--EATE        INDEX ax_anschrift_gz   ON ax_anschrift  USING gin   (gehoertzu);

COMMENT ON TABLE  ax_anschrift        IS 'Personen- und Bestandsdaten: (NREO) "Anschrift" ist die postalische Adresse, verbunden mit weiteren Adressen aus dem Bereich elektronischer Kommunikationsmedien.';
COMMENT ON COLUMN ax_anschrift.gml_id IS 'Identifikator, global eindeutig';

--COMMENT ON COLUMN ax_anschrift.beziehtsichauf IS '<- Beziehung zu ax_dienststelle (0..*):
--Es handelt sich um die inverse Relationsrichtung.';
--COMMENT ON COLUMN ax_anschrift.gehoertzu      IS '<- Beziehung zu ax_person (0..*): Eine ''Anschrift'' gehört zu ''Person''.
--Es handelt sich um die inverse Relationsrichtung.';


-- V e r w a l t u n g
-- -------------------
-- Objektart: AX_Verwaltung Kennung: 21004
CREATE TABLE ax_verwaltung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  -- Beziehungen:
--beziehtsichauf character varying[], -- <- ax_buchungsstelle
  haengtan character varying, -- -> ax_person
  CONSTRAINT ax_verwaltung_pk PRIMARY KEY (ogc_fid)
);
SELECT AddGeometryColumn('ax_verwaltung','dummy',:alkis_epsg,'POINT',2);

COMMENT ON TABLE  ax_verwaltung  IS 'Personen- und Bestandsdaten: (NREO "Verwaltung") beschreibt die Grundlagen und die Befugnisse des Verwalters entsprechend dem Wohnungseigentumsgesetz (z.B. für Wohnungs-/Teileigentum).';

--COMMENT ON COLUMN ax_verwaltung.beziehtsichauf IS '<- Beziehung zu ax_buchungsstelle (1..*): Durch die Relation ''Verwaltung'' bezieht sich auf ''Buchungsstelle'' wird augedrückt, für welche Buchungsstellen die Verwaltung bestellt wurde.
--Es handelt sich um die inverse Relationsrichtung.';
COMMENT ON COLUMN ax_verwaltung.haengtan       IS '-> Beziehung zu ax_person (1): Durch die Relation ''Verwaltung'' hängt an ''Person'' wird die Verwaltung namentlich benannt.';

CREATE UNIQUE INDEX ax_verwaltung_gml  ON ax_verwaltung USING btree (gml_id, beginnt);
CREATE INDEX ax_verwaltung_gml16       ON ax_verwaltung USING btree (substring(gml_id,1,16)); -- ALKIS-Relation
CREATE INDEX ax_verwaltung_han         ON ax_verwaltung USING btree (haengtan);


-- V e r t r e t u n g
-- -------------------
-- Objektart: AX_Vertretung Kennung: 21005
CREATE TABLE ax_vertretung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  -- Beziehungen:
--vertritt character varying[], -- <- ax_person
  haengtan character varying, --> ax_person
  beziehtsichauf character varying[], --> ax_flurstueck
  CONSTRAINT ax_vertretung_pk PRIMARY KEY (ogc_fid)
);
SELECT AddGeometryColumn('ax_vertretung','dummy',:alkis_epsg,'POINT',2);

COMMENT ON TABLE  ax_vertretung IS 'Personen- und Bestandsdaten: (NREO) "Vertretung" gibt an, welche Person eine andere Person in Katasterangelegenheiten vertritt.';

--COMMENT ON COLUMN ax_vertretung.vertritt       IS '<- Beziehung zu ax_person (1..*): Die Relation ''Vertretung'' vertritt ''Person'' sagt aus, welche Person durch die Vertretung vertreten wird.
--Es handelt sich um die inverse Relationsrichtung.';
COMMENT ON COLUMN ax_vertretung.haengtan       IS '-> Beziehung zu ax_person (1): Die Relation ''Vertretung'' hängt an ''Person'' sagt aus, welche Person die Vertretung wahrnimmt.';
COMMENT ON COLUMN ax_vertretung.beziehtsichauf IS '-> Beziehung zu ax_flurstueck (0..*): Die Relation ''Vertretung'' bezieht sich auf ''Flurstück'' sagt aus, für welche Flurstücke die Vertretung wahrgenommen wird.';

CREATE INDEX ax_vertretung_han         ON ax_vertretung USING btree (haengtan);
CREATE INDEX ax_vertretung_bezauf      ON ax_vertretung USING gin   (beziehtsichauf);


-- N a m e n s n u m m e r
-- ----------------------------------------------
-- AX_Namensnummer Kennung: 21006
CREATE TABLE ax_namensnummer (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  laufendenummernachdin1421 character(16), -- 0000.00.00.00.00
  zaehler double precision, -- Anteil ..
  nenner double precision, --  .. als Bruch
  eigentuemerart integer,
  nummer character varying, -- immer leer ?
  artderrechtsgemeinschaft integer, -- Schlüssel
  beschriebderrechtsgemeinschaft character varying,
  -- Beziehungen:
  bestehtausrechtsverhaeltnissenzu character varying, -- -> ax_namensnummer
  istbestandteilvon character varying, -- -> ax_buchungsblatt
  hatvorgaenger character varying[], -- -> ax_namensnummer
  benennt character varying, -- -> ax_person
  CONSTRAINT ax_namensnummer_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_namensnummer','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_namensnummer_gml   ON ax_namensnummer  USING btree (gml_id, beginnt);
CREATE INDEX  ax_namensnummer_gml16       ON ax_namensnummer  USING btree (substring(gml_id,1,16)); -- ALKIS-Relation

CREATE        INDEX ax_namensnummer_barvz ON ax_namensnummer  USING btree (bestehtausrechtsverhaeltnissenzu);
CREATE        INDEX ax_namensnummer_ben   ON ax_namensnummer  USING btree (benennt);
CREATE        INDEX ax_namensnummer_hv    ON ax_namensnummer  USING gin   (hatvorgaenger);
CREATE        INDEX ax_namensnummer_ibv   ON ax_namensnummer  USING btree (istbestandteilvon);

COMMENT ON TABLE  ax_namensnummer        IS 'Personen- und Bestandsdaten: (NREO) "Namensnummer" ist die laufende Nummer der Eintragung, unter welcher der Eigentümer oder Erbbauberechtigte im Buchungsblatt geführt wird. Rechtsgemeinschaften werden auch unter AX_Namensnummer geführt.';
COMMENT ON COLUMN ax_namensnummer.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_namensnummer.bestehtausrechtsverhaeltnissenzu IS '-> Beziehung zu ax_namensnummer (0..1): Die Relation ''Namensnummer'' besteht aus Rechtsverhältnissen zu ''Namensnummer'' sagt aus, dass mehrere Namensnummern zu einer Rechtsgemeinschaft gehören können. Die Rechtsgemeinschaft selbst steht unter einer eigenen AX_Namensnummer, die zu allen Namensnummern der Rechtsgemeinschaft eine Relation besitzt.';
COMMENT ON COLUMN ax_namensnummer.istbestandteilvon                IS '-> Beziehung zu ax_buchungsblatt (1): Eine ''Namensnummer'' ist Teil von einem ''Buchungsblatt''.';
COMMENT ON COLUMN ax_namensnummer.hatvorgaenger                    IS '-> Beziehung zu ax_namensnummer (0..*): Die Relation ''Namensnummer'' hat Vorgänger ''Namensnummer'' gibt Auskunft darüber, aus welchen Namensnummern die aktuelle entstanden ist.';
COMMENT ON COLUMN ax_namensnummer.benennt                          IS '-> Beziehung zu ax_person (0..1): Durch die Relation ''Namensnummer'' benennt ''Person'' wird die Person zum Eigentümer, Erbbauberechtigten oder künftigen Erwerber.';


-- B u c h u n g s b l a t t
-- -------------------------
-- Objektart: AX_Buchungsblatt Kennung: 21007
CREATE TABLE ax_buchungsblatt (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  buchungsblattkennzeichen character varying,
  land character varying,
  bezirk character varying,
  buchungsblattnummermitbuchstabenerweiterung character varying,
  blattart character varying, -- bisher integer,
  art character varying,
  -- Beziehungen:
--bestehtaus character varying[], -- <- ax_buchungsstelle
  CONSTRAINT ax_buchungsblatt_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_buchungsblatt','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_buchungsblatt_gml  ON ax_buchungsblatt USING btree (gml_id, beginnt);
CREATE        INDEX ax_buchungsblatt_lbb  ON ax_buchungsblatt USING btree (land, bezirk, buchungsblattnummermitbuchstabenerweiterung);
--EATE        INDEX ax_buchungsblatt_bsa  ON ax_buchungsblatt USING gin   (bestehtaus);

COMMENT ON TABLE  ax_buchungsblatt        IS 'Personen- und Bestandsdaten: (NREO) "Buchungsblatt" enthält die Buchungen (Buchungsstellen und Namensnummern) des Grundbuchs und des Liegenschhaftskatasters (bei buchungsfreien Grundstücken).
Das Buchungsblatt für Buchungen im Liegenschaftskataster kann entweder ein Kataster-, Erwerber-, Pseudo- oder ein Fiktives Blatt sein.';
COMMENT ON COLUMN ax_buchungsblatt.gml_id IS 'Identifikator, global eindeutig';

--COMMENT ON COLUMN ax_buchungsblatt.bestehtaus IS '<- Beziehung zu ax_buchungsstelle (0..*): ''Buchungsblatt'' besteht aus ''Buchungsstelle''. Bei einem Buchungsblatt mit der Blattart ''Fiktives Blatt'' (Wert 5000) muss die Relation zu einer aufgeteilten Buchung (Wertearten 1101, 1102, 1401 bis 1403, 2201 bis 2205 und 2401 bis 2404) bestehen.
--Es handelt sich um die inverse Relationsrichtung.';


-- B u c h u n g s s t e l l e
-- -----------------------------
-- Objektart: AX_Buchungsstelle Kennung: 21008
CREATE TABLE ax_buchungsstelle (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  buchungsart integer,
  laufendenummer character varying,
  beschreibungdesumfangsderbuchung character(1),
  zaehler double precision,
  nenner double precision,
  nummerimaufteilungsplan character varying,
  beschreibungdessondereigentums character varying,
  buchungstext character varying,
  -- Beziehungen:
  istbestandteilvon character varying, -- -> ax_buchungsblatt
  durch character varying[], -- -> ax_buchungsstelle
  verweistauf character varying[], -- -> ax_flurstueck
--grundstueckbestehtaus character varying[], -- <- ax_flurstueck
  zu character varying[], -- -> ax_buchungsstelle
  an character varying[], -- -> ax_buchungsstelle
  hatvorgaenger character varying[], -- -> ax_buchungsstelle
  wirdverwaltetvon character varying, -- -> ax_verwaltung
  beziehtsichauf character varying[], -- -> ax_buchungsblatt
  CONSTRAINT ax_buchungsstelle_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_buchungsstelle','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_buchungsstelle_gml ON ax_buchungsstelle USING btree (gml_id, beginnt);
CREATE INDEX ax_buchungsstelle_gml16  ON ax_buchungsstelle  USING btree (substring(gml_id,1,16)); -- ALKIS-Relation

CREATE INDEX ax_buchungsstelle_an     ON ax_buchungsstelle  USING gin  (an);
CREATE INDEX ax_buchungsstelle_bsa    ON ax_buchungsstelle  USING gin  (beziehtsichauf);
CREATE INDEX ax_buchungsstelle_durch  ON ax_buchungsstelle  USING gin  (durch);
--EATE INDEX ax_buchungsstelle_gba    ON ax_buchungsstelle  USING gin  (grundstueckbestehtaus);
CREATE INDEX ax_buchungsstelle_hv     ON ax_buchungsstelle  USING gin  (hatvorgaenger);
CREATE INDEX ax_buchungsstelle_ibv    ON ax_buchungsstelle  USING btree (istbestandteilvon);
CREATE INDEX ax_buchungsstelle_vwa    ON ax_buchungsstelle  USING gin  (verweistauf);
CREATE INDEX ax_buchungsstelle_wvv    ON ax_buchungsstelle  USING btree (wirdverwaltetvon);
CREATE INDEX ax_buchungsstelle_zu     ON ax_buchungsstelle  USING gin  (zu);

COMMENT ON TABLE  ax_buchungsstelle        IS 'Personen- und Bestandsdaten: (NREO) "Buchungsstelle" ist die unter einer laufenden Nummer im Verzeichnis des Buchungsblattes eingetragene Buchung.';
COMMENT ON COLUMN ax_buchungsstelle.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_buchungsstelle.istbestandteilvon IS '-> Beziehung zu ax_buchungsblatt (1): ''Buchungsstelle'' ist Teil von ''Buchungsblatt''. Bei ''Buchungsart'' mit einer der Wertearten für aufgeteilte Buchungen (Wertearten 1101, 1102, 1401 bis 1403, 2201 bis 2205 und 2401 bis 2404) muss die Relation zu einem ''Buchungsblatt'' und der ''Blattart'' mit der Werteart ''Fiktives Blatt'' bestehen.';
COMMENT ON COLUMN ax_buchungsstelle.durch IS '-> Beziehung zu ax_buchungsstelle (0..*): Eine ''Buchungsstelle'' verweist mit ''durch'' auf eine andere ''Buchungsstelle'' auf einem anderen Buchungsblatt (herrschend). Die Buchungsstelle ist belastet durch ein Recht, dass ''durch'' die andere Buchungsstelle an ihr ausgeübt wird.';
COMMENT ON COLUMN ax_buchungsstelle.verweistauf IS '-> Beziehung zu ax_flurstueck (0..*): ''Buchungsstelle'' verweist auf ''Flurstück''.';
--COMMENT ON COLUMN ax_buchungsstelle.grundstueckbestehtaus IS '<- Beziehung zu ax_flurstueck (0..*): Diese Relationsart legt fest, welche Flurstücke ein Grundstück bilden. Nur bei der ''Buchungsart'' mit den Wertearten 1100, 1101 und 1102 muss die Relationsart vorhanden sein, sofern nicht ein Objekt AX_HistorischesFlurstueckOhneRaumbezug über die Relationsart ''istGebucht'' auf die Buchungsstelle verweist.
--Es handelt sich um die inverse Relationsrichtung.';
COMMENT ON COLUMN ax_buchungsstelle.zu IS '-> Beziehung zu ax_buchungsstelle (0..*): Eine ''Buchungsstelle'' verweist mit ''zu'' auf eine andere ''Buchungsstelle'' des gleichen Buchungsblattes (herrschend).';
COMMENT ON COLUMN ax_buchungsstelle.an IS '-> Beziehung zu ax_buchungsstelle (0..*): Eine ''Buchungsstelle'' verweist mit ''an'' auf eine andere ''Buchungsstelle'' auf einem anderen Buchungsblatt. Die Buchungsstelle kann ein Recht (z.B. Erbbaurecht) oder einen Miteigentumsanteil ''an'' der anderen Buchungsstelle haben Die Relation zeigt stets vom begünstigten Recht zur belasteten Buchung (z.B. Erbbaurecht hat ein Recht ''an'' einem Grundstück).';

COMMENT ON COLUMN ax_buchungsstelle.hatvorgaenger IS '-> Beziehung zu ax_buchungsstelle (0..*): Die Relation ''Buchungsstelle'' hat Vorgänger ''Buchungsstelle'' gibt Auskunft darüber, aus welchen Buchungsstellen die aktuelle Buchungsstelle entstanden ist.';
COMMENT ON COLUMN ax_buchungsstelle.wirdverwaltetvon IS '-> Beziehung zu ax_verwaltung (0..1): Die ''Buchungsstelle'' wird verwaltet von ''Verwaltung''.';
COMMENT ON COLUMN ax_buchungsstelle.beziehtsichauf IS '-> Beziehung zu ax_buchungsblatt (0..*): ''Buchungsstelle'' bezieht sich auf ''Buchungsblatt''.';


--*** ############################################################
--*** Objektbereich: Gebäude
--*** ############################################################

--** Objektartengruppe: Angaben zum Gebäude
--   ===================================================================

-- G e b ä u d e
-- ---------------
-- Objektart: AX_Gebaeude Kennung: 31001
CREATE TABLE ax_gebaeude (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  gebaeudefunktion integer, -- Werte siehe Schlüsseltabelle
  weiteregebaeudefunktion integer[],
  name character varying[],
  bauweise integer,
  anzahlderoberirdischengeschosse integer,
  anzahlderunterirdischengeschosse integer,
  hochhaus character varying, -- "true"/"false", meist leer
  objekthoehe double precision,
  dachform integer,
  zustand integer,
  geschossflaeche integer,
  grundflaeche integer,
  umbauterraum integer,
  baujahr integer,
  lagezurerdoberflaeche integer,
  dachart character varying,
  dachgeschossausbau integer,
  qualitaetsangaben character varying,
  ax_datenerhebung integer,
  description integer,
  art character varying,
  individualname character varying,
  -- Beziehungen:
  gehoertzu character varying, -- -> ax_gebaeude
  hat character varying, -- -> ax_lagebezeichnungmitpseudonummer
  gehoert character varying[], -- -> ax_person
  zeigtauf character varying[], -- -> ax_lagebezeichnungmithausnummer
--haengtzusammenmit character varying, -- <- ax_gebaeude
  CONSTRAINT ax_gebaeude_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_gebaeude','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/MULTIPOLYGON

CREATE INDEX ax_gebaeude_geom_idx   ON ax_gebaeude USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_gebaeude_gml ON ax_gebaeude USING btree (gml_id, beginnt);
CREATE INDEX ax_gebaeude_gml16      ON ax_gebaeude USING btree (substring(gml_id,1,16)); -- ALKIS-Relation

CREATE INDEX ax_gebaeude_geh  ON ax_gebaeude USING gin   (gehoert);
CREATE INDEX ax_gebaeude_gz   ON ax_gebaeude USING btree (gehoertzu);
CREATE INDEX ax_gebaeude_hat  ON ax_gebaeude USING btree (hat);
--EATE INDEX ax_gebaeude_hzm  ON ax_gebaeude USING btree (haengtzusammenmit);
CREATE INDEX ax_gebaeude_za   ON ax_gebaeude USING gin   (zeigtauf);

COMMENT ON TABLE  ax_gebaeude                    IS 'Angaben zum Gebäude: (REO) "Gebäude" ist ein dauerhaft errichtetes Bauwerk, dessen Nachweis wegen seiner Bedeutung als Liegenschaft erforderlich ist sowie dem Zweck der Basisinformation des Liegenschaftskatasters dient.';
COMMENT ON COLUMN ax_gebaeude.gml_id             IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_gebaeude.gebaeudefunktion   IS 'GFK "Gebäudefunktion" ist die zum Zeitpunkt der Erhebung vorherrschend funktionale Bedeutung des Gebäudes (Dominanzprinzip). Werte siehe ax_gebaeude_funktion';
COMMENT ON COLUMN ax_gebaeude.weiteregebaeudefunktion IS 'WGF "Weitere Gebäudefunktion" sind weitere Funktionen, die ein Gebäude neben der dominierenden Gebäudefunktion hat.';
COMMENT ON COLUMN ax_gebaeude.name               IS 'NAM "Name" ist der Eigenname oder die Bezeichnung des Gebäudes.';
COMMENT ON COLUMN ax_gebaeude.bauweise           IS 'BAW "Bauweise" ist die Beschreibung der Art der Bauweise. Werte siehe ax_gebaeude_bauweise';
COMMENT ON COLUMN ax_gebaeude.anzahlderoberirdischengeschosse  IS 'AOG "Anzahl der oberirdischen Geschosse" ist die Anzahl der oberirdischen Geschosse des Gebäudes.';
COMMENT ON COLUMN ax_gebaeude.anzahlderunterirdischengeschosse IS 'AUG "Anzahl der unterirdischen Geschosse" ist die Anzahl der unterirdischen Geschosse des Gebäudes.';
COMMENT ON COLUMN ax_gebaeude.hochhaus           IS 'HOH "Hochhaus" ist ein Gebäude, das nach Gebäudehöhe und Ausprägung als Hochhaus zu bezeichnen ist. Für Gebäude im Geschossbau gilt dieses i.d.R. ab 8 oberirdischen Geschossen, für andere Gebäude ab einer Gebäudehöhe von 22 m. Abweichungen hiervon können sich durch die Festlegungen in den länderspezifischen Bauordnungen ergeben.';
COMMENT ON COLUMN ax_gebaeude.objekthoehe        IS 'HHO "Objekthöhe" ist die Höhendifferenz in [m] zwischen dem höchsten Punkt der Dachkonstruktion und der festgelegten Geländeoberfläche des Gebäudes.';
COMMENT ON COLUMN ax_gebaeude.dachform           IS 'DAF "Dachform" beschreibt die charakteristische Form des Daches. Werte siehe ax_gebaeude_dachform';
COMMENT ON COLUMN ax_gebaeude.zustand            IS 'ZUS "Zustand" beschreibt die Beschaffenheit oder die Betriebsbereitschaft von "Gebäude". Diese Attributart wird nur dann optional geführt, wenn der Zustand des Gebäudes vom nutzungsfähigen Zustand abweicht. Werte siehe ax_gebaeude_zustand';
COMMENT ON COLUMN ax_gebaeude.geschossflaeche    IS 'GFL "Geschossfläche" ist die Gebäudegeschossfläche in [qm].';
COMMENT ON COLUMN ax_gebaeude.grundflaeche       IS 'GRF "Grundfläche" ist die Gebäudegrundfläche in [qm].';
COMMENT ON COLUMN ax_gebaeude.umbauterraum       IS 'URA "Umbauter Raum" ist der umbaute Raum [Kubikmeter] des Gebäudes.';
COMMENT ON COLUMN ax_gebaeude.baujahr            IS 'BJA "Baujahr" ist das Jahr der Fertigstellung oder der baulichen Veränderung des Gebäudes.';
COMMENT ON COLUMN ax_gebaeude.lagezurerdoberflaeche IS 'OFL "Lage zur Erdoberfläche" ist die Angabe der relativen Lage des Gebäudes zur Erdoberfläche. Diese Attributart wird nur bei nicht ebenerdigen Gebäuden geführt. 1200=Unter der Erdoberfläche, 1400=Aufgeständert';
COMMENT ON COLUMN ax_gebaeude.dachart            IS 'DAA "Dachart" gibt die Art der Dacheindeckung (z.B. Reetdach) an.';
COMMENT ON COLUMN ax_gebaeude.dachgeschossausbau IS 'DGA "Dachgeschossausbau" ist ein Hinweis auf den Ausbau bzw. die Ausbaufähigkeit des Dachgeschosses.';
COMMENT ON COLUMN ax_gebaeude.qualitaetsangaben  IS 'QAG Angaben zur Herkunft der Informationen (Erhebungsstelle). Die Information ist konform zu den Vorgaben aus ISO 19115 zu repräsentieren.';

COMMENT ON COLUMN ax_gebaeude.gehoertzu         IS '-> Beziehung zu ax_gebaeude (0..1): ''Gebäude'' gehört zu ''Gebäude'', wenn die Gebäude baulich zusammen gehören und im Gegensatz zum Bauteil eine gleichrangige Bedeutung haben.';
COMMENT ON COLUMN ax_gebaeude.hat               IS '-> Beziehung zu ax_lagebezeichnungmitpseudonummer (0..1): ''Gebäude'' hat ''Lagebezeichnung mit Pseudonummer''.';
COMMENT ON COLUMN ax_gebaeude.gehoert           IS '-> Beziehung zu ax_person (0..*): ''Gebäude'' gehört ''Person''. Die Relation kommt nur vor, wenn unabhängig von Eintragungen im Grundbuch (''Buchungsstelle'' mit der Attributart ''Buchungsart'') für das Gebäude ein Eigentum nach BGB begründet ist.';
COMMENT ON COLUMN ax_gebaeude.zeigtauf          IS '-> Beziehung zu ax_lagebezeichnungmithausnummer (0..*): ''Gebäude'' zeigt auf ''Lagebezeichnung mit Hausnummer''.';
--COMMENT ON COLUMN ax_gebaeude.haengtzusammenmit IS '<- Beziehung zu ax_gebaeude (0..1):
--Es handelt sich um die inverse Relationsrichtung.';


-- B a u t e i l
-- -------------
-- Objektart: AX_Bauteil Kennung: 31002
CREATE TABLE ax_bauteil (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  bauart integer,
  dachform integer,
  anzahlderoberirdischengeschosse integer,
  anzahlderunterirdischengeschosse integer,
  lagezurerdoberflaeche integer,
  CONSTRAINT ax_bauteil_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_bauteil','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_bauteil_geom_idx ON ax_bauteil USING gist (wkb_geometry);

CREATE UNIQUE INDEX ax_bauteil_gml ON ax_bauteil USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_bauteil        IS 'Angaben zum Gebäude: (REO) "Bauteil" ist ein charakteristisches Merkmal eines Gebäudes mit gegenüber dem jeweiligen Objekt "Gebäude" abweichenden bzw. besonderen Eigenschaften.';
COMMENT ON COLUMN ax_bauteil.gml_id IS 'Identifikator, global eindeutig';


-- B e s o n d e r e   G e b ä u d e l i n i e
-- ----------------------------------------------
-- Objektart: AX_BesondereGebaeudelinie Kennung: 31003
CREATE TABLE ax_besonderegebaeudelinie (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  beschaffenheit integer[],
  anlass character varying,
  CONSTRAINT ax_besonderegebaeudelinie_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_besonderegebaeudelinie','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/MULTILINESTRING

CREATE INDEX ax_besonderegebaeudelinie_geom_idx ON ax_besonderegebaeudelinie USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_besonderegebaeudelinie_gml ON ax_besonderegebaeudelinie USING btree (gml_id, beginnt);

CREATE INDEX ax_besonderegebaeudelinie_bes  ON ax_besonderegebaeudelinie  USING gin  (beschaffenheit);

COMMENT ON TABLE ax_besonderegebaeudelinie IS 'Angaben zum Gebäude: (REO) "Besondere Gebäudelinie" ist der Teil der Geometrie des Objekts "Gebäude" oder des Objekts "Bauteil", der besondere Eigenschaften besitzt.';
COMMENT ON COLUMN ax_besonderegebaeudelinie.gml_id IS 'Identifikator, global eindeutig';


-- F i r s t l i n i e
-- -----------------------------------------------------
-- Objektart: AX_Firstlinie Kennung: 31004
CREATE TABLE ax_firstlinie (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art character varying,
  uri character varying, -- wirklich?
  CONSTRAINT ax_firstlinie_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_firstlinie','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/MULTILINESTRING

CREATE INDEX ax_firstlinie_geom_idx ON ax_firstlinie USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_firstlinie_gml ON ax_firstlinie USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_firstlinie        IS 'Angaben zum Gebäude: (REO) "Firstlinie" kennzeichnet den Verlauf des Dachfirstes eines Gebäudes.';
COMMENT ON COLUMN ax_firstlinie.gml_id IS 'Identifikator, global eindeutig';


-- B e s o n d e r e r   G e b ä u d e p u n k t
-- -----------------------------------------------
-- Objektart: AX_BesondererGebaeudepunkt Kennung: 31005
CREATE TABLE ax_besonderergebaeudepunkt (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  land character varying,
  stelle character varying,
  punktkennung character varying,
  art character varying,
  name character varying[],
  sonstigeeigenschaft character varying[],
  CONSTRAINT ax_besonderergebaeudepunkt_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_besonderergebaeudepunkt','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_besonderergebaeudepunkt_gml ON ax_besonderergebaeudepunkt USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_besonderergebaeudepunkt        IS 'Angaben zum Gebäude: (ZUSO) "Besonderer Gebäudepunkt" ist ein Punkt eines "Gebäudes" oder eines "Bauteils".';
COMMENT ON COLUMN ax_besonderergebaeudepunkt.gml_id IS 'Identifikator, global eindeutig';


--*** ############################################################
--*** Objektbereich: Tatsächliche Nutzung (AX_TatsaechlicheNutzung)
--*** ############################################################
-- Objektart: AX_TatsaechlicheNutzung Kennung: 40001
-- abstrakte Oberklasse für alle tatsächlichen Nutzungen

-- Gemeinsame Attribute:
--   DLU datumDerLetztenUeberpruefung DateTime
--   DAQ qualitaetsangaben

--** Objektartengruppe: Siedlung (in Objektbereich: Tatsächliche Nutzung)
--   ====================================================================

-- W o h n b a u f l ä c h e
-- ----------------------------------------------
-- Objektart: AX_Wohnbauflaeche Kennung: 41001
CREATE TABLE ax_wohnbauflaeche (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artderbebauung integer,
  zustand integer,
  name character varying,
  CONSTRAINT ax_wohnbauflaeche_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_wohnbauflaeche','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_wohnbauflaeche_geom_idx ON ax_wohnbauflaeche USING gist (wkb_geometry);

CREATE UNIQUE INDEX ax_wohnbauflaeche_gml ON ax_wohnbauflaeche USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_wohnbauflaeche                 IS 'Tatsächliche Nutzung / Siedlung: (REO) "Wohnbaufläche" ist eine baulich geprägte Fläche einschließlich der mit ihr im Zusammenhang stehenden Freiflächen (z.B. Vorgärten, Ziergärten, Zufahrten, Stellplätze und Hofraumflächen), die ausschließlich oder vorwiegend dem Wohnen dient.';
COMMENT ON COLUMN ax_wohnbauflaeche.gml_id          IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_wohnbauflaeche.artderbebauung  IS 'BEB "Art der Bebauung" differenziert nach offener und geschlossener Bauweise aus topographischer Sicht und nicht nach gesetzlichen Vorgaben (z.B. BauGB).';
COMMENT ON COLUMN ax_wohnbauflaeche.zustand         IS 'ZUS "Zustand" beschreibt, ob "Wohnbaufläche" ungenutzt ist oder ob eine Fläche als Wohnbaufläche genutzt werden soll.';
COMMENT ON COLUMN ax_wohnbauflaeche.name            IS 'NAM "Name" ist der Eigenname von "Wohnbaufläche" insbesondere bei Objekten außerhalb von Ortslagen.';


-- Objektart: I n d u s t r i e -   u n d   G e w e r b e f l ä c h e
-- --------------------------------------------------------------------
-- Objektart: AX_IndustrieUndGewerbeflaeche Kennung: 41002
CREATE TABLE ax_industrieundgewerbeflaeche (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  name character varying,
  zustand integer,
  foerdergut integer,
  primaerenergie integer,
  lagergut integer,
  CONSTRAINT ax_industrieundgewerbeflaeche_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_industrieundgewerbeflaeche','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/POINT

CREATE INDEX ax_industrieundgewerbeflaeche_geom_idx ON ax_industrieundgewerbeflaeche USING gist (wkb_geometry);

CREATE UNIQUE INDEX ax_industrieundgewerbeflaeche_gml ON ax_industrieundgewerbeflaeche USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_industrieundgewerbeflaeche            IS 'Tatsächliche Nutzung / Siedlung: (REO) "Industrie- und Gewerbefläche" ist eine Fläche, die vorwiegend industriellen oder gewerblichen Zwecken dient.';
COMMENT ON COLUMN ax_industrieundgewerbeflaeche.gml_id     IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_industrieundgewerbeflaeche.name       IS 'NAM "Name" ist der Eigenname von "Industrie- und Gewerbefläche" insbesondere außerhalb von Ortslagen.';
COMMENT ON COLUMN ax_industrieundgewerbeflaeche.zustand    IS 'ZUS "Zustand" beschreibt die Betriebsbereitschaft von "Industrie- und Gewerbefläche".';
COMMENT ON COLUMN ax_industrieundgewerbeflaeche.funktion   IS 'FKT "Funktion" ist die zum Zeitpunkt der Erhebung vorherrschende Nutzung von "Industrie- und Gewerbefläche".';
COMMENT ON COLUMN ax_industrieundgewerbeflaeche.foerdergut IS 'FGT "Fördergut" gibt an, welches Produkt gefördert wird. Die Attributart "Fördergut" kann nur in Verbindung mit der Attributart "Funktion" und der Werteart 2510 vorkommen.';
COMMENT ON COLUMN ax_industrieundgewerbeflaeche.lagergut   IS 'LGT "Lagergut" gibt an, welches Produkt gelagert wird. Die Attributart "Lagergut" kann nur in Verbindung mit der Attributart "Funktion" und der Werteart 1740 vorkommen.';
COMMENT ON COLUMN ax_industrieundgewerbeflaeche.primaerenergie IS 'PEG "Primärenergie" beschreibt die zur Strom- oder Wärmeerzeugung dienende Energieform oder den Energieträger. Die Attributart "Primärenergie" kann nur in Verbindung mit der Attributart "Funktion" und den Wertearten 2530, 2531, 2532, 2570, 2571 und 2572 vorkommen.';


-- H a l d e
-- ----------------------------------------------
-- Objektart: AX_Halde Kennung: 41003
CREATE TABLE ax_halde (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  lagergut integer,
  name character varying,
  zustand integer,
  CONSTRAINT ax_halde_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_halde','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_halde_geom_idx ON ax_halde USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_halde_gml ON ax_halde USING btree (gml_id, beginnt);

COMMENT ON TABLE ax_halde             IS 'Tatsächliche Nutzung / Siedlung: (REO) "Halde" ist eine Fläche, auf der Material langfristig gelagert wird und beschreibt die auch im Relief zu modellierende tatsächliche Aufschüttung.
Aufgeforstete Abraumhalden werden als Objekte der Objektart "Wald" erfasst.';
COMMENT ON COLUMN ax_halde.gml_id     IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_halde.name       IS 'NAM "Name" ist die einer "Halde" zugehörige Bezeichnung oder deren Eigenname.';
COMMENT ON COLUMN ax_halde.lagergut   IS 'LGT "Lagergut" gibt an, welches Produkt gelagert wird.';
COMMENT ON COLUMN ax_halde.zustand    IS 'ZUS "Zustand" beschreibt die Betriebsbereitschaft von "Halde".';


-- B e r b a u b e t r i e b
-- -------------------------
-- Objektart: AX_Bergbaubetrieb Kennung: 41004
CREATE TABLE ax_bergbaubetrieb (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  abbaugut integer,
  name character varying,
  bezeichnung character varying,
  zustand integer,
  CONSTRAINT ax_bergbaubetrieb_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_bergbaubetrieb','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_bergbaubetrieb_geom_idx   ON ax_bergbaubetrieb USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_bergbaubetrieb_gml ON ax_bergbaubetrieb USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_bergbaubetrieb             IS 'Tatsächliche Nutzung / Siedlung: (REO) "Bergbaubetrieb" ist eine Fläche, die für die Förderung des Abbaugutes unter Tage genutzt wird.';
COMMENT ON COLUMN ax_bergbaubetrieb.gml_id      IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_bergbaubetrieb.abbaugut    IS 'AGT "Abbaugut" gibt an, welches Material abgebaut wird.';
COMMENT ON COLUMN ax_bergbaubetrieb.name        IS 'NAM "Name" ist der Eigenname von "Bergbaubetrieb".';
COMMENT ON COLUMN ax_bergbaubetrieb.zustand     IS 'ZUS "Zustand" beschreibt die Betriebsbereitschaft von "Bergbaubetrieb".';
COMMENT ON COLUMN ax_bergbaubetrieb.bezeichnung IS 'BEZ "Bezeichnung" ist die von einer Fachstelle vergebene Kurzbezeichnung.';


-- T a g e b a u  /  G r u b e  /  S t e i n b r u c h
-- ---------------------------------------------------
-- Objektart: AX_TagebauGrubeSteinbruch Kennung: 41005
CREATE TABLE ax_tagebaugrubesteinbruch (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  abbaugut integer,
  name character varying,
  zustand integer,

  CONSTRAINT ax_tagebaugrubesteinbruch_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_tagebaugrubesteinbruch','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_tagebaugrubesteinbruch_geom_idx ON ax_tagebaugrubesteinbruch USING gist (wkb_geometry);

CREATE UNIQUE INDEX ax_tagebaugrubesteinbruchb_gml ON ax_tagebaugrubesteinbruch USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_tagebaugrubesteinbruch          IS 'Tatsächliche Nutzung / Siedlung: (REO) "Tagebau, Grube, Steinbruch" ist eine Fläche, auf der oberirdisch Bodenmaterial abgebaut wird. Rekultivierte Tagebaue, Gruben, Steinbrüche werden als Objekte entsprechend der vorhandenen Nutzung erfasst.';
COMMENT ON COLUMN ax_tagebaugrubesteinbruch.gml_id   IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_tagebaugrubesteinbruch.name     IS 'NAM "Name" ist der Eigenname von "Tagebau, Grube, Steinbruch".';
COMMENT ON COLUMN ax_tagebaugrubesteinbruch.abbaugut IS 'AGT "Abbaugut" gibt an, welches Material abgebaut wird.';
COMMENT ON COLUMN ax_tagebaugrubesteinbruch.zustand  IS 'ZUS "Zustand" beschreibt die Betriebsbereitschaft von "Tagebau, Grube, Steinbruch".';


-- F l ä c h e n   g e m i s c h t e r   N u t z u n g
-- -----------------------------------------------------
-- Objektart: AX_FlaecheGemischterNutzung Kennung: 41006
CREATE TABLE ax_flaechegemischternutzung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artderbebauung integer,
  funktion integer,
  name character varying,
  zustand integer,
  CONSTRAINT ax_flaechegemischternutzung_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_flaechegemischternutzung','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_flaechegemischternutzung_geom_idx     ON ax_flaechegemischternutzung USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_flaechegemischternutzung_gml   ON ax_flaechegemischternutzung USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_flaechegemischternutzung         IS 'Tatsächliche Nutzung / Siedlung: (REO) "Fläche gemischter Nutzung" ist eine bebaute Fläche einschließlich der mit ihr im Zusammenhang stehenden Freifläche (Hofraumfläche, Hausgarten), auf der keine Art der baulichen Nutzung vorherrscht. Solche Flächen sind insbesondere ländlich-dörflich geprägte Flächen mit land- und forstwirtschaftlichen Betrieben, Wohngebäuden u.a. sowie städtisch geprägte Kerngebiete mit Handelsbetrieben und zentralen Einrichtungen für die Wirtschaft und die Verwaltung.';
COMMENT ON COLUMN ax_flaechegemischternutzung.gml_id  IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_flaechegemischternutzung.artderbebauung IS 'BEB "Art der Bebauung" differenziert nach offener und geschlossener Bauweise aus topographischer Sicht und nicht nach gesetzlichen Vorgaben (z.B. BauGB).';
COMMENT ON COLUMN ax_flaechegemischternutzung.funktion       IS 'FKT "Funktion" ist die zum Zeitpunkt der Erhebung vorherrschende Nutzung (Dominanzprinzip).';
COMMENT ON COLUMN ax_flaechegemischternutzung.name           IS 'NAM "Name" ist der Eigenname von "Fläche gemischter Nutzung" insbesondere bei Objekten außerhalb von Ortslagen.';
COMMENT ON COLUMN ax_flaechegemischternutzung.zustand        IS 'ZUS "Zustand" beschreibt, ob "Fläche gemischter Nutzung" ungenutzt ist.';


-- F l ä c h e   b e s o n d e r e r   f u n k t i o n a l e r   P r ä g u n g
-- -------------------------------------------------------------------------------
-- Objektart: AX_FlaecheBesondererFunktionalerPraegung Kennung: 41007
CREATE TABLE ax_flaechebesondererfunktionalerpraegung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  artderbebauung integer,
  name character varying,
  zustand integer,
  CONSTRAINT ax_flaechebesondererfunktionalerpraegung_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_flaechebesondererfunktionalerpraegung','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_flaechebesondererfunktionalerpraegung_geom_idx    ON ax_flaechebesondererfunktionalerpraegung USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_flaechebesondererfunktionalerpraegung_gml  ON ax_flaechebesondererfunktionalerpraegung USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_flaechebesondererfunktionalerpraegung        IS 'Tatsächliche Nutzung / Siedlung: (REO) "Fläche besonderer funktionaler Prägung" ist eine baulich geprägte Fläche einschließlich der mit ihr im Zusammenhang stehenden Freifläche, auf denen vorwiegend Gebäude und/oder Anlagen zur Erfüllung öffentlicher Zwecke oder historische Anlagen vorhanden sind.';
COMMENT ON COLUMN ax_flaechebesondererfunktionalerpraegung.gml_id IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_flaechebesondererfunktionalerpraegung.funktion       IS 'FKT "Funktion" ist die zum Zeitpunkt der Erhebung vorherrschende Nutzung von "Fläche besonderer funktionaler Prägung".';
COMMENT ON COLUMN ax_flaechebesondererfunktionalerpraegung.artderbebauung IS 'BEB "Art der Bebauung" differenziert nach offener und geschlossener Bauweise aus topographischer Sicht und nicht nach gesetzlichen Vorgaben (z.B. BauGB).';
COMMENT ON COLUMN ax_flaechebesondererfunktionalerpraegung.name           IS 'NAM "Name" ist der Eigenname von "Fläche besonderer funktionaler Prägung" insbesondere außerhalb von Ortslagen.';
COMMENT ON COLUMN ax_flaechebesondererfunktionalerpraegung.zustand        IS 'ZUS  "Zustand" beschreibt die Betriebsbereitschaft von "Fläche funktionaler Prägung".';


-- S p o r t - ,   F r e i z e i t -   u n d   E r h o h l u n g s f l ä c h e
-- ---------------------------------------------------------------------------
-- Objektart: AX_SportFreizeitUndErholungsflaeche Kennung: 41008
CREATE TABLE ax_sportfreizeitunderholungsflaeche (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  zustand integer,
  name character varying,
  CONSTRAINT ax_sportfreizeitunderholungsflaeche_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_sportfreizeitunderholungsflaeche','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_sportfreizeitunderholungsflaeche_geom_idx ON ax_sportfreizeitunderholungsflaeche USING gist (wkb_geometry);

CREATE UNIQUE INDEX ax_sportfreizeitunderholungsflaeche_gml ON ax_sportfreizeitunderholungsflaeche USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_sportfreizeitunderholungsflaeche          IS 'Tatsächliche Nutzung / Siedlung: (REO) "Sport-, Freizeit- und Erhohlungsfläche" ist eine bebaute oder unbebaute Fläche, die dem Sport, der Freizeitgestaltung oder der Erholung dient.';
COMMENT ON COLUMN ax_sportfreizeitunderholungsflaeche.gml_id   IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_sportfreizeitunderholungsflaeche.funktion IS 'FKT "Funktion" ist die Art der Nutzung von "Sport-, Freizeit- und Erholungsfläche".';
COMMENT ON COLUMN ax_sportfreizeitunderholungsflaeche.zustand  IS 'ZUS "Zustand" beschreibt die Betriebsbereitschaft von "SportFreizeitUndErholungsflaeche ".';
COMMENT ON COLUMN ax_sportfreizeitunderholungsflaeche.name     IS 'NAM "Name" ist der Eigenname von "Sport-, Freizeit- und Erholungsfläche".';


-- F r i e d h o f
-- ----------------
-- Objektart: AX_Friedhof Kennung: 41009
CREATE TABLE ax_friedhof (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  name character varying,
  zustand integer,
  CONSTRAINT ax_friedhof_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_friedhof','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_friedhof_geom_idx ON ax_friedhof USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_friedhof_gml ON ax_friedhof USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_friedhof           IS 'Tatsächliche Nutzung / Siedlung: (REO) "Friedhof" ist eine Fläche, auf der Tote bestattet sind.';
COMMENT ON COLUMN ax_friedhof.gml_id    IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_friedhof.funktion  IS 'FKT "Funktion" ist die Art der Begräbnisstätte.';
COMMENT ON COLUMN ax_friedhof.name      IS 'NAM "Name" ist der Eigenname von "Friedhof".';
COMMENT ON COLUMN ax_friedhof.zustand   IS 'ZUS "Zustand" beschreibt die Betriebsbereitschaft von "Friedhof".';


--** Objektartengruppe: Verkehr (in Objektbereich: Tatsächliche Nutzung)
--   ===================================================================

-- S t r a s s e n v e r k e h r
-- ----------------------------------------------
-- Objektart: AX_Strassenverkehr Kennung: 42001
CREATE TABLE ax_strassenverkehr (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  name character varying,
  zweitname character varying,
  zustand integer,
  land character varying,
  regierungsbezirk character varying,
  kreis character varying,
  gemeinde character varying,
  lage character varying,
  unverschluesselt character varying,
  CONSTRAINT ax_strassenverkehr_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_strassenverkehr','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_strassenverkehr_geom_idx ON ax_strassenverkehr USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_strassenverkehr_gml ON ax_strassenverkehr USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_strassenverkehr           IS 'Tatsächliche Nutzung / Verkehr: (REO) "Strassenverkehr" umfasst alle für die bauliche Anlage Straße erforderlichen sowie dem Straßenverkehr dienenden bebauten und unbebauten Flächen.';
COMMENT ON COLUMN ax_strassenverkehr.gml_id    IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_strassenverkehr.funktion  IS 'FKT "Funktion" beschreibt die verkehrliche Nutzung von "Straßenverkehr".';
COMMENT ON COLUMN ax_strassenverkehr.name      IS 'NAM "Name" ist der Eigenname von "Strassenverkehr".';
COMMENT ON COLUMN ax_strassenverkehr.zweitname IS 'ZNM "Zweitname" ist ein von der Lagebezeichnung abweichender Name von "Strassenverkehrsflaeche" (z.B. "Deutsche Weinstraße").';
COMMENT ON COLUMN ax_strassenverkehr.zustand   IS 'ZUS "Zustand" beschreibt die Betriebsbereitschaft von "Strassenverkehrsflaeche".';


-- W e g
-- ----------------------------------------------
-- Objektart: AX_Strassenverkehr Kennung: 42001
CREATE TABLE ax_weg (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  name character varying,
  bezeichnung character varying,
  land character varying,
  regierungsbezirk character varying,
  kreis character varying,
  gemeinde character varying,
  lage character varying,
  unverschluesselt character varying,
  CONSTRAINT ax_weg_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_weg','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_weg_geom_idx ON ax_weg USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_weg_gml ON ax_weg USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_weg              IS 'Tatsächliche Nutzung / Verkehr: (REO) "Weg" umfasst alle Flächen, die zum Befahren und/oder Begehen vorgesehen sind. Zum "Weg" gehören auch Seitenstreifen und Gräben zur Wegentwässerung.';
COMMENT ON COLUMN ax_weg.gml_id       IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_weg.funktion     IS 'FKT "Funktion" ist die zum Zeitpunkt der Erhebung objektiv erkennbare oder feststellbare vorherrschend vorkommende Nutzung.';
COMMENT ON COLUMN ax_weg.name         IS 'NAM "Name" ist die Bezeichnung oder der Eigenname von "Wegflaeche".';
COMMENT ON COLUMN ax_weg.bezeichnung  IS 'BEZ "Bezeichnung" ist die amtliche Nummer des Weges.';


-- P l a t z
-- ----------------------------------------------
-- Objektart: AX_Platz Kennung: 42009
CREATE TABLE ax_platz (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  name character varying,
  zweitname character varying,
  land character varying,
  regierungsbezirk character varying,
  kreis character varying,
  gemeinde character varying,
  lage character varying, -- Straßenschlüssel
  unverschluesselt character varying, -- Gewanne?
  CONSTRAINT ax_platz_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_platz','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_platz_geom_idx   ON ax_platz USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_platz_gml ON ax_platz USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_platz           IS 'Tatsächliche Nutzung / Verkehr: (REO) "Platz" ist eine Verkehrsfläche in Ortschaften oder eine ebene, befestigte oder unbefestigte Fläche, die bestimmten Zwecken dient (z. B. für Verkehr, Märkte, Festveranstaltungen).';
COMMENT ON COLUMN ax_platz.gml_id    IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_platz.funktion  IS 'FKT "Funktion" ist die zum Zeitpunkt der Erhebung objektiv erkennbare oder feststellbare vorkommende Nutzung.';
COMMENT ON COLUMN ax_platz.name      IS 'NAM "Name" ist der Eigenname von "Platz".';
COMMENT ON COLUMN ax_platz.zweitname IS 'ZNM "Zweitname" ist der touristische oder volkstümliche Name von "Platz".';


-- B a h n v e r k e h r
-- ----------------------------------------------
-- Objektart: AX_Bahnverkehr Kennung: 42010
CREATE TABLE ax_bahnverkehr (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  bahnkategorie integer,
  bezeichnung character varying,
  nummerderbahnstrecke character varying,
  zweitname character varying,
  zustand integer,
  CONSTRAINT ax_bahnverkehr_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_bahnverkehr','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_bahnverkehr_geom_idx   ON ax_bahnverkehr USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_bahnverkehr_gml ON ax_bahnverkehr USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_bahnverkehr        IS 'Tatsächliche Nutzung / Verkehr: (REO) "Bahnverkehr" umfasst alle für den Schienenverkehr erforderlichen Flächen.
Flächen von Bahnverkehr sind
  * der Bahnkörper (Unterbau für Gleise; bestehend aus Dämmen oder Einschnitten und deren kleineren Böschungen,
    Durchlässen, schmalen Gräben zur Entwässerung, Stützmauern, Unter- und Überführung, Seiten und Schutzstreifen) mit seinen Bahnstrecken
  * an den Bahnkörper angrenzende bebaute und unbebaute Flächen (z.B. größere Böschungsflächen).';

COMMENT ON COLUMN ax_bahnverkehr.gml_id               IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_bahnverkehr.funktion             IS 'FKT "Funktion" ist die objektiv feststellbare Nutzung von "Bahnverkehr".';
COMMENT ON COLUMN ax_bahnverkehr.bahnkategorie        IS 'BKT "Bahnkategorie" beschreibt die Art des Verkehrsmittels.';
COMMENT ON COLUMN ax_bahnverkehr.bezeichnung          IS 'BEZ "Bezeichnung" ist die Angabe der Orte, in denen die Bahnlinie beginnt und endet (z. B. "Bahnlinie Frankfurt - Würzburg").';
COMMENT ON COLUMN ax_bahnverkehr.nummerderbahnstrecke IS 'NRB "Nummer der Bahnstrecke" ist die von der Bahn AG festgelegte Verschlüsselung der Bahnstrecke.';
COMMENT ON COLUMN ax_bahnverkehr.zweitname            IS 'ZNM "Zweitname" ist der von der Lagebezeichnung abweichende Name von "Bahnverkehr" (z. B. "Höllentalbahn").';
COMMENT ON COLUMN ax_bahnverkehr.zustand              IS 'ZUS "Zustand" beschreibt die Betriebsbereitschaft von "Bahnverkehr".';


-- F l u g v e r k e h r
-- ----------------------
-- Objektart: AX_Flugverkehr Kennung: 42015
CREATE TABLE ax_flugverkehr (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  art integer,
  name character varying,
  bezeichnung character varying,
  nutzung integer,
  zustand integer,
  CONSTRAINT ax_flugverkehr_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_flugverkehr','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_flugverkehr_geom_idx   ON ax_flugverkehr USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_flugverkehr_gml ON ax_flugverkehr USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_flugverkehr             IS 'Tatsächliche Nutzung / Verkehr: (REO) "Flugverkehr" umfasst die baulich geprägte Fläche und die mit ihr in Zusammenhang stehende Freifläche, die ausschließlich oder vorwiegend dem Flugverkehr dient.';
COMMENT ON COLUMN ax_flugverkehr.gml_id      IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_flugverkehr.funktion    IS 'FKT "Funktion" ist die zum Zeitpunkt der Erhebung vorherrschende Nutzung (Dominanzprinzip).';
COMMENT ON COLUMN ax_flugverkehr.art         IS 'ART "Art" ist Einstufung der Flugverkehrsfläche durch das Luftfahrtbundesamt.';
COMMENT ON COLUMN ax_flugverkehr.name        IS 'NAM "Name" ist der Eigenname von "Flugverkehr".';
COMMENT ON COLUMN ax_flugverkehr.bezeichnung IS 'BEZ "Bezeichnung" ist die von einer Fachstelle vergebene Kennziffer von "Flugverkehr".';
COMMENT ON COLUMN ax_flugverkehr.nutzung     IS 'NTZ "Nutzung" gibt den Nutzerkreis von "Flugverkehr" an.';
COMMENT ON COLUMN ax_flugverkehr.zustand     IS 'ZUS "Zustand" beschreibt die Betriebsbereitschaft von "Flugverkehr".';


-- S c h i f f s v e r k e h r
-- ---------------------------
-- Objektart: AX_Schiffsverkehr Kennung: 42016
CREATE TABLE ax_schiffsverkehr (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  name character varying,
  zustand integer,
  CONSTRAINT ax_schiffsverkehr_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_schiffsverkehr','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_schiffsverkehr_geom_idx ON ax_schiffsverkehr USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_schiffsverkehr_gml ON ax_schiffsverkehr USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_schiffsverkehr          IS 'Tatsächliche Nutzung / Verkehr: (REO) "Schiffsverkehr" umfasst die baulich geprägte Fläche und die mit ihr in Zusammenhang stehende Freifläche, die ausschließlich oder vorwiegend dem Schiffsverkehr dient.';
COMMENT ON COLUMN ax_schiffsverkehr.gml_id   IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_schiffsverkehr.funktion IS 'FKT "Funktion" ist die zum Zeitpunkt der Erhebung vorherrschende Nutzung von "Schiffsverkehr".';
COMMENT ON COLUMN ax_schiffsverkehr.name     IS 'NAM "Name" ist der Eigenname von "Schiffsverkehr".';
COMMENT ON COLUMN ax_schiffsverkehr.zustand  IS 'ZUS "Zustand" beschreibt die Betriebsbereitschaft von "Schiffsverkehr". Diese Attributart kann nur in Verbindung mit der Attributart "Funktion" und der Werteart 5620 vorkommen.';


--** Objektartengruppe:Vegetation (in Objektbereich:Tatsächliche Nutzung)
--   ===================================================================

-- L a n d w i r t s c h a f t
-- ----------------------------------------------
-- Objektart: AX_Landwirtschaft Kennung: 43001
CREATE TABLE ax_landwirtschaft (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  vegetationsmerkmal integer,
  name character varying,
  CONSTRAINT ax_landwirtschaft_pk PRIMARY KEY (ogc_fid)
);
SELECT AddGeometryColumn('ax_landwirtschaft','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_landwirtschaft_geom_idx ON ax_landwirtschaft USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_landwirtschaft_gml ON ax_landwirtschaft USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_landwirtschaft                    IS 'Tatsächliche Nutzung / Vegetation: (REO) "Landwirtschaft" ist eine Fläche für den Anbau von Feldfrüchten sowie eine Fläche, die beweidet und gemäht werden kann, einschließlich der mit besonderen Pflanzen angebauten Fläche. Die Brache, die für einen bestimmten Zeitraum (z. B. ein halbes oder ganzes Jahr) landwirtschaftlich unbebaut bleibt, ist als "Landwirtschaft" bzw. "Ackerland" zu erfassen';
COMMENT ON COLUMN ax_landwirtschaft.gml_id             IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_landwirtschaft.vegetationsmerkmal IS 'VEG "Vegetationsmerkmal" ist die zum Zeitpunkt der Erhebung erkennbare oder feststellbare vorherrschend vorkommende landwirtschaftliche Nutzung (Dominanzprinzip).';
COMMENT ON COLUMN ax_landwirtschaft.name               IS 'NAM "Name" ist die Bezeichnung oder der Eigenname von "Landwirtschaft".';


-- W a l d
-- ----------------------------------------------
-- Objektart: AX_Wald Kennung: 43002
CREATE TABLE ax_wald (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  vegetationsmerkmal integer,
  name character varying,
  bezeichnung character varying,
  CONSTRAINT ax_wald_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_wald','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_wald_geom_idx ON ax_wald USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_wald_gml ON ax_wald USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_wald             IS 'Tatsächliche Nutzung / Vegetation: (REO) "Wald" ist eine Fläche, die mit Forstpflanzen (Waldbäume und Waldsträucher) bestockt ist.';
COMMENT ON COLUMN ax_wald.gml_id      IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_wald.vegetationsmerkmal IS 'VEG "Vegetationsmerkmal" beschreibt den Bewuchs von "Wald".';
COMMENT ON COLUMN ax_wald.name        IS 'NAM "Name" ist der Eigenname von "Wald".';
COMMENT ON COLUMN ax_wald.bezeichnung IS 'BEZ "Bezeichnung" ist die von einer Fachstelle vergebene Kennziffer (Forstabteilungsnummer, Jagenzahl) von "Wald".';


-- G e h ö l z
-- ----------------------------------------------
-- Objektart: AX_Gehoelz Kennung: 43003
CREATE TABLE ax_gehoelz (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  vegetationsmerkmal integer,
  name character varying,
  funktion integer,
  CONSTRAINT ax_gehoelz_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_gehoelz','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_gehoelz_geom_idx ON ax_gehoelz USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_gehoelz_gml ON ax_gehoelz USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_gehoelz        IS 'Tatsächliche Nutzung / Vegetation: (REO) "Gehölz" ist eine Fläche, die mit einzelnen Bäumen, Baumgruppen, Büschen, Hecken und Sträuchern bestockt ist.';
COMMENT ON COLUMN ax_gehoelz.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_gehoelz.vegetationsmerkmal IS 'VEG "Vegetationsmerkmal" beschreibt den Bewuchs von "Gehölz".';
COMMENT ON COLUMN ax_gehoelz.name               IS 'NAM "Name" ist der Eigenname von "Wald".';
COMMENT ON COLUMN ax_gehoelz.funktion           IS 'FKT "Funktion" beschreibt, welchem Zweck "Gehölz" dient.';


-- H e i d e
-- ----------------------------------------------
-- Objektart: AX_Heide Kennung: 43004
CREATE TABLE ax_heide (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  name character varying,
  CONSTRAINT ax_heide_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_heide','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_heide_geom_idx   ON ax_heide USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_heide_gml ON ax_heide USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_heide        IS 'Tatsächliche Nutzung / Vegetation: (REO) "Heide" ist eine meist sandige Fläche mit typischen Sträuchern, Gräsern und geringwertigem Baumbestand.';
COMMENT ON COLUMN ax_heide.gml_id IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_heide.name   IS 'NAM "Name" ist der Eigenname von "Heide".';


-- M o o r
-- ----------------------------------------------
-- Objektart: AX_Moor Kennung: 43005
CREATE TABLE ax_moor (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  name character varying,
  CONSTRAINT ax_moor_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_moor','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_moor_geom_idx   ON ax_moor USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_moor_gml ON ax_moor USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_moor        IS 'Tatsächliche Nutzung / Vegetation: (REO) "Moor" ist eine unkultivierte Fläche, deren obere Schicht aus vertorften oder zersetzten Pflanzenresten besteht.';
-- Torfstich bzw. Torfabbaufläche wird der Objektart 41005 'Tagebau, Grube, Steinbruch' mit AGT 'Torf' zugeordnet.
COMMENT ON COLUMN ax_moor.gml_id IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_moor.name IS 'NAM "Name" ist der Eigenname von "Moor".';


-- S u m p f
-- ----------------------------------------------
-- Objektart: AX_Sumpf Kennung: 43006
CREATE TABLE ax_sumpf (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  name character varying,
  CONSTRAINT ax_sumpf_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_sumpf','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_sumpf_geom_idx ON ax_sumpf USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_sumpf_gml ON ax_sumpf USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_sumpf        IS 'Tatsächliche Nutzung / Vegetation: (REO) "Sumpf" ist ein wassergesättigtes, zeitweise unter Wasser stehendes Gelände. Nach Regenfällen kurzzeitig nasse Stellen im Boden werden nicht als "Sumpf" erfasst.';
COMMENT ON COLUMN ax_sumpf.gml_id IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_sumpf.name   IS 'NAM "Name" ist der Eigenname von "Sumpf".';


-- U n l a n d  /  V e g e t a t i o n s f l ä c h e
-- ---------------------------------------------------
-- Objektart: AX_UnlandVegetationsloseFlaeche Kennung: 43007
CREATE TABLE ax_unlandvegetationsloseflaeche (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  oberflaechenmaterial integer,
  name character varying,
  funktion integer,
  CONSTRAINT ax_unlandvegetationsloseflaeche_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_unlandvegetationsloseflaeche','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_unlandvegetationsloseflaeche_geom_idx ON ax_unlandvegetationsloseflaeche USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_unlandvegetationsloseflaeche_gml ON ax_unlandvegetationsloseflaeche USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_unlandvegetationsloseflaeche        IS 'Tatsächliche Nutzung / Vegetation: (REO) "Unland/Vegetationslose Fläche" ist eine Fläche, die dauerhaft landwirtschaftlich nicht genutzt wird, wie z.B. nicht aus dem Geländerelief herausragende Felspartien, Sand- oder Eisflächen, Uferstreifen längs von Gewässern und Sukzessionsflächen.';
COMMENT ON COLUMN ax_unlandvegetationsloseflaeche.gml_id IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_unlandvegetationsloseflaeche.oberflaechenmaterial IS 'OFM "Oberflächenmaterial" ist die Beschaffenheit des Bodens von "Unland/Vegetationslose Fläche". Die Attributart "Oberflächenmaterial" kann nur im Zusammenhang mit der Attributart "Funktion" und der Werteart 1000 vorkommen.';
COMMENT ON COLUMN ax_unlandvegetationsloseflaeche.name                 IS 'NAM "Name" ist die Bezeichnung oder der Eigenname von "Unland/ VegetationsloseFlaeche".';
COMMENT ON COLUMN ax_unlandvegetationsloseflaeche.funktion             IS 'FKT "Funktion" ist die erkennbare Art von "Unland/Vegetationslose Fläche".';


--** Objektartengruppe: Gewässer (in Objektbereich: Tatsächliche Nutzung)
--   ===================================================================

-- F l i e s s g e w ä s s e r
-- ----------------------------------------------
-- Objektart: AX_Fliessgewaesser Kennung: 44001
CREATE TABLE ax_fliessgewaesser (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  name character varying,
  zustand integer,
  unverschluesselt character varying,
  CONSTRAINT ax_fliessgewaesser_pk PRIMARY KEY (ogc_fid)
);
SELECT AddGeometryColumn('ax_fliessgewaesser','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_fliessgewaesser_geom_idx ON ax_fliessgewaesser USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_fliessgewaesser_gml ON ax_fliessgewaesser USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_fliessgewaesser IS 'Tatsächliche Nutzung / Gewässer: (REO) "Fließgewässer" ist ein geometrisch begrenztes, oberirdisches, auf dem Festland fließendes Gewässer, das die Wassermengen sammelt, die als Niederschläge auf die Erdoberfläche fallen oder in Quellen austreten, und in ein anderes Gewässer, ein Meer oder in einen See transportiert
 oder
in einem System von natürlichen oder künstlichen Bodenvertiefungen verlaufendes Wasser, das zur Be- und Entwässerung an- oder abgeleitet wird
 oder
ein geometrisch begrenzter, für die Schifffahrt angelegter künstlicher Wasserlauf, der in einem oder in mehreren Abschnitten die jeweils gleiche Höhe des Wasserspiegels besitzt.';

COMMENT ON COLUMN ax_fliessgewaesser.gml_id   IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_fliessgewaesser.funktion IS 'FKT "Funktion" ist die Art von "Fließgewässer".';
COMMENT ON COLUMN ax_fliessgewaesser.name     IS 'NAM "Name" ist die Bezeichnung oder der Eigenname von "Fließgewässer".';
COMMENT ON COLUMN ax_fliessgewaesser.zustand  IS 'ZUS "Zustand" beschreibt die Betriebsbereitschaft von "Fließgewässer" mit FKT=8300 (Kanal).';


-- H a f e n b e c k e n
-- ---------------------
-- Objektart: AX_Hafenbecken Kennung: 44005
CREATE TABLE ax_hafenbecken (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  name character varying,
  nutzung integer,
  CONSTRAINT ax_hafenbecken_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_hafenbecken','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_hafenbecken_geom_idx   ON ax_hafenbecken USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_hafenbecken_gml ON ax_hafenbecken USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_hafenbecken        IS 'Tatsächliche Nutzung / Gewässer: (REO) "Hafenbecken" ist ein natürlicher oder künstlich angelegter oder abgetrennter Teil eines Gewässers, in dem Schiffe be- und entladen werden.';
COMMENT ON COLUMN ax_hafenbecken.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_hafenbecken.funktion IS 'FKT "Funktion" ist die objektiv erkennbare Nutzung von "Hafenbecken".';
COMMENT ON COLUMN ax_hafenbecken.name     IS 'NAM "Name" ist der Eigenname von "Hafenbecken".';
COMMENT ON COLUMN ax_hafenbecken.nutzung  IS 'NTZ "Nutzung" gibt den Nutzerkreis von "Hafenbecken" an.';


-- s t e h e n d e s   G e w ä s s e r
-- ----------------------------------------------
-- Objektart: AX_StehendesGewaesser Kennung: 44006
CREATE TABLE ax_stehendesgewaesser (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  name character varying,
  gewaesserkennziffer character varying,
  hydrologischesMerkmal integer,
  unverschluesselt character varying,
  CONSTRAINT ax_stehendesgewaesser_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_stehendesgewaesser','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_stehendesgewaesser_geom_idx ON ax_stehendesgewaesser USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_stehendesgewaesser_gml ON ax_stehendesgewaesser USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_stehendesgewaesser           IS 'Tatsächliche Nutzung / Gewässer: (REO) "stehendes Gewässer" ist eine natürliche oder künstliche mit Wasser gefüllte, allseitig umschlossene Hohlform der Landoberfläche ohne unmittelbaren Zusammenhang mit "Meer".';
COMMENT ON COLUMN ax_stehendesgewaesser.gml_id    IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_stehendesgewaesser.funktion  IS 'FKT "Funktion" ist die Art von "Stehendes Gewässer".';
COMMENT ON COLUMN ax_stehendesgewaesser.name      IS 'NAM "Name" ist der Eigenname von "Stehendes Gewässer".';
COMMENT ON COLUMN ax_stehendesgewaesser.gewaesserkennziffer   IS 'GWK  "Gewässerkennziffer" ist die von der zuständigen Fachstelle vergebene Verschlüsselung.';
COMMENT ON COLUMN ax_stehendesgewaesser.hydrologischesMerkmal IS 'HYD  "Hydrologisches Merkmal" gibt die Wasserverhältnisse von "Stehendes Gewässer" an.';


-- M e e r
-- ----------------------------------------------
-- Objektart: AX_Meer Kennung: 44007
CREATE TABLE ax_meer (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  name character varying,
  bezeichnung character varying,
  tidemerkmal integer,
  CONSTRAINT ax_meer_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_meer','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_meer_geom_idx   ON ax_meer USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_meer_gml ON ax_meer USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_meer              IS 'Tatsächliche Nutzung / Gewässer: (REO) "Meer" ist die das Festland umgebende Wasserfläche.';
COMMENT ON COLUMN ax_meer.gml_id       IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_meer.funktion     IS 'FKT "Funktion" ist die Art von "Meer".';
COMMENT ON COLUMN ax_meer.name         IS 'NAM "Name" ist der Eigenname von "Meer".';
COMMENT ON COLUMN ax_meer.bezeichnung  IS 'BEZ "Bezeichnung" ist die von der zuständigen Fachbehörde vergebene Verschlüsselung.';
COMMENT ON COLUMN ax_meer.tidemerkmal  IS 'TID "Tidemerkmal" gibt an, ob "Meer" von den periodischen Wasserstandsänderungen beeinflusst wird.';


--*** ############################################################
--*** Objektbereich: Bauwerke, Einrichtungen und sonstige Angaben
--*** ############################################################
-- .. ist Ziel einer Relation


--** Objektartengruppe: Bauwerke und Einrichtungen in Siedlungsflächen
--   ===================================================================

-- T u r m
-- ---------------------------------------------------
-- Objektart: AX_Turm Kennung: 51001
CREATE TABLE ax_turm (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  bauwerksfunktion integer,
  zustand integer,
  name character varying,
  -- Beziehungen:
  zeigtauf character varying, --> ax_lagebezeichnungmithausnummer
  CONSTRAINT ax_turm_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_turm','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_turm_geom_idx ON ax_turm USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_turm_gml ON ax_turm USING btree (gml_id, beginnt);

CREATE INDEX ax_turm_za  ON ax_turm  USING btree  (zeigtauf);

COMMENT ON TABLE  ax_turm        IS 'Bauwerke und Einrichtungen in Siedlungsflächen: (REO) "Turm" ist ein hoch aufragendes, auf einer verhältnismäßig kleinen Fläche freistehendes Bauwerk.';
COMMENT ON COLUMN ax_turm.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_turm.zeigtauf IS '-> Beziehung zu ax_lagebezeichnungmithausnummer (0..*): ''Turm'' zeigt auf eine ''Lagebezeichnung mit Hausnummer''.';


-- Bauwerk oder Anlage fuer Industrie und Gewerbe
-- ----------------------------------------------
-- Objektart: AX_BauwerkOderAnlageFuerIndustrieUndGewerbe Kennung: 51002
CREATE TABLE ax_bauwerkoderanlagefuerindustrieundgewerbe (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  bauwerksfunktion integer,
  name character varying,
  zustand integer,
  objekthoehe double precision,
  CONSTRAINT ax_bauwerkoderanlagefuerindustrieundgewerbe_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_bauwerkoderanlagefuerindustrieundgewerbe','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/POINT

CREATE INDEX ax_bauwerkoderanlagefuerindustrieundgewerbe_geom_idx ON ax_bauwerkoderanlagefuerindustrieundgewerbe USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_bauwerkoderanlagefuerindustrieundgewerbe_gml ON ax_bauwerkoderanlagefuerindustrieundgewerbe USING btree (gml_id, beginnt);

COMMENT ON TABLE ax_bauwerkoderanlagefuerindustrieundgewerbe         IS 'Bauwerke und Einrichtungen in Siedlungsflächen: (REO) "Bauwerk oder Anlage fuer Industrie und Gewerbe" ist ein Bauwerk oder eine Anlage, die überwiegend industriellen und gewerblichen Zwecken dient oder Einrichtung an Ver- und Entsorgungsleitungen ist.';
COMMENT ON COLUMN ax_bauwerkoderanlagefuerindustrieundgewerbe.gml_id IS 'Identifikator, global eindeutig';


-- V o r r a t s b e h ä l t e r  /  S p e i c h e r b a u w e r k
-- -----------------------------------------------------------------
-- Objektart: AX_VorratsbehaelterSpeicherbauwerk Kennung: 51003
CREATE TABLE ax_vorratsbehaelterspeicherbauwerk (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  speicherinhalt integer,
  bauwerksfunktion integer,
  lagezurerdoberflaeche integer,
  name character varying,
  CONSTRAINT ax_vorratsbehaelterspeicherbauwerk_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_vorratsbehaelterspeicherbauwerk','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_vorratsbehaelterspeicherbauwerk_geom_idx ON ax_vorratsbehaelterspeicherbauwerk USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_vorratsbehaelterspeicherbauwerk_gml ON ax_vorratsbehaelterspeicherbauwerk USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_vorratsbehaelterspeicherbauwerk        IS 'Bauwerke und Einrichtungen in Siedlungsflächen: (REO) "Vorratsbehälter, Speicherbauwerk" ist ein geschlossenes Bauwerk zum Aufbewahren von festen, flüssigen oder gasförmigen Stoffen.';
COMMENT ON COLUMN ax_vorratsbehaelterspeicherbauwerk.gml_id IS 'Identifikator, global eindeutig';


-- T r a n s p o r t a n l a g e
-- ---------------------------------------------------
-- Objektart: AX_Transportanlage Kennung: 51004
CREATE TABLE ax_transportanlage (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  bauwerksfunktion integer,
  lagezurerdoberflaeche integer,
  art character varying,
  name character varying,
  produkt integer,
  CONSTRAINT ax_transportanlage_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_transportanlage','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POINT/LINESTRING

CREATE INDEX ax_transportanlage_geom_idx ON ax_transportanlage USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_transportanlage_gml ON ax_transportanlage USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_transportanlage        IS 'Bauwerke und Einrichtungen in Siedlungsflächen: (REO) "Transportanlage" ist eine Anlage zur Förderung oder zum Transport von Flüssigkeiten, Gasen und Gütern.';
COMMENT ON COLUMN ax_transportanlage.gml_id IS 'Identifikator, global eindeutig';


-- L e i t u n g
-- ----------------------------------------------
-- Objektart: AX_Leitung Kennung: 51005
CREATE TABLE ax_leitung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  bauwerksfunktion integer,
  spannungsebene integer,
  CONSTRAINT ax_leitung_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_leitung','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/MULTILINESTRING

CREATE INDEX ax_leitung_geom_idx   ON ax_leitung USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_leitung_gml ON ax_leitung USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_leitung        IS 'Bauwerke und Einrichtungen in Siedlungsflächen: (REO) "Leitung" ist eine aus Drähten oder Fasern hergestellte Leitung zum Transport von elektrischer Energie und zur Übertragung von elektrischen Signalen.';
COMMENT ON COLUMN ax_leitung.gml_id IS 'Identifikator, global eindeutig';


-- Bauwerk oder Anlage fuer Sport, Freizeit und Erholung
-- -----------------------------------------------------
-- Objektart: AX_BauwerkOderAnlageFuerSportFreizeitUndErholung Kennung: 51006
CREATE TABLE ax_bauwerkoderanlagefuersportfreizeitunderholung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  bauwerksfunktion integer,
  sportart integer,
  name character varying,
  CONSTRAINT ax_bauwerkoderanlagefuersportfreizeitunderholung_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_bauwerkoderanlagefuersportfreizeitunderholung','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/POINT

CREATE INDEX ax_bauwerkoderanlagefuersportfreizeitunderholung_geom_idx   ON ax_bauwerkoderanlagefuersportfreizeitunderholung USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_bauwerkoderanlagefuersportfreizeitunderholung_gml ON ax_bauwerkoderanlagefuersportfreizeitunderholung USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_bauwerkoderanlagefuersportfreizeitunderholung        IS 'Bauwerke und Einrichtungen in Siedlungsflächen: (REO) "Bauwerk oder Anlage für Sport, Freizeit und Erholung" ist ein Bauwerk oder eine Anlage in Sport-, Freizeit- und Erholungsanlagen.';
COMMENT ON COLUMN ax_bauwerkoderanlagefuersportfreizeitunderholung.gml_id IS 'Identifikator, global eindeutig';


-- Historisches Bauwerk oder historische Einrichtung
-- -------------------------------------------------
-- Objektart: AX_HistorischesBauwerkOderHistorischeEinrichtung Kennung: 51007
CREATE TABLE ax_historischesbauwerkoderhistorischeeinrichtung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  archaeologischertyp integer,
  name character varying,
  CONSTRAINT ax_historischesbauwerkoderhistorischeeinrichtung_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_historischesbauwerkoderhistorischeeinrichtung','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/POINT

CREATE INDEX ax_historischesbauwerkoderhistorischeeinrichtung_geom_idx   ON ax_historischesbauwerkoderhistorischeeinrichtung USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_historischesbauwerkoderhistorischeeinrichtung_gml ON ax_historischesbauwerkoderhistorischeeinrichtung USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_historischesbauwerkoderhistorischeeinrichtung        IS 'Bauwerke und Einrichtungen in Siedlungsflächen: (REO) "Historisches Bauwerk oder historische Einrichtung" ist ein Bauwerk oder eine Einrichtung vor- oder frühgeschichtlicher Kulturen.';
COMMENT ON COLUMN ax_historischesbauwerkoderhistorischeeinrichtung.gml_id IS 'Identifikator, global eindeutig';


-- H e i l q u e l l e  /  G a s q u e l l e
-- ----------------------------------------------
-- Objektart: AX_HeilquelleGasquelle Kennung: 51008
CREATE TABLE ax_heilquellegasquelle (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art integer,
  name character varying,
  CONSTRAINT ax_heilquellegasquelle_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_heilquellegasquelle','wkb_geometry',:alkis_epsg,'POINT',2);

CREATE INDEX ax_heilquellegasquelle_geom_idx ON ax_heilquellegasquelle USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_heilquellegasquelle_gml ON ax_heilquellegasquelle USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_heilquellegasquelle        IS 'Bauwerke und Einrichtungen in Siedlungsflächen: (REO) "Heilquelle, Gasquelle" ist eine natürliche, örtlich begrenzte Austrittsstelle von Heilwasser oder Gas.';
COMMENT ON COLUMN ax_heilquellegasquelle.gml_id IS 'Identifikator, global eindeutig';


-- sonstiges Bauwerk oder sonstige Einrichtung
-- ----------------------------------------------
-- Objektart: AX_SonstigesBauwerkOderSonstigeEinrichtung Kennung: 51009
CREATE TABLE ax_sonstigesbauwerkodersonstigeeinrichtung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  description integer,
  name character varying,
  bauwerksfunktion integer,
  funktion integer,
  -- Beziehungen:
  gehoertzubauwerk character varying, --> ax_bauwerkeeinrichtungenundsonstigeangaben
  gehoertzu character varying, --> ax_gebaeude
  CONSTRAINT ax_sonstigesbauwerkodersonstigeeinrichtung_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_sonstigesbauwerkodersonstigeeinrichtung','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/LINESTRING

CREATE INDEX ax_sonstigesbauwerkodersonstigeeinrichtung_geom_idx ON ax_sonstigesbauwerkodersonstigeeinrichtung USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_sonstigesbauwerkodersonstigeeinrichtung_gml ON ax_sonstigesbauwerkodersonstigeeinrichtung USING btree (gml_id, beginnt);

CREATE INDEX ax_sonstigesbauwerkodersonstigeeinrichtung_gz  ON ax_sonstigesbauwerkodersonstigeeinrichtung USING btree (gehoertzu);
CREATE INDEX ax_sonstigesbauwerkodersonstigeeinrichtung_gzb ON ax_sonstigesbauwerkodersonstigeeinrichtung USING btree (gehoertzubauwerk);

COMMENT ON TABLE  ax_sonstigesbauwerkodersonstigeeinrichtung        IS 'Bauwerke und Einrichtungen in Siedlungsflächen: (REO) "Sonstiges Bauwerk oder sonstige Einrichtung" ist ein Bauwerk oder eine Einrichtung, das/die nicht zu den anderen Objektarten der Objektartengruppe Bauwerke und Einrichtungen gehört.';
COMMENT ON COLUMN ax_sonstigesbauwerkodersonstigeeinrichtung.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_sonstigesbauwerkodersonstigeeinrichtung.gehoertzubauwerk IS '-> Beziehung zu ax_bauwerkeeinrichtungenundsonstigeangaben (0..1): ''AX_SonstigesBauwerkOderSonstigeEinrichtung'' kann einem anderen Bauwerk zugeordnet werden.';
COMMENT ON COLUMN ax_sonstigesbauwerkodersonstigeeinrichtung.gehoertzu IS '-> Beziehung zu ax_gebaeude (0..1): ''AX_SonstigesBauwerkOderSonstigeEinrichtung'' kann einem Gebäude zugeordnet werden, soweit dies fachlich erforderlich ist.';


-- E i n r i c h t u n g   i n   Ö f f e n t l i c h e n  B e r e i c h e n
-- ------------------------------------------------------------------------
-- Objektart: AX_EinrichtungInOeffentlichenBereichen Kennung: 51010
CREATE TABLE ax_einrichtunginoeffentlichenbereichen (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art integer,
  kilometerangabe character varying,
  CONSTRAINT ax_einrichtunginoeffentlichenbereichen_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_einrichtunginoeffentlichenbereichen','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_einrichtunginoeffentlichenbereichen_geom_idx ON ax_einrichtunginoeffentlichenbereichen USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_einrichtunginoeffentlichenbereichen_gml ON ax_einrichtunginoeffentlichenbereichen USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_einrichtunginoeffentlichenbereichen        IS 'Bauwerke und Einrichtungen in Siedlungsflächen: (REO) "Einrichtung in öffentlichen Bereichen" sind Gegenstände und Einrichtungen verschiedenster Art in öffentlichen oder öffentlich zugänglichen Bereichen (z.B. Straßen, Parkanlagen).';
COMMENT ON COLUMN ax_einrichtunginoeffentlichenbereichen.gml_id IS 'Identifikator, global eindeutig';


-- B e s o n d e r e r   B a u w e r k s p u n k t
-- -----------------------------------------------
-- Objektart: AX_BesondererBauwerkspunkt Kennung: 51011
CREATE TABLE ax_besondererbauwerkspunkt (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  punktkennung character varying,
  land character varying,
  stelle character varying,
  sonstigeeigenschaft character varying[],
  CONSTRAINT ax_besondererbauwerkspunkt_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_besondererbauwerkspunkt','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_besondererbauwerkspunkt_gml ON ax_besondererbauwerkspunkt USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_besondererbauwerkspunkt        IS 'Bauwerke und Einrichtungen in Siedlungsflächen: (ZUSO) "Besonderer Bauwerkspunkt" ist ein Punkt eines "Bauwerks" oder einer "Einrichtung".';
COMMENT ON COLUMN ax_besondererbauwerkspunkt.gml_id IS 'Identifikator, global eindeutig';


--** Objektartengruppe: Besondere Anlagen auf Siedlungsflächen
--   ===================================================================

--** Objektartengruppe: Bauwerke, Anlagen und Einrichtungen für den Verkehr
--   =======================================================================


-- B a u w e r k   i m  V e r k e h s b e r e i c h
-- ------------------------------------------------
-- Objektart: AX_BauwerkImVerkehrsbereich Kennung: 53001
CREATE TABLE ax_bauwerkimverkehrsbereich (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  bauwerksfunktion integer,
  name character varying,
  zustand integer,
  CONSTRAINT ax_bauwerkimverkehrsbereich_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_bauwerkimverkehrsbereich','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/MULTIPOLYGON

CREATE INDEX ax_bauwerkimverkehrsbereich_geom_idx   ON ax_bauwerkimverkehrsbereich USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_bauwerkimverkehrsbereich_gml ON ax_bauwerkimverkehrsbereich USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_bauwerkimverkehrsbereich        IS 'Bauwerke, Anlagen und Einrichtungen für den Verkehr: (REO) "Bauwerk im Verkehsbereich" ist ein Bauwerk, das dem Verkehr dient.';
COMMENT ON COLUMN ax_bauwerkimverkehrsbereich.gml_id IS 'Identifikator, global eindeutig';


-- S t r a ß e n v e r k e h r s a n l a g e
-- ------------------------------------------
-- Objektart: AX_Strassenverkehrsanlage Kennung: 53002
CREATE TABLE ax_strassenverkehrsanlage (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art integer,
  bezeichnung character varying,
  name character varying,
  CONSTRAINT ax_strassenverkehrsanlage_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_strassenverkehrsanlage','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/MULTIPOLYGON

CREATE INDEX ax_strassenverkehrsanlage_geom_idx ON ax_strassenverkehrsanlage USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_strassenverkehrsanlage_gml ON ax_strassenverkehrsanlage USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_strassenverkehrsanlage        IS 'Bauwerke, Anlagen und Einrichtungen für den Verkehr: (REO) "Straßenverkehrsanlage" ist eine besondere Anlage für den Straßenverkehr.';
COMMENT ON COLUMN ax_strassenverkehrsanlage.gml_id IS 'Identifikator, global eindeutig';


-- W e g  /  P f a d  /  S t e i g
-- ----------------------------------------------
-- Objektart: AX_WegPfadSteig Kennung: 53003
CREATE TABLE ax_wegpfadsteig (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art integer,
  name character varying,
  CONSTRAINT ax_wegpfadsteig_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_wegpfadsteig','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/POLYGON

CREATE INDEX ax_wegpfadsteig_geom_idx   ON ax_wegpfadsteig USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_wegpfadsteig_gml ON ax_wegpfadsteig USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_wegpfadsteig        IS 'Bauwerke, Anlagen und Einrichtungen für den Verkehr: (REO) "Weg, Pfad, Steig" ist ein befestigter oder unbefestigter Geländestreifen, der zum Befahren und/oder Begehen vorgesehen ist.';
COMMENT ON COLUMN ax_wegpfadsteig.gml_id IS 'Identifikator, global eindeutig';


-- B a h n v e r k e h r s a n l a g e
-- ----------------------------------------------
-- Objektart: AX_Bahnverkehrsanlage Kennung: 53004
CREATE TABLE ax_bahnverkehrsanlage (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  bahnhofskategorie integer,
  bahnkategorie integer,
  name character varying,
  CONSTRAINT ax_bahnverkehrsanlage_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_bahnverkehrsanlage','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POINT/POLYGON

CREATE INDEX ax_bahnverkehrsanlage_geom_idx ON ax_bahnverkehrsanlage USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_bahnverkehrsanlage_gml ON ax_bahnverkehrsanlage USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_bahnverkehrsanlage        IS 'Bauwerke, Anlagen und Einrichtungen für den Verkehr: (REO) "Bahnverkehrsanlage" ist eine Fläche mit Einrichtungen zur Abwicklung des Personen und/oder Güterverkehrs bei Schienenbahnen. Dazu gehören das Empfangsgebäude, sonstige räumlich angegliederte Verwaltungs- und Lagergebäude, bahntechnische Einrichtungen, Freiflächen und Gleisanlagen.
Die "Bahnverkehrsanlage" der Eisenbahnen beginnt oder endet im Allgemeinen am Einfahrtssignal oder an der Einfahrtsweiche.';
COMMENT ON COLUMN ax_bahnverkehrsanlage.gml_id IS 'Identifikator, global eindeutig';


-- S e i l b a h n, S c h w e b e b a h n
-- --------------------------------------
-- Objektart: AX_SeilbahnSchwebebahn Kennung: 53005
CREATE TABLE ax_seilbahnschwebebahn (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  bahnkategorie integer,
  name character varying,
  CONSTRAINT ax_seilbahnschwebebahn_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_seilbahnschwebebahn','wkb_geometry',:alkis_epsg,'GEOMETRY',2);
-- LINESTRING/MULTILINESTRING
CREATE INDEX ax_seilbahnschwebebahn_geom_idx ON ax_seilbahnschwebebahn USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_seilbahnschwebebahn_gml ON ax_seilbahnschwebebahn USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_seilbahnschwebebahn        IS 'Bauwerke, Anlagen und Einrichtungen für den Verkehr: (REO) "Seilbahn, Schwebebahn" ist eine Beförderungseinrichtung, bei der Waggons, Kabinen oder sonstige Behälter an Seilen oder festen Schienen aufgehängt sind und sich an diesen entlang bewegen.';
COMMENT ON COLUMN ax_seilbahnschwebebahn.gml_id IS 'Identifikator, global eindeutig';


-- G l e i s
-- ----------------------------------------------
-- Objektart: AX_Gleis Kennung: 53006
CREATE TABLE ax_gleis (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  bahnkategorie integer,
  art integer,
  lagezuroberflaeche integer,
  name character varying,
  CONSTRAINT ax_gleis_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_gleis','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/POLYGON

CREATE INDEX ax_gleis_geom_idx ON ax_gleis USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_gleis_gml ON ax_gleis USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_gleis        IS 'Bauwerke, Anlagen und Einrichtungen für den Verkehr: (REO) "Gleis" ist ein zur Führung von Schienenfahrzeugen verlegtes Schienenpaar.';
COMMENT ON COLUMN ax_gleis.gml_id IS 'Identifikator, global eindeutig';


-- F l u g v e r k e h r s a n l a g e
-- -----------------------------------
-- Objektart: AX_Flugverkehrsanlage Kennung: 53007
CREATE TABLE ax_flugverkehrsanlage (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art integer,
  oberflaechenmaterial integer,
  name character varying,
  CONSTRAINT ax_flugverkehrsanlage_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_flugverkehrsanlage','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_flugverkehrsanlage_geom_idx ON ax_flugverkehrsanlage USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_flugverkehrsanlage_gml ON ax_flugverkehrsanlage USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_flugverkehrsanlage          IS 'Bauwerke, Anlagen und Einrichtungen für den Verkehr: (REO) "Flugverkehrsanlage" ist eine Fläche, auf der Luftfahrzeuge am Boden bewegt oder abgestellt werden.';
COMMENT ON COLUMN ax_flugverkehrsanlage.gml_id   IS 'Identifikator, global eindeutig';


-- E i n r i c h t u n g e n  f ü r   d e n   S c h i f f s v e r k e h r
-- ------------------------------------------------------------------------
-- Objektart: AX_EinrichtungenFuerDenSchiffsverkehr Kennung: 53008
CREATE TABLE ax_einrichtungenfuerdenschiffsverkehr (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art integer,
  kilometerangabe character varying,
  name character varying,
  CONSTRAINT ax_einrichtungfuerdenschiffsverkehr_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_einrichtungenfuerdenschiffsverkehr','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_einrichtungenfuerdenschiffsverkehr_geom_idx   ON ax_einrichtungenfuerdenschiffsverkehr USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_einrichtungenfuerdenschiffsverkehr_gml ON ax_einrichtungenfuerdenschiffsverkehr USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_einrichtungenfuerdenschiffsverkehr        IS 'Bauwerke, Anlagen und Einrichtungen für den Verkehr: (REO) "Einrichtungen für den Schiffsverkehr" ist ein Bauwerk, das dem Schiffsverkehr dient.';
COMMENT ON COLUMN ax_einrichtungenfuerdenschiffsverkehr.gml_id IS 'Identifikator, global eindeutig';


-- B a u w e r k   i m   G e w ä s s e r b e r e i c h
-- -----------------------------------------------------
-- Objektart: AX_BauwerkImGewaesserbereich Kennung: 53009
CREATE TABLE ax_bauwerkimgewaesserbereich (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  bauwerksfunktion integer,
  name character varying,
  zustand integer,
  CONSTRAINT ax_bauwerkimgewaesserbereich_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_bauwerkimgewaesserbereich','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/POINT

CREATE INDEX ax_bauwerkimgewaesserbereich_geom_idx ON ax_bauwerkimgewaesserbereich USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_bauwerkimgewaesserbereich_gml ON ax_bauwerkimgewaesserbereich USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_bauwerkimgewaesserbereich        IS 'Bauwerke, Anlagen und Einrichtungen für den Verkehr: (REO) "Bauwerk im Gewässerbereich" ist ein Bauwerk, mit dem ein Wasserlauf unter einem Verkehrsweg oder einem anderen Wasserlauf hindurch geführt wird. Ein "Bauwerk im Gewässerbereich" dient dem Abfluss oder der Rückhaltung von Gewässern oder als Messeinrichtung zur Feststellung des Wasserstandes oder als Uferbefestigung.';
COMMENT ON COLUMN ax_bauwerkimgewaesserbereich.gml_id IS 'Identifikator, global eindeutig';


--** Objektartengruppe: Besondere Vegetationsmerkmale
--   ===================================================================

-- V e g a t a t i o n s m e r k m a l
-- ----------------------------------------------
-- Objektart: AX_Vegetationsmerkmal Kennung: 54001
CREATE TABLE ax_vegetationsmerkmal (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  bewuchs integer,
  zustand integer,
  name character varying,
  CONSTRAINT ax_vegetationsmerkmal_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_vegetationsmerkmal','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_vegetationsmerkmal_geom_idx ON ax_vegetationsmerkmal USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_vegetationsmerkmal_gml ON ax_vegetationsmerkmal USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_vegetationsmerkmal        IS 'Besondere Vegetationsmerkmale: (REO) "Vegatationsmerkmal" beschreibt den zusätzlichen Bewuchs oder besonderen Zustand einer Grundfläche.';
COMMENT ON COLUMN ax_vegetationsmerkmal.gml_id IS 'Identifikator, global eindeutig';


--** Objektartengruppe: Besondere Eigenschaften von Gewässern
--   ===================================================================

-- G e w ä s s e r m e r k m a l
-- ----------------------------------------------
-- Objektart: AX_Gewaessermerkmal Kennung: 55001
CREATE TABLE ax_gewaessermerkmal (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art integer,
  name character varying,
  CONSTRAINT ax_gewaessermerkmal_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_gewaessermerkmal','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POINT/LINESTRING/POLYGON

CREATE INDEX ax_gewaessermerkmal_geom_idx ON ax_gewaessermerkmal USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_gewaessermerkmal_gml ON ax_gewaessermerkmal USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_gewaessermerkmal        IS 'Besondere Eigenschaften von Gewässern: (REO) "Gewässermerkmal" sind besondere Eigenschaften eines Gewässers.';
COMMENT ON COLUMN ax_gewaessermerkmal.gml_id IS 'Identifikator, global eindeutig';


-- u n t e r g e o r d n e t e s   G e w ä s s e r
-- -------------------------------------------------
-- Objektart: AX_UntergeordnetesGewaesser Kennung: 55002
CREATE TABLE ax_untergeordnetesgewaesser (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  funktion integer,
  lagezurerdoberflaeche integer,
  hydrologischesmerkmal integer,
  name character varying,
  CONSTRAINT ax_untergeordnetesgewaesser_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_untergeordnetesgewaesser','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/POLYGON

CREATE INDEX ax_untergeordnetesgewaesser_geom_idx ON ax_untergeordnetesgewaesser USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_untergeordnetesgewaesser_gml ON ax_untergeordnetesgewaesser USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_untergeordnetesgewaesser        IS 'Besondere Eigenschaften von Gewässern: (REO) "untergeordnetes Gewässer" ist ein stehendes oder fließendes Gewässer mit untergeordneter Bedeutung.';
COMMENT ON COLUMN ax_untergeordnetesgewaesser.gml_id IS 'Identifikator, global eindeutig';


-- Objektart: AX_Wasserspiegelhoehe Kennung: 57001
-- 'Wasserspiegelhöhe' ist die Höhe des mittleren Wasserstandes über bzw. unter der Höhenbezugsfläche.


--** Objektartengruppe: Besondere Angaben zum Verkehr
--   ===================================================================
-- 56001 'Netzknoten'
-- 56002 'Nullpunkt'
-- 56003 'Abschnitt'
-- 56004 'Ast'


--** Objektartengruppe: Besondere Angaben zum Gewässer
--   ===================================================================

-- W a s s e r s p i e g e l h ö h e
-- ---------------------------------
-- Objektart: AX_Wasserspiegelhoehe Kennung: 57001
CREATE TABLE ax_wasserspiegelhoehe (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  hoehedeswasserspiegels double precision,
  CONSTRAINT ax_wasserspiegelhoehe_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_wasserspiegelhoehe','wkb_geometry',:alkis_epsg,'POINT',2);

CREATE INDEX ax_wasserspiegelhoehe_geom_idx ON ax_wasserspiegelhoehe USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_wasserspiegelhoehe_gml ON ax_wasserspiegelhoehe USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_wasserspiegelhoehe  IS 'Besondere Angaben zum Gewässer: (REO) "Wasserspiegelhöhe" ist die Höhe des mittleren Wasserstandes über bzw. unter der Höhenbezugsfläche.';


-- S c h i f f f a h r t s l i n i e  /  F ä h r v e r k e h r
-- -----------------------------------------------------------
-- Objektart: AX_SchifffahrtslinieFaehrverkehr Kennung: 57002
CREATE TABLE ax_schifffahrtsliniefaehrverkehr (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art integer[],
  name character varying,
  CONSTRAINT ax_schifffahrtsliniefaehrverkehr_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_schifffahrtsliniefaehrverkehr','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/MULTILINESTRING

CREATE INDEX ax_schifffahrtsliniefaehrverkehr_geom_idx ON ax_schifffahrtsliniefaehrverkehr USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_schifffahrtsliniefaehrverkehr_gml ON ax_schifffahrtsliniefaehrverkehr USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_schifffahrtsliniefaehrverkehr  IS 'Besondere Angaben zum Gewässer: (REO) "Schifffahrtslinie, Fährverkehr" ist die regelmäßige Schiffs- oder Fährverbindung.';


--*** ############################################################
--*** Objektbereich: Relief
--*** ############################################################

--** Objektartengruppe: Reliefformen
--   ===================================================================


-- B ö s c h u n g s k l i f f
-- -----------------------------
-- Objektart: AX_BoeschungKliff Kennung: 61001
CREATE TABLE ax_boeschungkliff (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  objekthoehe double precision,
  CONSTRAINT ax_boeschungkliff_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_boeschungkliff','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_boeschungkliff_gml ON ax_boeschungkliff USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_boeschungkliff        IS 'Reliefformen: (ZUSO) "Böschung" ist die zwischen zwei verschieden hoch gelegenden Ebenen geneigte Geländeoberfläche künstlichen oder natürlichen Ursprungs.
"Kliff" ist eine aus Lockermaterial oder Festgestein aufgebaute Steilküste.';

COMMENT ON COLUMN ax_boeschungkliff.gml_id IS 'Identifikator, global eindeutig';


-- B ö s c h u n g s f l ä c h e
-- ---------------------------------
-- Objektart: AX_Boeschungsflaeche Kennung: 61002
CREATE TABLE ax_boeschungsflaeche (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  -- Beziehungen:
  istteilvon character varying, -- Index drauf?
  CONSTRAINT ax_boeschungsflaeche_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_boeschungsflaeche','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_boeschungsflaeche_geom_idx   ON ax_boeschungsflaeche USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_boeschungsflaeche_gml ON ax_boeschungsflaeche USING btree (gml_id, beginnt);
CREATE INDEX ax_boeschungsflaeche_itv        ON ax_boeschungsflaeche USING btree (istteilvon);

COMMENT ON TABLE  ax_boeschungsflaeche        IS 'Reliefformen: (REO) "Böschungsfläche" ist eine durch Geländekanten begrenzte Geländeoberfläche künstlichen oder natürlichen Ursprungs.';
COMMENT ON COLUMN ax_boeschungsflaeche.gml_id IS 'Identifikator, global eindeutig';


-- D a m m  /  W a l l  /  D e i c h
-- ----------------------------------------------
-- Objektart: AX_DammWallDeich Kennung: 61003
CREATE TABLE ax_dammwalldeich (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art integer,
  name character varying,
  funktion integer,
  CONSTRAINT ax_dammwalldeich_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_dammwalldeich','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/POLYGON

CREATE INDEX ax_dammwalldeich_geom_idx ON ax_dammwalldeich USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_dammwalldeich_gml ON ax_dammwalldeich USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_dammwalldeich        IS 'Reliefformen: (REO) "Damm, Wall, Deich" ist eine aus Erde oder anderen Baustoffen bestehende langgestreckte Aufschüttung, die Vegetation tragen kann.';
COMMENT ON COLUMN ax_dammwalldeich.gml_id IS 'Identifikator, global eindeutig';


-- H ö h l e n e i n g a n g
-- -------------------------
-- Objektart: AX_Hoehleneingang Kennung: 61005
CREATE TABLE ax_hoehleneingang (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  name character varying,
  ax_datenerhebung integer,
  CONSTRAINT ax_hoehleneingang_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_hoehleneingang','wkb_geometry',:alkis_epsg,'POINT',2);

CREATE INDEX ax_hoehleneingang_geom_idx ON ax_hoehleneingang USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_hoehleneingang_gml ON ax_hoehleneingang USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_hoehleneingang        IS 'Reliefformen: (REO) "Höhleneingang" ist die Öffnung eines unterirdischen Hohlraumes an der Erdoberfläche.';
COMMENT ON COLUMN ax_hoehleneingang.gml_id IS 'Identifikator, global eindeutig';


-- F e l s e n ,  F e l s b l o c k ,   F e l s n a d e l
-- ------------------------------------------------------
-- Objektart: AX_FelsenFelsblockFelsnadel Kennung: 61006
CREATE TABLE ax_felsenfelsblockfelsnadel (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  name character varying,
  CONSTRAINT ax_felsenfelsblockfelsnadel_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_felsenfelsblockfelsnadel','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_felsenfelsblockfelsnadel_geom_idx ON ax_felsenfelsblockfelsnadel USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_felsenfelsblockfelsnadel_gml ON ax_felsenfelsblockfelsnadel USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_felsenfelsblockfelsnadel        IS 'Reliefformen: (REO) "Felsen, Felsblock, Felsnadel" ist eine aufragende Gesteinsmasse oder ein einzelner großer Stein.';
COMMENT ON COLUMN ax_felsenfelsblockfelsnadel.gml_id IS 'Identifikator, global eindeutig';


-- D ü n e
-- -------
-- Objektart: AX_Duene Kennung: 61007
CREATE TABLE ax_duene (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  name character varying,
  CONSTRAINT ax_duene_pk PRIMARY KEY (ogc_fid)
);
SELECT AddGeometryColumn('ax_duene','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_duene_geom_idx ON ax_duene USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_duene_gml ON ax_duene USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_duene IS 'Reliefformen: (REO) "Düne" ist ein vom Wind angewehter Sandhügel.';
COMMENT ON COLUMN ax_duene.gml_id IS 'Identifikator, global eindeutig';


-- H ö h e n l i n i e
-- --------------------
-- Objektart: AX_Hoehenlinie Kennung: 61008
CREATE TABLE ax_hoehenlinie (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  hoehevonhoehenlinie double precision,
  CONSTRAINT ax_hoehenlinie_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_hoehenlinie','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/MULTILINESTRING

CREATE INDEX ax_hoehenlinie_geom_idx ON ax_hoehenlinie USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_hoehenlinie_gml ON ax_hoehenlinie USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_hoehenlinie        IS 'Reliefformen: (REO) "Höhenlinie" ist die Schnittlinie einer Objektfläche (z.B. des Geländes) mit einer Fläche konstanter Höhe über oder unter einer Höhenbezugsfläche.';
COMMENT ON COLUMN ax_hoehenlinie.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_hoehenlinie.hoehevonhoehenlinie IS 'HHL "Höhe der Höhenlinie" ist der vertikale Abstand von "Höhenlinie" zum amtlichen Bezugssystem für die Höhe in [m] auf cm gerundet.';


-- B e s o n d e r e r   T o p o g r a f i s c h e r   P u n k t
-- -------------------------------------------------------------
-- Objektart: AX_BesondererTopographischerPunkt Kennung: 61009
CREATE TABLE ax_besonderertopographischerpunkt (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  land character varying,
  stelle character varying,
  punktkennung character varying,
  sonstigeeigenschaft character varying[],
  CONSTRAINT ax_besonderertopographischerpunkt_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_besonderertopographischerpunkt','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_besonderertopographischerpunkt_gml ON ax_besonderertopographischerpunkt USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_besonderertopographischerpunkt        IS 'Reliefformen: (ZUSO) "Besonderer Topografischer Punkt" ist ein im Liegenschaftskataster geführter Topographischer Punkt.';
COMMENT ON COLUMN ax_besonderertopographischerpunkt.gml_id IS 'Identifikator, global eindeutig';


-- S o l l
-- -------
-- Objektart: AX_Soll Kennung: 61010
CREATE TABLE ax_soll (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  name character varying,
  CONSTRAINT ax_soll_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_soll','wkb_geometry',:alkis_epsg,'POLYGON',2);

CREATE INDEX ax_soll_geom_idx ON ax_soll USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_soll_gml ON ax_soll USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_soll        IS 'Reliefformen: (REO) "Soll" ist eine runde, oft steilwandige Vertiefung in den norddeutschen Grundmoränenlandschaften; kann durch Abschmelzen von überschütteten Toteisblöcken (Toteisloch) oder durch Schmelzen periglazialer Eislinsen entstanden sein.';
COMMENT ON COLUMN ax_soll.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_soll.name   IS 'NAM "Name" ist der Eigenname von "Soll".';


--** Objektartengruppe: Primäres DGM
--   ===================================================================
-- Kennung '62000'


-- G e l ä n d e k a n t e
-- ----------------------------------------------
-- Objektart: AX_Gelaendekante Kennung: 62040
CREATE TABLE ax_gelaendekante (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artdergelaendekante integer,
  ax_dqerfassungsmethode integer,
  identifikation integer,
  art integer,
  -- Beziehungen:
  istteilvon			character varying,
  CONSTRAINT ax_gelaendekante_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_gelaendekante','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING

CREATE INDEX ax_gelaendekante_geom_idx   ON ax_gelaendekante USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_gelaendekante_gml ON ax_gelaendekante USING btree (gml_id, beginnt);
CREATE INDEX ax_gelaendekante_itv_idx    ON ax_gelaendekante USING btree (istteilvon);

COMMENT ON TABLE  ax_gelaendekante        IS 'Primäres DGM: (REO) "Geländekante" ist die Schnittlinie unterschiedlich geneigter Geländeflächen.';
COMMENT ON COLUMN ax_gelaendekante.gml_id IS 'Identifikator, global eindeutig';


-- M a r k a n t e r   G e l ä n d e p u n k t
-- -------------------------------------------
-- Objektart: AX_MarkanterGelaendepunkt Kennung: 62070
-- ** Tabelle bisher noch nicht generiert
-- "Markanter Geländepunkt" ist ein Höhenpunkt an markanter Stelle des Geländes, der zur Ergänzung eines gitterförmigen DGM und/oder der Höhenliniendarstellung dient.


-- B e s o n d e r e r   H ö h e n p u n k t
-- -------------------------------------------------------------
-- Objektart: AX_BesondererHoehenpunkt Kennung: 62090
CREATE TABLE ax_besondererhoehenpunkt (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  besonderebedeutung integer,
  CONSTRAINT ax_besondererhoehenpunkt_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_besondererhoehenpunkt','wkb_geometry',:alkis_epsg,'POINT',2);

CREATE INDEX ax_besondererhoehenpunkt_geom_idx ON ax_besondererhoehenpunkt USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_besondererhoehenpunkt_gml ON ax_besondererhoehenpunkt USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_besondererhoehenpunkt        IS 'Primäres DGM: (REO) "Besonderer Höhenpunkt" ist ein Höhenpunkt mit besonderer topographischer Bedeutung.';
COMMENT ON COLUMN ax_besondererhoehenpunkt.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_besondererhoehenpunkt.besonderebedeutung IS 'BBD "Besondere Bedeutung" ist die besondere topographische Bedeutung des Höhenpunktes.';


--** Objektartengruppe: Sekundäres DGM
--   ===================================================================
-- Kennung '63000'
-- 63010 'DGM-Gitter'
-- 63020 'Abgeleitete Höhenlinie'


--*** ############################################################
--*** Objektbereich: Gesetzliche Festlegungen, Gebietseinheiten, Kataloge
--*** ############################################################

--** Objektartengruppe: Öffentlich-rechtliche und sonstige Festlegungen
--   ===================================================================
-- Kennung '71000'

-- K l a s s i f i z i e r u n g   n a c h   S t r a s s e n r e c h t
-- -------------------------------------------------------------------
-- Objektart: AX_KlassifizierungNachStrassenrecht Kennung: 71001
CREATE TABLE ax_klassifizierungnachstrassenrecht (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artderfestlegung integer,
  land character varying,
  stelle character varying,
  bezeichnung character varying,
  CONSTRAINT ax_klassifizierungnachstrassenrecht_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_klassifizierungnachstrassenrecht','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/MULTIPOLYGON

CREATE INDEX ax_klassifizierungnachstrassenrecht_geom_idx   ON ax_klassifizierungnachstrassenrecht USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_klassifizierungnachstrassenrecht_gml ON ax_klassifizierungnachstrassenrecht USING btree (gml_id, beginnt);
CREATE INDEX ax_klassifizierungnachstrassenrecht_afs        ON ax_klassifizierungnachstrassenrecht USING btree (land, stelle);

COMMENT ON TABLE  ax_klassifizierungnachstrassenrecht        IS 'Öffentlich-rechtliche und sonstige Festlegungen: (REO) "Klassifizierung nach Strassenrecht" ist die auf den Grund und Boden bezogene Beschränkung, Belastung oder andere Eigenschaft einer Fläche nach öffentlichen, straßenrechtlichen Vorschriften.';
COMMENT ON COLUMN ax_klassifizierungnachstrassenrecht.gml_id IS 'Identifikator, global eindeutig';


-- Objektart: AX_AndereFestlegungNachStrassenrecht Kennung: 71002
-- "Andere Festlegung nach Straßenrecht" ist die auf den Grund und Boden bezogene Beschränkung, Belastung oder andere Eigenschaft einer Fläche nach öffentlichen, straßenrechtlichen Vorschriften.



-- K l a s s i f i z i e r u n g   n a c h   W a s s e r r e c h t
-- ---------------------------------------------------------------
-- Objektart: AX_KlassifizierungNachWasserrecht Kennung: 71003
CREATE TABLE ax_klassifizierungnachwasserrecht (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artderfestlegung integer,
  land character varying,
  stelle character varying,
  CONSTRAINT ax_klassifizierungnachwasserrecht_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_klassifizierungnachwasserrecht','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_klassifizierungnachwasserrecht_geom_idx ON ax_klassifizierungnachwasserrecht USING gist (wkb_geometry);
CREATE INDEX ax_klassifizierungnachwasserrecht_afs      ON ax_klassifizierungnachwasserrecht USING btree (land, stelle);

COMMENT ON TABLE  ax_klassifizierungnachwasserrecht        IS 'Öffentlich-rechtliche und sonstige Festlegungen: (REO) "Klassifizierung nach Wasserrecht" ist die auf den Grund und Boden bezogene Beschränkung, Belastung oder andere Eigenschaft einer Fläche nach öffentlichen, wasserrechtlichen Vorschriften.';
COMMENT ON COLUMN ax_klassifizierungnachwasserrecht.gml_id IS 'Identifikator, global eindeutig';


-- A n d e r e   F e s t l e g u n g   n a c h   W a s s e r r e c h t
-- --------------------------------------------------------------------
-- Objektart: AX_AndereFestlegungNachWasserrecht Kennung: 71004
CREATE TABLE ax_anderefestlegungnachwasserrecht (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artderfestlegung integer,
  land character varying,
  stelle character varying,
  CONSTRAINT ax_anderefestlegungnachwasserrecht_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_anderefestlegungnachwasserrecht','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE        INDEX ax_anderefestlegungnachwasserrecht_geom_idx ON ax_anderefestlegungnachwasserrecht USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_anderefestlegungnachwasserrecht_gml      ON ax_anderefestlegungnachwasserrecht USING btree (gml_id, beginnt);
CREATE        INDEX ax_anderefestlegungnachwasserrecht_afs      ON ax_anderefestlegungnachwasserrecht(land, stelle);

COMMENT ON TABLE  ax_anderefestlegungnachwasserrecht        IS 'Öffentlich-rechtliche und sonstige Festlegungen: (REO) "Andere Festlegung nach  Wasserrecht" ist die auf den Grund und Boden bezogene Beschränkung, Belastung oder andere Eigenschaft einer Fläche nach öffentlichen, wasserrechtlichen Vorschriften.';
COMMENT ON COLUMN ax_anderefestlegungnachwasserrecht.gml_id IS 'Identifikator, global eindeutig';


-- S c h u t z g e b i e t   n a c h   W a s s e r r e c h t
-- -----------------------------------------------------------
-- Objektart: AX_SchutzgebietNachWasserrecht Kennung: 71005
CREATE TABLE ax_schutzgebietnachwasserrecht (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artderfestlegung integer,
  land character varying,
  stelle character varying,
  art character varying[],
  name character varying[],
  nummerdesschutzgebietes character varying,
  CONSTRAINT ax_schutzgebietnachwasserrecht_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_schutzgebietnachwasserrecht','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_schutzgebietnachwasserrecht_gml ON ax_schutzgebietnachwasserrecht USING btree (gml_id, beginnt);
CREATE        INDEX ax_schutzgebietnachwasserrecht_afs ON ax_schutzgebietnachwasserrecht USING btree (land, stelle);

COMMENT ON TABLE  ax_schutzgebietnachwasserrecht        IS 'Öffentlich-rechtliche und sonstige Festlegungen: (NREO) "Schutzgebiet nach Wassserrecht" ist ein fachlich übergeordnetes Gebiet von Flächen mit bodenbezogenen Beschränkungen, Belastungen oder anderen Eigenschaften nach öffentlichen, wasserrechtlichen Vorschriften.';
COMMENT ON COLUMN ax_schutzgebietnachwasserrecht.gml_id IS 'Identifikator, global eindeutig';


-- N  a t u r -,  U m w e l t -   o d e r   B o d e n s c h u t z r e c h t
-- ------------------------------------------------------------------------
-- Objektart: AX_NaturUmweltOderBodenschutzrecht Kennung: 71006
CREATE TABLE ax_naturumweltoderbodenschutzrecht (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artderfestlegung integer,
  land character varying,
  stelle character varying,
  name character varying,
  CONSTRAINT ax_naturumweltoderbodenschutzrecht_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_naturumweltoderbodenschutzrecht','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/MULTIPOLYGON

CREATE        INDEX ax_naturumweltoderbodenschutzrecht_geom_idx ON ax_naturumweltoderbodenschutzrecht USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_naturumweltoderbodenschutzrecht_gml      ON ax_naturumweltoderbodenschutzrecht USING btree (gml_id, beginnt);
CREATE        INDEX ax_naturumweltoderbodenschutzrecht_afs      ON ax_naturumweltoderbodenschutzrecht USING btree (land, stelle);

COMMENT ON TABLE  ax_naturumweltoderbodenschutzrecht        IS 'Öffentlich-rechtliche und sonstige Festlegungen: (REO) "Natur-, Umwelt- oder Bodenschutzrecht" ist die auf den Grund und Boden bezogene Beschränkung, Belastung oder andere Eigenschaft einer Fläche oder eines Gegenstandes nach öffentlichen, natur-, umwelt- oder bodenschutzrechtlichen Vorschriften.';
COMMENT ON COLUMN ax_naturumweltoderbodenschutzrecht.gml_id IS 'Identifikator, global eindeutig';


-- S c h u t z g e b i e t   n a c h   N a t u r,  U m w e l t  o d e r  B o d e n s c h u t z r e c h t
-- -----------------------------------------------------------------------------------------------------
-- Objektart: AX_SchutzgebietNachNaturUmweltOderBodenschutzrecht Kennung: 71007
CREATE TABLE ax_schutzgebietnachnaturumweltoderbodenschutzrecht (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artderfestlegung integer,
  land character varying,
  stelle character varying,
	name			 character varying,
  CONSTRAINT ax_schutzgebietnachnaturumweltoderbodenschutzrecht_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_schutzgebietnachnaturumweltoderbodenschutzrecht','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_schutzgebietnachnaturumweltoderbodenschutzrecht_gml ON ax_schutzgebietnachnaturumweltoderbodenschutzrecht USING btree (gml_id, beginnt);
CREATE        INDEX ax_schutzgebietnachnaturumweltoderbodenschutzrecht_afs ON ax_schutzgebietnachnaturumweltoderbodenschutzrecht USING btree (land, stelle);

COMMENT ON TABLE  ax_schutzgebietnachnaturumweltoderbodenschutzrecht IS 'Öffentlich-rechtliche und sonstige Festlegungen: (NREO) "Schutzgebiet nach Natur, Umwelt oder Bodenschutzrecht" ist ein fachlich übergeordnetes Gebiet von Flächen mit bodenbezogenen Beschränkungen, Belastungen oder anderen Eigenschaften nach öffentlichen Vorschriften.';
COMMENT ON COLUMN ax_schutzgebietnachnaturumweltoderbodenschutzrecht.gml_id IS 'Identifikator, global eindeutig';


-- B a u - ,   R a u m -   o d e r   B o d e n o r d n u n g s r e c h t
-- ---------------------------------------------------------------------
-- Objektart: AX_BauRaumOderBodenordnungsrecht Kennung: 71008
CREATE TABLE ax_bauraumoderbodenordnungsrecht (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art character varying,
  name character varying,
  artderfestlegung integer,
  land character varying,
  stelle character varying,
  bezeichnung character varying,
  datumanordnung character varying,
  CONSTRAINT ax_bauraumoderbodenordnungsrecht_pk PRIMARY KEY (ogc_fid)
);
SELECT AddGeometryColumn('ax_bauraumoderbodenordnungsrecht','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_bauraumoderbodenordnungsrecht_geom_idx   ON ax_bauraumoderbodenordnungsrecht USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_bauraumoderbodenordnungsrecht_gml ON ax_bauraumoderbodenordnungsrecht USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_bauraumoderbodenordnungsrecht             IS 'Öffentlich-rechtliche und sonstige Festlegungen: (REO) "Bau-, Raum- oder Bodenordnungsrecht" ist ein fachlich übergeordnetes Gebiet von Flächen mit bodenbezogenen Beschränkungen, Belastungen oder anderen Eigenschaften nach öffentlichen Vorschriften.';
COMMENT ON COLUMN ax_bauraumoderbodenordnungsrecht.gml_id      IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_bauraumoderbodenordnungsrecht.artderfestlegung IS 'ADF';
COMMENT ON COLUMN ax_bauraumoderbodenordnungsrecht.name        IS 'NAM, Eigenname von "Bau-, Raum- oder Bodenordnungsrecht"';
COMMENT ON COLUMN ax_bauraumoderbodenordnungsrecht.bezeichnung IS 'BEZ, Amtlich festgelegte Verschlüsselung von "Bau-, Raum- oder Bodenordnungsrecht"';


-- D e n k m a l s c h u t z r e c h t
-- -----------------------------------
-- Objektart: AX_Denkmalschutzrecht Kennung: 71009
CREATE TABLE ax_denkmalschutzrecht (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artderfestlegung integer,
  land character varying,
  stelle character varying,
  art character varying,
  name character varying,
  CONSTRAINT ax_denkmalschutzrecht_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_denkmalschutzrecht','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/MULTIPOLYGON

CREATE INDEX ax_denkmalschutzrecht_geom_idx   ON ax_denkmalschutzrecht USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_denkmalschutzrecht_gml ON ax_denkmalschutzrecht USING btree (gml_id, beginnt);
CREATE INDEX ax_denkmalschutzrecht_afs        ON ax_denkmalschutzrecht(land, stelle);

COMMENT ON TABLE  ax_denkmalschutzrecht        IS 'Öffentlich-rechtliche und sonstige Festlegungen: (REO)  "Denkmalschutzrecht" ist die auf den Grund und Boden bezogene Beschränkung, Belastung oder andere Eigenschaft einer Fläche oder Gegenstand nach öffentlichen, denkmalschutzrechtlichen Vorschriften.';
COMMENT ON COLUMN ax_denkmalschutzrecht.gml_id IS 'Identifikator, global eindeutig';


-- F o r s t r e c h t
-- -------------------
-- Objektart: AX_Forstrecht Kennung: 71010
CREATE TABLE ax_forstrecht (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artderfestlegung integer,
  besonderefunktion integer,
  land character varying,
  stelle character varying,
  CONSTRAINT ax_forstrecht_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_forstrecht','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/MULTIPOLYGON

CREATE INDEX ax_forstrecht_geom_idx   ON ax_forstrecht USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_forstrecht_gml ON ax_forstrecht USING btree (gml_id, beginnt);
CREATE INDEX ax_forstrecht_afs ON ax_forstrecht(land,stelle);

COMMENT ON TABLE  ax_forstrecht        IS 'Öffentlich-rechtliche und sonstige Festlegungen: (REO) "Forstrecht" ist die auf den Grund und Boden bezogene Beschränkung, Belastung oder andere Eigenschaft einer Fläche nach öffentlichen, forstrechtlichen Vorschriften.';
COMMENT ON COLUMN ax_forstrecht.gml_id IS 'Identifikator, global eindeutig';


-- S o n s t i g e s   R e c h t
-- -----------------------------
-- Objektart: AX_SonstigesRecht Kennung: 71011
CREATE TABLE ax_sonstigesrecht (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  artderfestlegung integer,
  land character varying,
  stelle character varying,
  bezeichnung character varying,
 characterstring character varying,
  art character varying,
  name character varying,
  funktion integer,
  CONSTRAINT ax_sonstigesrecht_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_sonstigesrecht','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_sonstigesrecht_geom_idx ON ax_sonstigesrecht USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_sonstigesrecht_gml ON ax_sonstigesrecht USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_sonstigesrecht        IS 'Öffentlich-rechtliche und sonstige Festlegungen: (REO) "Sonstiges Recht" sind die auf den Grund und Boden bezogenen Beschränkungen, Belastungen oder anderen Eigenschaften einer Fläche nach weiteren, nicht unter die Objektarten 71001 bis 71010 zu subsumierenden öffentlich - rechtlichen Vorschriften.';
COMMENT ON COLUMN ax_sonstigesrecht.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_sonstigesrecht.artderfestlegung IS 'ADF "Art der Festlegung" ist die auf den Grund und Boden bezogene Art der Beschränkung, Belastung oder anderen öffentlich-rechtlichen Eigenschaft.';


-- S c h u t z z o n e
-- -------------------
-- Objektart: AX_Schutzzone Kennung: 71012
CREATE TABLE ax_schutzzone (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  "zone" integer,
  art character varying[],
  -- Beziehungen:
  istteilvon character varying, --> AX_SchutzgebietNachWasserrecht
  CONSTRAINT ax_schutzzone_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_schutzzone','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/MULTIPOLYGON

CREATE        INDEX ax_schutzzone_geom_idx ON ax_schutzzone USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_schutzzone_gml      ON ax_schutzzone USING btree (gml_id, beginnt);
CREATE        INDEX ax_schutzzone_itv      ON ax_schutzzone USING btree (istteilvon);

COMMENT ON TABLE  ax_schutzzone        IS 'Öffentlich-rechtliche und sonstige Festlegungen: (REO) "Schutzzone" ist die auf den Grund und Boden bezogene Beschränkung, Belastung oder andere Eigenschaft einer Fläche nach öffentlichen oder wasserrechtlichen Vorschriften.';
COMMENT ON COLUMN ax_schutzzone.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_schutzzone.istteilvon IS '-> Beziehung zu AX_SchutzgebietNachWasserrecht (1)';



--** Objektartengruppe: Bodenschätzung, Bewertung
--   ===================================================================
-- Kennung '72000'


-- B o d e n s c h ä t z u n g
-- ----------------------------------------------
-- Objektart: AX_Bodenschaetzung Kennung: 72001
CREATE TABLE ax_bodenschaetzung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art character varying,
  name character varying,
  kulturart integer,
  bodenart integer,
  zustandsstufeoderbodenstufe integer,
  entstehungsartoderklimastufewasserverhaeltnisse integer[],
  bodenzahlodergruenlandgrundzahl integer,
  ackerzahlodergruenlandzahl integer,
  sonstigeangaben integer[],
  jahreszahl integer,
  CONSTRAINT ax_bodenschaetzung_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_bodenschaetzung','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/MULTIPOLYGON

CREATE INDEX ax_bodenschaetzung_geom_idx ON ax_bodenschaetzung USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_bodenschaetzung_gml ON ax_bodenschaetzung USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_bodenschaetzung              IS 'Bodenschätzung, Bewertung: (REO) "Bodenschätzung" ist die kleinste Einheit einer bodengeschätzten Fläche nach dem Bodenschätzungsgesetz, für die eine Ertragsfähigkeit im Liegenschaftskataster nachzuweisen ist (Bodenschätzungsfläche). Ausgenommen sind Musterstücke, Landesmusterstücke und Vergleichsstücke der Bodenschätzung.';

COMMENT ON COLUMN ax_bodenschaetzung.gml_id       IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_bodenschaetzung.kulturart    IS 'KUL "Kulturart" ist die bestandskräftig festgesetzte landwirtschaftliche Nutzungsart entsprechend dem Acker- oder Grünlandschätzungsrahmen.';
COMMENT ON COLUMN ax_bodenschaetzung.bodenart     IS 'KN1 "Bodenart" ist die nach den Durchführungsbestimmungen zum Bodenschätzungsgesetz (Schätzungsrahmen) festgelegte Bezeichnung der Bodenart.';
COMMENT ON COLUMN ax_bodenschaetzung.zustandsstufeoderbodenstufe     IS 'KN2 "Zustandsstufe oder Bodenstufe" ist die nach den Schätzungsrahmen festgelegte Bezeichnung der Zustands- oder Bodenstufe.';
COMMENT ON COLUMN ax_bodenschaetzung.entstehungsartoderklimastufewasserverhaeltnisse IS 'KN3 "Entstehungsart oder Klimastufe/Wasserverhältnisse" ist die nach den Schätzungsrahmen festgelegte Bezeichnung der Entstehungsart oder der Klimastufe und der Wasserverhältnisse.';
COMMENT ON COLUMN ax_bodenschaetzung.bodenzahlodergruenlandgrundzahl IS 'WE1 "Bodenzahl oder Grünlandgrundzahl" ist die Wertzahl nach dem Acker- oder Grünlandschätzungsrahmen';
COMMENT ON COLUMN ax_bodenschaetzung.ackerzahlodergruenlandzahl      IS 'WE2 "Ackerzahl oder Grünlandzahl" ist die "Bodenzahl oder Grünlandgrundzahl" einschließlich Ab- und Zurechnungen nach dem Bodenschätzungsgesetz.';
COMMENT ON COLUMN ax_bodenschaetzung.sonstigeangaben                 IS 'SON "Sonstige Angaben" ist der Nachweis von Besonderheiten einer bodengeschätzten Fläche.';
COMMENT ON COLUMN ax_bodenschaetzung.jahreszahl   IS 'JAH "Jahreszahl" ist das Jahr, in dem eine Neukultur oder Tiefkultur angelegt worden ist.';


-- M u s t e r -,  L a n d e s m u s t e r -   u n d   V e r g l e i c h s s t u e c k
-- -----------------------------------------------------------------------------------
-- Objektart: AX_MusterLandesmusterUndVergleichsstueck Kennung: 72002
CREATE TABLE ax_musterlandesmusterundvergleichsstueck (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art character varying,
  name character varying,
  merkmal integer,
  nummer character varying, -- integer
  kulturart integer,
  bodenart integer,
  zustandsstufeoderbodenstufe integer,
  entstehungsartoderklimastufewasserverhaeltnisse integer,
  bodenzahlodergruenlandgrundzahl character varying, -- integer
  ackerzahlodergruenlandzahl character varying, -- integer
  sonstigeangaben integer[],
  CONSTRAINT ax_musterlandesmusterundvergleichsstueck_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_musterlandesmusterundvergleichsstueck','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- POLYGON/POINT

CREATE INDEX ax_musterlandesmusterundvergleichsstueck_geom_idx   ON ax_musterlandesmusterundvergleichsstueck USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_musterlandesmusterundvergleichsstueck_gml ON ax_musterlandesmusterundvergleichsstueck USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_musterlandesmusterundvergleichsstueck           IS 'Bodenschätzung, Bewertung: (REO) "Muster-, Landesmuster- und Vergleichsstück" ist eine besondere bodengeschätzte Fläche nach dem Bodenschätzungsgesetz, für die eine Ertragsfähigkeit im Liegenschaftskataster nachzuweisen ist.';
COMMENT ON COLUMN ax_musterlandesmusterundvergleichsstueck.gml_id    IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_musterlandesmusterundvergleichsstueck.merkmal   IS 'MDB "Merkmal" ist die Kennzeichnung zur Unterscheidung von Musterstück, Landesmusterstück und Vergleichsstück.';
COMMENT ON COLUMN ax_musterlandesmusterundvergleichsstueck.nummer    IS 'MKN "Nummer" ist ein von der Finanzverwaltung zur eindeutigen Bezeichnung der Muster-, Landesmusterstücke und Vergleichsstücke vergebenes Ordnungsmerkmal (z.B.: 2328.07 mit Bundesland (23), Finanzamt (28), lfd. Nummer (07)).';

COMMENT ON COLUMN ax_musterlandesmusterundvergleichsstueck.kulturart IS 'KUL "Kulturart" ist die bestandskräftig festgesetzte landwirtschaftliche Nutzungsart entsprechend dem Acker- oder Grünlandschätzungsrahmen.';
COMMENT ON COLUMN ax_musterlandesmusterundvergleichsstueck.bodenart  IS 'KN1 "Bodenart" ist die nach den Durchführungsbestimmungen zum Bodenschätzungsgesetz (Schätzungsrahmen) festgelegte Bezeichnung der Bodenart.';
COMMENT ON COLUMN ax_musterlandesmusterundvergleichsstueck.zustandsstufeoderbodenstufe     IS 'KN2 "Zustandsstufe oder Bodenstufe" ist die nach den Schätzungsrahmen festgelegte Bezeichnung der Zustands- oder Bodenstufe.';
COMMENT ON COLUMN ax_musterlandesmusterundvergleichsstueck.entstehungsartoderklimastufewasserverhaeltnisse IS 'KN3 "Entstehungsart oder Klimastufe/Wasserverhältnisse" ist die nach den Schätzungsrahmen festgelegte Bezeichnung der Entstehungsart oder der Klimastufe und der Wasserverhältnisse.';
COMMENT ON COLUMN ax_musterlandesmusterundvergleichsstueck.bodenzahlodergruenlandgrundzahl IS 'WE1 "Bodenzahl oder Grünlandgrundzahl" ist die Wertzahl nach dem Acker- oder Grünlandschätzungsrahmen.';
COMMENT ON COLUMN ax_musterlandesmusterundvergleichsstueck.ackerzahlodergruenlandzahl      IS 'WE2 "Ackerzahl oder Grünlandzahl" ist die "Bodenzahl oder Grünlandgrundzahl" einschließlich Ab- und Zurechnungen nach dem Bodenschätzungsgesetz.';
COMMENT ON COLUMN ax_musterlandesmusterundvergleichsstueck.sonstigeangaben                 IS 'SON "Sonstige Angaben" ist der Nachweis von Besonderheiten einer bodengeschätzten Fläche.';


-- G r a b l o c h   d e r   B o d e n s c h ä t z u n g
-- -----------------------------------------------------
-- Objektart: AX_GrablochDerBodenschaetzung Kennung: 72003
CREATE TABLE ax_grablochderbodenschaetzung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  art character varying,
  name character varying,
  bedeutung integer[],
  land character varying,
  nummerierungsbezirk character varying,
  gemarkungsnummer character varying,
  nummerdesgrablochs character varying,
  bodenzahlodergruenlandgrundzahl integer,
  -- Beziehungen:
  gehoertzu character varying, --> ax_tagesabschnitt
  CONSTRAINT ax_grablochderbodenschaetzung_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_grablochderbodenschaetzung','wkb_geometry',:alkis_epsg,'POINT',2);

CREATE INDEX ax_grablochderbodenschaetzung_geom_idx   ON ax_grablochderbodenschaetzung USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_grablochderbodenschaetzung_gml ON ax_grablochderbodenschaetzung USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_grablochderbodenschaetzung        IS 'Bodenschätzung, Bewertung: (REO) "Grabloch der Bodenschätzung" ist der Lagepunkt der Profilbeschreibung von Grab-/Bohrlöchern.';
COMMENT ON COLUMN ax_grablochderbodenschaetzung.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_grablochderbodenschaetzung.gehoertzu IS '-> Beziehung zu ax_tagesabschnitt (0..1): Jedes Grabloch einer Bodenschätzung liegt in einem Tagesabschnitt.';


-- B e w e r t u n g
-- ------------------
-- Objektart: AX_Bewertung Kennung: 72004
CREATE TABLE ax_bewertung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  klassifizierung integer,
  CONSTRAINT ax_bewertung_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_bewertung','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_bewertung_geom_idx   ON ax_bewertung USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_bewertung_gml ON ax_bewertung USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_bewertung        IS 'Bodenschätzung, Bewertung: (REO) "Bewertung" ist die Klassifizierung einer Fläche nach dem Bewertungsgesetz (Bewertungsfläche).';
COMMENT ON COLUMN ax_bewertung.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_bewertung.klassifizierung IS 'KLA "Klassifizierung" ist die gesetzliche Klassifizierung nach dem Bewertungsgesetz.';


-- T a g e s a b s c h n i t t
-- ---------------------------
-- Objektart: AX_Tagesabschnitt Kennung: 72006
CREATE TABLE ax_tagesabschnitt (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  tagesabschnittsnummer character varying,
  CONSTRAINT ax_tagesabschnitt_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_tagesabschnitt','wkb_geometry',:alkis_epsg,'POLYGON',2);

CREATE INDEX ax_tagesabschnitt_geom_idx   ON ax_tagesabschnitt USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_tagesabschnitt_gml ON ax_tagesabschnitt USING btree (gml_id, beginnt);

COMMENT ON TABLE ax_tagesabschnitt         IS 'Bodenschätzung, Bewertung: (REO) "Tagesabschnitt" ist ein Ordnungskriterium der Schätzungsarbeiten für eine Bewertungsfläche. Innerhalb der Tagesabschnitte sind die Grablöcher eindeutig zugeordnet.';
COMMENT ON COLUMN ax_tagesabschnitt.gml_id IS 'Identifikator, global eindeutig';


--** Objektartengruppe: Kataloge
--   ===================================================================
-- Kennung '73000'


-- B u n d e s l a n d
-- ----------------------------------------------
-- Objektart: AX_Bundesland Kennung: 73002
CREATE TABLE ax_bundesland (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schluesselgesamt character varying,
  bezeichnung character varying,
  land character varying,
  stelle character varying,
  CONSTRAINT ax_bundesland_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_bundesland','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_bundesland_gml ON ax_bundesland USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_bundesland        IS 'Kataloge: (NREO) "Bundesland" umfasst das Gebiet des jeweiligen Bundeslandes innerhalb der Bundesrepublik Deutschland.';
COMMENT ON COLUMN ax_bundesland.gml_id IS 'Identifikator, global eindeutig';


-- R e g i e r u n g s b e z i r k
-- ----------------------------------------------
-- Objektart: AX_Regierungsbezirk Kennung: 73003
CREATE TABLE ax_regierungsbezirk (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schluesselgesamt character varying,
  bezeichnung character varying,
  land character varying,
  regierungsbezirk character varying,
  CONSTRAINT ax_regierungsbezirk_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_regierungsbezirk','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_regierungsbezirk_gml ON ax_regierungsbezirk USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_regierungsbezirk        IS 'Kataloge: (NREO) "Regierungsbezirk" enthält alle zur Regierungsbezirksebene zählenden Verwaltungseinheiten innerhalb eines Bundeslandes.';
COMMENT ON COLUMN ax_regierungsbezirk.gml_id IS 'Identifikator, global eindeutig';


-- K r e i s   /   R e g i o n
-- ---------------------------
-- Objektart: AX_KreisRegion Kennung: 73004
CREATE TABLE ax_kreisregion (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schluesselgesamt character varying,
  bezeichnung character varying,
  land character varying,
  regierungsbezirk character varying,
  kreis character varying,
  CONSTRAINT ax_kreisregion_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_kreisregion','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_kreisregion_gml ON ax_kreisregion USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_kreisregion        IS 'Kataloge: (NREO) "Kreis/Region" enthält alle zur Kreisebene zählenden Verwaltungseinheiten innerhalb eines Bundeslandes.';
COMMENT ON COLUMN ax_kreisregion.gml_id IS 'Identifikator, global eindeutig';


-- G e m e i n d e
-- ----------------------------------------------
-- Objektart: AX_Gemeinde Kennung: 73005
CREATE TABLE ax_gemeinde (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schluesselgesamt character varying,
  bezeichnung character varying,
  land character varying,
  regierungsbezirk character varying,
  kreis character varying,
  gemeinde character varying,
  stelle character varying,
  -- Beziehungen:
  istamtsbezirkvon character varying[], --> ax_dienststelle
  CONSTRAINT ax_gemeinde_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_gemeinde','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_gemeinde_gml ON ax_gemeinde USING btree (gml_id, beginnt);
CREATE INDEX ax_gemeinde_iabv       ON ax_gemeinde USING gin   (istamtsbezirkvon);

COMMENT ON TABLE  ax_gemeinde        IS 'Kataloge: (NREO) "Gemeinde" enthält alle zur Gemeindeebene zählenden Verwaltungseinheiten innerhalb eines Bundeslandes.';
COMMENT ON COLUMN ax_gemeinde.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_gemeinde.istamtsbezirkvon IS '-> Beziehung zu ax_dienststelle (0..*): ''Gemeinde'' ist Verwaltungsbezirk einer Dienststelle.';


-- G e m e i n d e t e i l
-- -----------------------------------------
-- Objektart: AX_Gemeindeteil Kennung: 73006
CREATE TABLE ax_gemeindeteil (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schluesselgesamt character varying,
  bezeichnung character varying,
  administrativefunktion integer,
  land character varying,
  regierungsbezirk character varying,
  kreis character varying,
  gemeinde character varying,
  gemeindeteil integer,
  CONSTRAINT ax_gemeindeteil_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_gemeindeteil','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_gemeindeteil_gml ON ax_gemeindeteil USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_gemeindeteil        IS 'Kataloge: (NREO) "Gemeindeteil" enthält alle zur Gemeindeteilebene zählenden Verwaltungseinheiten innerhalb eines Bundeslandes.';
COMMENT ON COLUMN ax_gemeindeteil.gml_id IS 'Identifikator, global eindeutig';


-- G e m a r k u n g
-- ----------------------------------------------
-- Objektart: AX_Gemarkung Kennung: 73007
CREATE TABLE ax_gemarkung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schluesselgesamt character varying,
  bezeichnung character varying,
  land character varying,
  gemarkungsnummer character varying,
  stelle character varying,
  CONSTRAINT ax_gemarkung_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_gemarkung','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_gemarkung_gml ON ax_gemarkung USING btree (gml_id, beginnt);
CREATE INDEX ax_gemarkung_nr         ON ax_gemarkung USING btree (land, gemarkungsnummer); -- Such-Index, Verweis aus ax_Flurstueck

COMMENT ON TABLE  ax_gemarkung        IS 'Kataloge: (NREO) "Gemarkung" ist ein Katasterbezirk, der eine zusammenhängende Gruppe von Flurstücken umfasst. Er kann von Gemarkungsteilen/Fluren unterteilt werden.';
COMMENT ON COLUMN ax_gemarkung.gml_id IS 'Identifikator, global eindeutig';


-- G e m a r k u n g s t e i l   /   F l u r
-- ----------------------------------------------
-- Objektart: AX_GemarkungsteilFlur Kennung: 73008
CREATE TABLE ax_gemarkungsteilflur (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schluesselgesamt character varying,
  bezeichnung character varying,
  land character varying,
  gemarkung integer,
  gemarkungsteilflur integer,
  CONSTRAINT ax_gemarkungsteilflur_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_gemarkungsteilflur','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_gemarkungsteilflur_gml ON ax_gemarkungsteilflur USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_gemarkungsteilflur        IS 'Kataloge: (NREO) "Gemarkungsteil/Flur" enthält die Gemarkungsteile und Fluren. Gemarkungsteile kommen nur in Bayern vor und entsprechen den Fluren in anderen Bundesländern.';
COMMENT ON COLUMN ax_gemarkungsteilflur.gml_id IS 'Identifikator, global eindeutig';


-- V e r w a l t u n g s g e m e i n s c h a f t
-- ---------------------------------------------
-- Objektart: AX_Verwaltungsgemeinschaft Kennung: 73009
CREATE TABLE ax_verwaltungsgemeinschaft (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schluesselgesamt character varying,
  bezeichnung character varying,
  bezeichnungart integer,
  land character varying,
  regierungsbezirk character varying,
  kreis character varying,
  verwaltungsgemeinschaft integer,
  CONSTRAINT ax_verwaltungsgemeinschaft_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_verwaltungsgemeinschaft','dummy',:alkis_epsg,'POINT',2);

COMMENT ON TABLE  ax_verwaltungsgemeinschaft  IS 'Kataloge: (ZUSO) "Verwaltungsgemeinschaft" bezeichnet einen Zusammenschluss von Gemeinden zur gemeinsamen Erfüllung von hoheitlichen Aufgaben.';
COMMENT ON COLUMN ax_verwaltungsgemeinschaft.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_verwaltungsgemeinschaft.bezeichnungart IS 'BZA "Bezeichnung (Art)" enthält den landesspezifischen Begriff für eine Verwaltungsgemeinschaft.';
-- Werte:
-- 1000 Samtgemeinde     'Samtgemeinde' umfasst in Niedersachsen das Gebiet einer Samtgemeinde.
-- 2000 Verbandsgemeinde
-- 3000 Amt              'Amt' umfasst das Gebiet eines Amtes, das aus Gemeinden desselben Landkreises besteht.


-- B u c h u n g s b l a t t - B e z i r k
-- ----------------------------------------------
-- Objektart: AX_Buchungsblattbezirk Kennung: 73010
CREATE TABLE ax_buchungsblattbezirk (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schluesselgesamt character varying,
  bezeichnung character varying,
  land character varying,
  bezirk character varying,
  stelle character varying,
  -- Beziehungen:
  gehoertzu character varying, --> ax_dienststelle
  CONSTRAINT ax_buchungsblattbezirk_pk PRIMARY KEY (ogc_fid)
);
SELECT AddGeometryColumn('ax_buchungsblattbezirk','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_buchungsblattbezirk_gml ON ax_buchungsblattbezirk USING btree (gml_id, beginnt);
CREATE INDEX ax_buchungsblattbez_ghz  ON ax_buchungsblattbezirk  USING btree  (gehoertzu);

CREATE INDEX ax_buchungsblattbez_key  ON ax_buchungsblattbezirk USING btree (land, bezirk);

COMMENT ON TABLE  ax_buchungsblattbezirk        IS 'Kataloge: (NREO) "Buchungsblattbezirk" enthält die Verschlüsselung von Buchungsbezirken mit der entsprechenden Bezeichnung.';
COMMENT ON COLUMN ax_buchungsblattbezirk.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_buchungsblattbezirk.gehoertzu IS '-> Beziehung zu ax_dienststelle (0..1): Buchungsblattbezirk" wird von einem Grundbuchamt verwaltet, das im Katalog der Dienststellen geführt wird. Die Relation wird nur gebildet, wenn die Dienststelle ein Grundbuchamt ist.';


-- D i e n s t s t e l l e
-- ----------------------------------------------
-- Objektart: AX_Dienststelle Kennung: 73011
CREATE TABLE ax_dienststelle (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schluesselgesamt character varying,
  bezeichnung character varying,
  land character varying,
  stelle character varying,
  stellenart integer,
  kennung character varying,
  -- Beziehungen:
  hat character varying, --> ax_anschrift
  CONSTRAINT ax_dienststelle_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_dienststelle','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_dienststelle_gml ON ax_dienststelle USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_dienststelle        IS 'Kataloge: (NREO) "Dienststelle" enthält die Verschlüsselung von Dienststellen und ÖbVi/ÖbV, die Aufgaben der öffentlichen Verwaltung wahrnehmen, mit der entsprechenden Bezeichnung.';
COMMENT ON COLUMN ax_dienststelle.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_dienststelle.stellenart IS 'SAR "Stellenart" bezeichnet die Art der Stelle.';
COMMENT ON COLUMN ax_dienststelle.kennung    IS 'KEN "Kennung" dient zur Unterscheidung und Fortführung der verschiedenen Katalogarten (z.B. Behördenkatalog) innerhalb des Dienststellenkatalogs.';

COMMENT ON COLUMN ax_dienststelle.hat    IS '-> Beziehung zu ax_anschrift (0..1): ''Dienststelle'' hat eine Anschrift.';


-- V e r b a n d
-- -------------
-- Objektart: AX_Verband Kennung: 73012
-- "Verband" umfasst die Verbände, denen Gemeinden angehören (z.B. Planungsverbände) mit den entsprechenden Bezeichnungen.


-- L a g e b e z e i c h n u n g s - K a t a l o g e i n t r a g
-- --------------------------------------------------------------
-- Objektart: AX_LagebezeichnungKatalogeintrag Kennung: 73013
CREATE TABLE ax_lagebezeichnungkatalogeintrag (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schluesselgesamt character varying,
  bezeichnung character varying,
  land character varying,
  regierungsbezirk character varying,
  kreis character varying,
  gemeinde character varying,
  lage character varying, -- Straßenschlüssel
  CONSTRAINT ax_lagebezeichnungkatalogeintrag_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_lagebezeichnungkatalogeintrag','dummy',:alkis_epsg,'POINT',2);

CREATE UNIQUE INDEX ax_lagebezeichnungkatalogeintrag_gml ON ax_lagebezeichnungkatalogeintrag USING btree (gml_id, beginnt);

-- NRW: Nummerierung Strassenschluessel innerhalb einer Gemeinde
-- Die Kombination Gemeinde und Straßenschlüssel ist also ein eindeutiges Suchkriterium.
CREATE INDEX ax_lagebezeichnungkatalogeintrag_lage ON ax_lagebezeichnungkatalogeintrag USING btree (gemeinde, lage);

-- Suchindex (Verwendung in Navigations-Programm)
CREATE INDEX ax_lagebezeichnungkatalogeintrag_gesa ON ax_lagebezeichnungkatalogeintrag USING btree (schluesselgesamt);
CREATE INDEX ax_lagebezeichnungkatalogeintrag_bez  ON ax_lagebezeichnungkatalogeintrag USING btree (bezeichnung);

COMMENT ON TABLE  ax_lagebezeichnungkatalogeintrag              IS 'Kataloge: (NREO) "Lagebezeichnung Katalogeintrag" enthält die eindeutige Verschlüsselung von Lagebezeichnungen und Straßen innerhalb einer Gemeinde mit der entsprechenden Bezeichnung. (Straßentabelle)';
COMMENT ON COLUMN ax_lagebezeichnungkatalogeintrag.gml_id       IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_lagebezeichnungkatalogeintrag.lage         IS 'Straßenschlüssel';
COMMENT ON COLUMN ax_lagebezeichnungkatalogeintrag.bezeichnung  IS 'Straßenname';


--** Objektartengruppe: Geographische Gebietseinheiten
--   ===================================================================


-- Objektart: AX_Landschaft Kennung: 74001
-- "Landschaft" ist hinsichtlich des äußeren Erscheinungsbildes (Bodenformen, Bewuchs, Besiedlung, Bewirtschaftung) ein in bestimmter Weise geprägter Teil der Erdoberfläche.


-- k l e i n r ä u m i g e r   L a n d s c h a f t s t e i l
-- -----------------------------------------------------------
-- Objektart: AX_KleinraeumigerLandschaftsteil Kennung: 74002
CREATE TABLE ax_kleinraeumigerlandschaftsteil (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  landschaftstyp integer,
  name character varying,
  CONSTRAINT ax_kleinraeumigerlandschaftsteil_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_kleinraeumigerlandschaftsteil','wkb_geometry',:alkis_epsg,'POINT',2);

CREATE INDEX ax_kleinraeumigerlandschaftsteil_geom_idx   ON ax_kleinraeumigerlandschaftsteil USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_kleinraeumigerlandschaftsteil_gml ON ax_kleinraeumigerlandschaftsteil USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_kleinraeumigerlandschaftsteil        IS 'Geographische Gebietseinheiten: (REO) "kleinräumiger Landschaftsteil" ist ein kleinerer Teil der Erdoberfläche, der hinsichtlich des äußeren Erscheinungsbildes (Bodenformen, Bewuchs, Besiedlung, Bewirtschaftung) in bestimmter Weise geprägt ist.';
COMMENT ON COLUMN ax_kleinraeumigerlandschaftsteil.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_kleinraeumigerlandschaftsteil.landschaftstyp IS 'LTP "Landschaftstyp" beschreibt das Erscheinungsbild von "Kleinräumiger Landschaftsteil".';
COMMENT ON COLUMN ax_kleinraeumigerlandschaftsteil.name           IS 'NAM "Name" ist der Eigenname von "Kleinräumiger Landschaftsteil".';


-- W o h n p l a t z
-- -----------------------------------------------------------
-- Objektart: AX_Wohnplatz Kennung: 74005
CREATE TABLE ax_wohnplatz (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  name character varying,
  zweitname character varying,
  CONSTRAINT ax_wohnplatz_pk PRIMARY KEY (ogc_fid)
);
SELECT AddGeometryColumn('ax_wohnplatz','wkb_geometry',:alkis_epsg,'POINT',2);

CREATE INDEX ax_wohnplatz_geom_idx   ON ax_wohnplatz USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_wohnplatz_gml ON ax_wohnplatz USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_wohnplatz        IS 'Geographische Gebietseinheiten: (REO) "Wohnplatz" ist ein bewohntes Gebiet, das einen Eigennamen trägt.';
COMMENT ON COLUMN ax_wohnplatz.gml_id IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_wohnplatz.name   IS 'NAM "Name" ist der Eigenname, amtlicher Wohnplatzname von "Wohnplatz".';
COMMENT ON COLUMN ax_wohnplatz.zweitname IS 'ZNM "Zweitname" ist ein volkstümlicher Name insbesondere bei Objekten außerhalb von Ortslagen.';


--** Objektartengruppe: Administrative Gebietseinheiten
--   ===================================================================
-- Kennung '75000'


-- B a u b l o c k
-- ----------------------------------------------
-- Objektart: AX_Baublock Kennung: 75001
CREATE TABLE ax_baublock (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  baublockbezeichnung character varying,
  art integer,
  CONSTRAINT ax_baublock_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_baublock','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_baublock_geom_idx   ON ax_baublock USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_baublock_gml ON ax_baublock USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_baublock        IS 'Administrative Gebietseinheiten: (REO) "Blaubock" war eine Unterhaltungsshow des Hessischen Rundfunks im Deutschen Fernsehen, von der zwischen 1957 und 1987 insgesamt 208 Folgen produziert wurden. Der Sendetitel war "Zum Blauen Bock".';

COMMENT ON COLUMN ax_baublock.gml_id IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_baublock.baublockbezeichnung IS 'BBZ "Baublockbezeichnung" ist die von der Gemeinde vergebene eindeutige Bezeichnung eines Teils des Gemeindegebietes.';
COMMENT ON COLUMN ax_baublock.art    IS 'ART "Art" ist die Art der Baublockfläche.';


-- w i r t s c h a f t l i c h e   E i n h e i t
-- ---------------------------------------------
-- Objektart: AX_WirtschaftlicheEinheit Kennung: 75002
CREATE TABLE ax_wirtschaftlicheeinheit (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  CONSTRAINT ax_wirtschaftlicheeinheit_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_wirtschaftlicheeinheit','dummy',:alkis_epsg,'POINT',2);

COMMENT ON TABLE  ax_wirtschaftlicheeinheit  IS 'Administrative Gebietseinheiten: (ZUSO) "Wirtschaftliche Einheit" ist eine in der Örtlichkeit vorhandene wirtschaftliche Einheit mehrerer Flurstücke, die nicht mit der rechtlichen Einheit (Grundstück im rechtlichen Sinn) identisch sein muss (Beispiel: Wirtschaftliche Einheit zweier Flurstücke/Grundstücke, wobei nur ein Flurstück ein Erbbaugrundstück ist).';


-- K o m m u n a l e s   G e b i e t
-- ----------------------------------------------
-- Objektart: AX_KommunalesGebiet Kennung: 75003
CREATE TABLE ax_kommunalesgebiet (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  schluesselgesamt character varying,
  land character varying,
  regierungsbezirk character varying,
  kreis character varying,
  gemeinde character varying,
  gemeindeflaeche double precision,
  CONSTRAINT ax_kommunalesgebiet_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_kommunalesgebiet','wkb_geometry',:alkis_epsg,'GEOMETRY',2);

CREATE INDEX ax_kommunalesgebiet_geom_idx   ON ax_kommunalesgebiet USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_kommunalesgebiet_gml ON ax_kommunalesgebiet USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_kommunalesgebiet        IS 'Administrative Gebietseinheiten: (REO) "Kommunales Gebiet" ist ein Teil der Erdoberfläche, der von einer festgelegten Grenzlinie umschlossen ist und den politischen Einflussbereich einer Kommune repräsentiert (z.B. Stadt-, Landgemeinde, gemeindefreies Gebiet).';
COMMENT ON COLUMN ax_kommunalesgebiet.gml_id IS 'Identifikator, global eindeutig';


-- abstrakte Objektart: AX_Gebiet Kennung: 75010


--*** ############################################################
--*** Objektbereich: Nutzerprofile
--*** ############################################################


--** Objektartengruppe: Nutzerprofile
--   ===================================================================
-- Kennung '81000'

-- Objektart: AX_Benutzer Kennung: 81001
-- In der Objektart 'Benutzer' werden allgemeine Informationen über den Benutzer verwaltet.

-- Objektart: AX_Benutzergruppe Kennung: 81002

-- Objektart: AX_BenutzergruppeMitZugriffskontrolle Kennung: 81003
-- In der Objektart 'Benutzergruppe mit Zugriffskontrolle' werden Informationen über die Benutzer der ALKIS-Bestandsdaten verwaltet, die den Umfang der Benutzung und Fortführung aus Gründen der Datenkonsistenz und des Datenschutzes einschränken.

-- Objektart: AX_BenutzergruppeNBA Kennung: 81004
-- In der Objektart 'Benutzergruppe (NBA)' werden relevante Informationen für die Durchführung der NBA-Versorgung, z.B. die anzuwendenden Selektionskriterien, gespeichert.
--  Eine gesonderte Prüfung der Zugriffsrechte erfolgt in diesem Fall nicht, deren Berücksichtigung ist von dem Administrator bei der Erzeugung und Pflege der NBA-Benutzergruppen sicherzustellen.


--*** ############################################################
--*** Objektbereich: Migration
--*** ############################################################

--** Objektartengruppe: Migrationsobjekte
--   ===================================================================
-- Kennung '91000'


-- G e b ä u d e a u s g e s t a l t u n g
-- -----------------------------------------
-- Objektart: AX_Gebaeudeausgestaltung Kennung: 91001
CREATE TABLE ax_gebaeudeausgestaltung (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  darstellung integer,
  zeigtauf character varying, --> ax_gebaeude
  CONSTRAINT ax_gebaeudeausgestaltung_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_gebaeudeausgestaltung','wkb_geometry',:alkis_epsg,'GEOMETRY',2);  -- LINESTRING/MULTILINESTRING

CREATE INDEX ax_gebaeudeausgestaltung_geom_idx   ON ax_gebaeudeausgestaltung USING gist (wkb_geometry);
CREATE UNIQUE INDEX ax_gebaeudeausgestaltung_gml ON ax_gebaeudeausgestaltung USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_gebaeudeausgestaltung          IS 'Migrationsobjekte: (REO) "Gebäudeausgestaltung" dient zur Speicherung von Gebäudeausgestaltungslinien, wenn eine Objektbildung im Zuge der Migration nicht möglich ist.';
COMMENT ON COLUMN ax_gebaeudeausgestaltung.gml_id   IS 'Identifikator, global eindeutig';
COMMENT ON COLUMN ax_gebaeudeausgestaltung.zeigtauf IS '-> Beziehung zu ax_gebaeude (1): ''Gebäudeausgestaltung'' zeigt auf die zugehörige Objektart ''Gebäude''.';


-- T o p o g r a p h i s c h e   L i n i e
-- ---------------------------------------
-- Objektart: AX_TopographischeLinie Kennung: 91002
CREATE TABLE ax_topographischelinie (
  ogc_fid serial NOT NULL,
  gml_id character(16) NOT NULL,
--identifier character varying,
  beginnt character(20),
  endet character(20),
  advstandardmodell character varying[],
  sonstigesmodell character varying[],
  anlass character varying,
  liniendarstellung integer,
  sonstigeeigenschaft character varying,
  CONSTRAINT ax_topographischelinie_pk PRIMARY KEY (ogc_fid)
);

SELECT AddGeometryColumn('ax_topographischelinie','wkb_geometry',:alkis_epsg,'GEOMETRY',2); -- LINESTRING/MULTILINESTRING

CREATE INDEX ax_topographischelinie_geom_idx   ON ax_topographischelinie USING gist  (wkb_geometry);
CREATE UNIQUE INDEX ax_topographischelinie_gml ON ax_topographischelinie USING btree (gml_id, beginnt);

COMMENT ON TABLE  ax_topographischelinie        IS 'Migrationsobjekte: (REO) "Topographische Linie" ist eine topographische Abgrenzungslinie ohne Objektbedeutung, die Übergangsweise im Rahmen der Migration aus bestehenden Verfahrenslösungen benötigt wird.';
COMMENT ON COLUMN ax_topographischelinie.gml_id IS 'Identifikator, global eindeutig';

COMMENT ON COLUMN ax_topographischelinie.liniendarstellung   IS 'LDS "Liniendarstellung" bezeichnet die Art der Liniendarstellung. Diese Information wird aus bestehenden Verfahrenslösungen übernommen Die Attributart ist nur im Rahmen der Migration zulässig.';
COMMENT ON COLUMN ax_topographischelinie.sonstigeeigenschaft IS 'SOE "Sonstige Eigenschaft" sind Informationen zur topographischen Linie';


-- Schlüsseltabelle "advstandardmodell" (9):
-- ----------------------------------------
-- LiegenschaftskatasterModell = DLKM
-- KatasterkartenModell500     = DKKM500
-- KatasterkartenModell1000    = DKKM1000
-- KatasterkartenModell2000    = DKKM2000
-- KatasterkartenModell5000    = DKKM5000
-- BasisLandschaftsModell      = Basis-DLM
-- LandschaftsModell50         = DLM50
-- LandschaftsModell250        = DLM250
-- LandschaftsModell1000       = DLM1000
-- TopographischeKarte10       = DTK10
-- TopographischeKarte25       = DTK25
-- TopographischeKarte50       = DTK50
-- TopographischeKarte100      = DTK100
-- TopographischeKarte250      = DTK250
-- TopographischeKarte1000     = DTK1000
-- Festpunktmodell             = DFGM
-- DigitalesGelaendemodell2    = DGM2
-- DigitalesGelaendemodell5    = DGM5
-- DigitalesGelaendemodell25   = DGM25
-- Digitales Gelaendemodell50  = DGM50


-- Wenn schon, dann auch alle Tabellen mit Kommentaren versehen:
-- COMMENT ON TABLE geometry_columns IS 'Metatabelle der Geometrie-Tabellen, Tabellen ohne Geometrie bekommen Dummy-Eintrag für PostNAS-Konverter (GDAL/OGR)';
-- COMMENT ON TABLE spatial_ref_sys  IS 'PostGIS: Koordinatensysteme und ihre Projektionssparameter';

--
--          THE  (happy)  END
--
