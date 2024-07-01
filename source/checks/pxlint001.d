module checks.pxlint001;

import d2sqlite3;
import plexlint.database;

/// PXLINT001
///
/// PXLINT001 checks for the existance of empty directories. Empty directories
/// serve no purpose to Plex and may only create the "illusion" of a legitimate
/// movie in Plex.
ResultRange checkPXLINT001(PlexlintDatabase db)
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
	auto db = new PlexlintDatabase();
	db.insertFile(1, "", "", 0, 1000, 1000, true, true, true, true, true, true, true, true, true, true);
	db.insertFile(1, "", path, 1, 1000, 1000, true, true, true, true, true, true, true, true, true, true);
	assert(checkPXLINT001(db).oneValue!string == path);
}