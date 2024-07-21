module checks.PL003;

import d2sqlite3;
import plexlint.database;

/// PL003
///
/// PL003 checks for movie files that are not readable by the Plex user.
ResultRange checkPL003(PlexlintDatabase db, uint plex_uid, uint plex_gid)
{
    auto statement = db.conn.prepare("
        SELECT file_path FROM files WHERE NOT (
            (owner_id = :uid AND is_owner_readable)
            OR
            (group_id = :gid AND is_group_readable)
            OR
            is_other_readable
        )
    ");
    statement.bind(":uid", plex_uid);
    statement.bind(":gid", plex_gid);
    return statement.execute();
}

unittest
{
	auto path = "/foo";
	auto plex_id = 1000;
	auto db = new PlexlintDatabase();
	db.insertFile(1, "", "", 0, plex_id, plex_id, true, true, true, true, true, true, true, true, true, true);
	db.insertFile(1, "", path, 1, plex_id, plex_id, false, true, true, false, true, true, false, true, true, false);
	assert(checkPL003(db, plex_id, plex_id).oneValue!string == path);
}

unittest
{
	auto path = "/foo";
	auto plex_id = 1000;
	auto db = new PlexlintDatabase();
	db.insertFile(1, "", "", 0, plex_id, plex_id, true, true, true, true, true, true, true, true, true, true);
	db.insertFile(1, "", path, 1, 999u, 999u, true, true, true, true, true, true, false, false, false, false);
	assert(checkPL003(db, plex_id, plex_id).oneValue!string == path);
}