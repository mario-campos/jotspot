module checks.pxlint004;

import d2sqlite3;
import plexlint.database;

/// PXLINT004
///
/// PXLINT004 checks for movie files whose metadata does not match its directory.
ResultRange checkPXLINT004(PlexlintDatabase db)
{
    return db.conn.execute("
        SELECT f.file_path
        FROM files d
            JOIN movies dm ON d.file_id = dm.file_id
            JOIN files f ON d.file_id = f.directory_id
            JOIN movies fm ON f.file_id = fm.file_id
        WHERE dm.title != fm.title
            OR dm.release_year != fm.release_year
            OR dm.edition != fm.edition
    ");
}

unittest
{
    auto path = "/foo/bar/qux.mkv";
    auto db = new PlexlintDatabase();
    db.insertFile(1, "", "", 0, 1000, 1000, true, true, true, true, true, true, true, true, true, true);
    db.insertMovie(1, Movie("foo", 2020, ""));
    db.insertFile(1, "", path, 1, 1000, 1000, true, true, true, true, true, true, true, true, true, false);
    db.insertMovie(2, Movie("foo", 2021, ""));
    assert(db.queryPXLINT004().oneValue!string == path);
}