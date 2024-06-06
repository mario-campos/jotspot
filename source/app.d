import core.stdc.stdlib : exit;
import core.sys.posix.sys.stat;
import std.array;
import std.conv;
import std.file;
import std.format;
import std.getopt;
import std.path;
import std.random : choice;
import std.range : iota;
import std.regex;
import std.stdio;
import std.sumtype;
import std.typecons : Nullable;

import d2sqlite3;

alias PlexFile = SumType!(Movie, MovieExtra, UnknownFile);

struct Movie
{
	string title;
	int release_year;
	string edition;
}

struct MovieExtra
{
	string name;
	string type;
}

struct UnknownFile
{
}

PlexFile parsePlexMovieFile(string filename)
{
	auto r = regex(
		r"^(.*)-(behindthescenes|deleted|featurette|interview|scene|short|trailer|other)\.\w{1,4}$");
	if (auto capture = matchFirst(filename, r))
		return PlexFile(MovieExtra(capture[1], capture[2]));
	if (auto capture = matchFirst(filename, r"^(.*) \((\d{4})\)\.\w{1,4}$"))
		return PlexFile(Movie(capture[1], capture[2].to!int, ""));
	if (auto capture = matchFirst(filename, r"^(.*) \((\d{4})\) \{edition-(\w+)\}\.\w{1,4}$"))
		return PlexFile(Movie(capture[1], capture[2].to!int, capture[3]));
	return PlexFile(UnknownFile());
}

unittest
{
	auto title = "foo";
	auto year = choice(iota(1900, 9999));
	auto ext = ["mkv", "avi", "mp4", "mov", "flv", "wmv", "webm", "m4v", "rmvb"].choice();
	assert(
		parsePlexMovieFile(format("%s (%d).%s", title, year, ext))
			.match!(
				(Movie m) => m.title == title && m.release_year == year,
				_ => false,
			)
	);
}

unittest
{
	auto title = "Movie Title 2: subtitle";
	auto year = choice(iota(1900, 9999));
	auto edition = "unrated";
	auto ext = ["mkv", "avi", "mp4", "mov", "flv", "wmv", "webm", "m4v", "rmvb"].choice();
	assert(
		parsePlexMovieFile(format("%s (%d) {edition-%s}.%s", title, year, edition, ext))
			.match!(
				(Movie m) => m.title == title && m.release_year == year && m.edition == edition,
				_ => false,
			)
	);
}

unittest
{
	auto name = "foo";
	auto type = [
		"behindthescenes", "deleted", "featurette", "interview", "scene", "short",
		"trailer", "other"
	].choice();
	auto ext = ["mkv", "avi", "mp4", "mov", "flv", "wmv", "webm", "m4v", "rmvb"].choice();
	assert(
		parsePlexMovieFile(format("%s-%s.%s", name, type, ext))
			.match!(
				(MovieExtra me) => me.name == name && me.type == type,
				_ => false,
			)
	);
}

unittest
{
	auto ext = ["mkv", "avi", "mp4", "mov", "flv", "wmv", "webm", "m4v", "rmvb"].choice();
	assert(
		parsePlexMovieFile("amdfvdf4oi3ue2e2vagkeowe2r." ~ ext)
			.match!(
				(UnknownFile f) => true,
				_ => false,
			)
	);
}

class PlexlintDatabase
{
	Database conn;
	Statement psInsertFile;
	Statement psInsertMovie;
	Statement psInsertMovieExtra;
	this()
	{
		conn = Database(":memory:");
		conn.run("
			CREATE TABLE files (
				file_id INTEGER PRIMARY KEY,
				directory_id INTEGER NOT NULL,
				file_name TEXT NOT NULL,
				file_path TEXT NOT NULL,
				file_depth INTEGER NOT NULL,
				owner_id INTEGER NOT NULL,
				group_id INTEGER NOT NULL,
				is_owner_readable BOOL NOT NULL,
				is_owner_writable BOOL NOT NULL,
				is_owner_executable BOOL NOT NULL,
				is_group_readable BOOL NOT NULL,
				is_group_writable BOOL NOT NULL,
				is_group_executable BOOL NOT NULL,
				is_other_readable BOOL NOT NULL,
				is_other_writable BOOL NOT NULL,
				is_other_executable BOOL NOT NULL,
				is_directory BOOL NOT NULL,
				FOREIGN KEY(directory_id) REFERENCES files(file_id)
			);
			CREATE TABLE movies (
				file_id INTEGER PRIMARY KEY,
				title TEXT NOT NULL,
				release_year INTEGER NOT NULL,
				edition TEXT,
				FOREIGN KEY(file_id) REFERENCES files(file_id)
			) WITHOUT ROWID;
			CREATE TABLE movie_extras (
				file_id INTEGER PRIMARY KEY,
				name TEXT NOT NULL,
				type TEXT NOT NULL,
				FOREIGN KEY(file_id) REFERENCES files(file_id)
			) WITHOUT ROWID;
		");
		psInsertFile = conn.prepare("
			INSERT INTO files (
				directory_id,
				file_name,
				file_path,
				file_depth,
				owner_id,
				group_id,
				is_owner_readable, is_owner_writable, is_owner_executable,
				is_group_readable, is_group_writable, is_group_executable,
				is_other_readable, is_other_writable, is_other_executable,
				is_directory
			) VALUES (
				:directory_id,
				:file_name,
				:file_path,
				:file_depth,
				:owner_id,
				:group_id,
				:is_owner_readable, :is_owner_writable, :is_owner_executable,
				:is_group_readable, :is_group_writable, :is_group_executable,
				:is_other_readable, :is_other_writable, :is_other_executable,
				:is_directory
			)
		");
		psInsertMovie = conn.prepare("
			INSERT INTO movies (
				file_id, title, release_year, edition
			) VALUES (
				:file_id, :title, :release_year, :edition
			)
		");
		psInsertMovieExtra = conn.prepare("
			INSERT INTO movie_extras (file_id, name, type) VALUES (:file_id, :name, :type)
		");
	}

	long insertFileFromDirEntry(DirEntry de, long directoryID, uint fileDepth)
	{
		return insertFile(
			directoryID,
			baseName(de.name),
			de.name,
			fileDepth,
			de.statBuf.st_uid,
			de.statBuf.st_gid,
			cast(bool)(de.attributes & S_IRUSR),
			cast(bool)(de.attributes & S_IWUSR),
			cast(bool)(de.attributes & S_IXUSR),
			cast(bool)(de.attributes & S_IRGRP),
			cast(bool)(de.attributes & S_IWGRP),
			cast(bool)(de.attributes & S_IXGRP),
			cast(bool)(de.attributes & S_IROTH),
			cast(bool)(de.attributes & S_IWOTH),
			cast(bool)(de.attributes & S_IXOTH),
			de.isDir,
		);
	}

	long insertFile(
		long directoryID,
		string fileName,
		string filePath,
		int fileDepth,
		uint ownerID,
		uint groupID,
		bool isOwnerReadable,
		bool isOwnerWritable,
		bool isOwnerExecutable,
		bool isGroupReadable,
		bool isGroupWritable,
		bool isGroupExecutable,
		bool isOtherReadable,
		bool isOtherWritable,
		bool isOtherExecutable,
		bool isDirectory)
	{
		psInsertFile.reset();
		psInsertFile.clearBindings();
		psInsertFile.bind(":directory_id", directoryID);
		psInsertFile.bind(":file_name", fileName);
		psInsertFile.bind(":file_path", filePath);
		psInsertFile.bind(":file_depth", fileDepth);
		psInsertFile.bind(":owner_id", ownerID);
		psInsertFile.bind(":group_id", groupID);
		psInsertFile.bind(":is_owner_readable", isOwnerReadable);
		psInsertFile.bind(":is_owner_writable", isOwnerWritable);
		psInsertFile.bind(":is_owner_executable", isOwnerExecutable);
		psInsertFile.bind(":is_group_readable", isGroupReadable);
		psInsertFile.bind(":is_group_writable", isGroupWritable);
		psInsertFile.bind(":is_group_executable", isGroupExecutable);
		psInsertFile.bind(":is_other_readable", isOtherReadable);
		psInsertFile.bind(":is_other_writable", isOtherWritable);
		psInsertFile.bind(":is_other_executable", isOtherExecutable);
		psInsertFile.bind(":is_directory", isDirectory);
		psInsertFile.execute();
		return conn.lastInsertRowid();
	}

	long insertMovie(long file_id, Movie m)
	{
		psInsertMovie.reset();
		psInsertMovie.clearBindings();
		psInsertMovie.bind(":file_id", file_id);
		psInsertMovie.bind(":title", m.title);
		psInsertMovie.bind(":release_year", m.release_year);
		psInsertMovie.bind(":edition", m.edition == "" ? null : m.edition);
		psInsertMovie.execute();
		return conn.lastInsertRowid();
	}

	long insertMovieExtra(long file_id, MovieExtra me)
	{
		psInsertMovieExtra.reset();
		psInsertMovieExtra.clearBindings();
		psInsertMovieExtra.bind(":file_id", file_id);
		psInsertMovieExtra.bind(":name", me.name);
		psInsertMovieExtra.bind(":type", me.type);
		psInsertMovieExtra.execute();
		return conn.lastInsertRowid();
	}

	/// PXLINT001
	///
	/// PXLINT001 checks for the existance of empty directories. Empty directories
	/// serve no purpose to Plex and may only create the "illusion" of a legitimate
	/// movie in Plex.
	ResultRange queryPXLINT001()
	{
		return conn.execute("
			SELECT d.file_path
			FROM files d LEFT JOIN files f ON d.file_id = f.directory_id
			WHERE d.is_directory AND f.directory_id IS NULL
		");
	}

	/// PXLINT002
	/// 
	/// PXLINT002 checks for the existence of movie files at the root of the library.
	/// Plex recommends organizing movies into their own individual directories under the
	/// library root.
	///
	/// Source: https://support.plex.tv/articles/naming-and-organizing-your-movie-media-files/
	ResultRange queryPXLINT002()
	{
		return conn.execute(
			"SELECT file_path FROM files WHERE NOT is_directory AND file_depth = 1");
	}

	/// PXLINT003
	///
	/// PXLINT003 checks for movie files that are not readable by the Plex user.
	ResultRange queryPXLINT003(uint plex_uid, uint plex_gid)
	{
		auto statement = conn.prepare("
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

	/// PXLINT004
	///
	/// PXLINT004 checks for movie files whose metadata does not match its directory.
	ResultRange queryPXLINT004()
	{
		return conn.execute("
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
}

unittest
{
	auto path = "/foo";
	auto db = new PlexlintDatabase();
	db.insertFile(1, "", "", 0, 1000, 1000, true, true, true, true, true, true, true, true, true, true);
	db.insertFile(1, "", path, 1, 1000, 1000, true, true, true, true, true, true, true, true, true, true);
	assert(db.queryPXLINT001().oneValue!string == path);
}

unittest
{
	auto path = "/foo";
	auto db = new PlexlintDatabase();
	db.insertFile(1, "", path, 1, 1000, 1000, true, true, true, true, true, true, true, true, true, false);
	assert(db.queryPXLINT002().oneValue!string == path);
}

unittest
{
	auto path = "/foo";
	auto plex_id = 1000;
	auto db = new PlexlintDatabase();
	db.insertFile(1, "", "", 0, plex_id, plex_id, true, true, true, true, true, true, true, true, true, true);
	db.insertFile(1, "", path, 1, plex_id, plex_id, false, true, true, false, true, true, false, true, true, false);
	assert(db.queryPXLINT003(plex_id, plex_id).oneValue!string == path);
}

unittest
{
	auto path = "/foo";
	auto plex_id = 1000;
	auto db = new PlexlintDatabase();
	db.insertFile(1, "", "", 0, plex_id, plex_id, true, true, true, true, true, true, true, true, true, true);
	db.insertFile(1, "", path, 1, 999u, 999u, true, true, true, true, true, true, false, false, false, false);
	assert(db.queryPXLINT003(plex_id, plex_id).oneValue!string == path);
}

void addAllMovieFiles(PlexlintDatabase db, string path, long directory_id = 1, int depth = 0)
{
	directory_id = db.insertFileFromDirEntry(DirEntry(path), directory_id, depth++);
	foreach (DirEntry de; dirEntries(path, SpanMode.shallow))
	{
		if (de.isDir)
			addAllMovieFiles(db, de.name, directory_id, depth);
		else
		{
			auto file_id = db.insertFileFromDirEntry(de, directory_id, depth);
			parsePlexMovieFile(baseName(de.name)).match!(
				(Movie m) => db.insertMovie(file_id, m),
				(MovieExtra me) => db.insertMovieExtra(file_id, me),
				(UnknownFile) => 0,
			);
		}
	}
}

void main(string[] args)
{
	bool opt_version;
	string[] lib_movies_paths;
	auto opts = getopt(
		args,
		"m|movies", &lib_movies_paths,
		"v|version", &opt_version,
	);

	if (opts.helpWanted)
	{
		writeln(
			"usage: plexlint -m|--movies PATH\n",
			"       plexlint -v|--version\n",
			"       plexlint -h|--help"
		);
		exit(0);
	}

	if (opt_version)
	{
		writeln("plexlint-0.1.0");
		exit(0);
	}

	auto db = new PlexlintDatabase();
	foreach (path; lib_movies_paths)
		addAllMovieFiles(db, path);

	foreach (Row row; db.queryPXLINT001())
		writeln("PXLINT001 ", row["file_path"].as!string);
	foreach (Row row; db.queryPXLINT002())
		writeln("PXLINT002 ", row["file_path"].as!string);
}
