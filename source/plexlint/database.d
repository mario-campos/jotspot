module plexlint.database;

import core.sys.posix.sys.stat;
import d2sqlite3;
import std.path;
import std.file;
import std.sumtype;
import std.typecons : Nullable;

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
}