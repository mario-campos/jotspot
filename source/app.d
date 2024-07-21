import core.stdc.stdlib : exit;
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

import plexlint.database;
import checks.PL001;
import checks.PL002;

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

	foreach (Row row; checkPL001(db))
		writeln("PXLINT001 ", row["file_path"].as!string);
	foreach (Row row; checkPL002(db))
		writeln("PXLINT002 ", row["file_path"].as!string);
}
