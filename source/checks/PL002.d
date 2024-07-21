module checks.PL002;

import d2sqlite3;
import plexlint.database;

/// PL002
/// 
/// PL002 checks for the existence of movie files at the root of the library.
/// Plex recommends organizing movies into their own individual directories under the
/// library root.
///
/// Source: https://support.plex.tv/articles/naming-and-organizing-your-movie-media-files/
ResultRange checkPL002(PlexlintDatabase db)
{
    return db.conn.execute(
        "SELECT file_path FROM files WHERE NOT is_directory AND file_depth = 1");
}

unittest
{
	auto path = "/foo";
	auto db = new PlexlintDatabase();
	db.insertFile(1, "", path, 1, 1000, 1000, true, true, true, true, true, true, true, true, true, false);
	assert(checkPL002(db).oneValue!string == path);
}