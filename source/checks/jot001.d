module checks.jot001;

import d2sqlite3;
import jotspot.database;

/// jot001
///
/// jot001 checks for the existance of empty directories. Empty directories
/// serve no purpose to Plex and may only create the "illusion" of a legitimate
/// movie in Plex.
ResultRange checkJot001(JotspotDatabase db)
{
	return db.conn.execute("
		SELECT d.file_path
		FROM files d LEFT JOIN files f ON d.file_id = f.directory_id
		WHERE d.is_directory AND f.directory_id IS NULL
	");
}

unittest
{
	auto path = "/foo";
	auto db = new JotspotDatabase();
	db.insertDirectory(1, "", "", 0, 1000, 1000);
	db.insertDirectory(1, "", path, 1, 1000, 1000);
	assert(checkJot001(db).oneValue!string == path);
}