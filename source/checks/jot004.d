module checks.jot004;

import core.sys.posix.sys.stat;
import std.conv;
import std.range;
import std.random;
import d2sqlite3;
import jotspot.database;

/// jot004
///
/// jot004 checks for directories that have a permission other than 0755.
ResultRange checkJot004(JotspotDatabase db)
{
	return db.conn.execute("
		SELECT file_path
		FROM files
		WHERE is_directory AND
		NOT (
			is_owner_readable AND
			is_owner_writable AND
			is_owner_executable AND
			is_group_readable AND
			NOT is_group_writable AND
			is_group_executable AND
			is_other_readable AND
			NOT is_other_writable AND
			is_other_executable
		)
	");
}

unittest
{
	auto wrongPermission = chain(iota(std.conv.octal!"755"), iota(std.conv.octal!"756", std.conv.octal!"777")).choice();
	auto path = "/foo";
	auto db = new JotspotDatabase();
	db.insertDirectory(1, "", path, 0, 1000, 1000, wrongPermission);
	assert(checkJot004(db).oneValue!string == path);
}

// Tests that a directory with permission 0755 is NOT returned by checkJot004.
unittest
{
	auto db = new JotspotDatabase();
	db.insertDirectory(1, "", "", 0, 1000, 1000, S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
	assert(checkJot004(db).empty);
}