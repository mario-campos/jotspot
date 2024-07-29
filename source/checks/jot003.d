module checks.jot003;

import d2sqlite3;
import jotspot.database;

/// jot003
///
/// jot003 checks for files that have a permission other than 0444.
ResultRange checkJot003(JotspotDatabase db)
{
    return db.conn.execute("
        SELECT file_path
        FROM files
        WHERE NOT is_directory AND
        NOT (
            is_owner_readable AND
            NOT is_owner_writable AND
            NOT is_owner_executable AND
            is_group_readable AND
            NOT is_group_writable AND
            NOT is_group_executable AND
            is_other_readable AND
            NOT is_other_writable AND
            NOT is_other_executable
        )
    ");
}

unittest
{
	auto path = "/foo";
	auto db = new JotspotDatabase();
	db.insertDirectory(1, "", "", 0, 0, 0, true, true, true, true, true, true, true, true, true);
	db.insertFile(1, "", path, 1, 0, 0, false, false, false, false, false, false, false, false, false);
	assert(checkJot003(db).oneValue!string == path);
}

// Tests that a file with permission 0444 is NOT returned by checkJot003.
unittest
{
	auto db = new JotspotDatabase();
	db.insertDirectory(1, "", "", 0, 0, 0, true, true, true, true, true, true, true, true, true);
	db.insertFile(1, "", "", 1, 0, 0, true, false, false, true, false, false, true, false, false);
	assert(checkJot003(db).empty);
}