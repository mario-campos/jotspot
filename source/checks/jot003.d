module checks.jot003;

import core.sys.posix.sys.stat;
import std.conv;
import std.range;
import std.random;
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
	auto wrongPermission = chain(iota(std.conv.octal!"444"), iota(std.conv.octal!"445", std.conv.octal!"777")).choice();
	auto path = "/foo";
	auto db = new JotspotDatabase();
	db.insertDirectory(1, "", "", 0, 1000, 1000);
	db.insertFile(1, "", path, 1, 1000, 1000, wrongPermission);
	assert(checkJot003(db).oneValue!string == path);
}

// Tests that a file with permission 0444 is NOT returned by checkJot003.
unittest
{
	auto db = new JotspotDatabase();
	db.insertDirectory(1, "", "", 0, 1000, 1000);
	db.insertFile(1, "", "", 1, 1000, 1000, S_IRUSR | S_IRGRP | S_IROTH);
	assert(checkJot003(db).empty);
}