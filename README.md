# jotspot [![D](https://github.com/mario-campos/jotspot/actions/workflows/d.yml/badge.svg)](https://github.com/mario-campos/jotspot/actions/workflows/d.yml)

jotspot is a command-line tool for scanning Plex library directories for potential problems. jotspot tries to identify files and directories that do not conform to Plex’s recommended layout and naming conventions.

It couldn't be easier to use jotspot! Once compiled, simply supply one or more movie-library root directories with the `-m` flag.

```shell
$ jotspot -m /path/to/movies
jot001  /path/to/movies/my_empty_folder
jot002  /path/to/movies/movie.mkv
```

The output is be a tab-separated value of two "columns": the first contains the check ID&mdash;it's meaning can be referenced at the [homepage](https://mario-campos.github.io/software/jotspot/). The second column contains the problematic movie file/folder to which the check is referring.

## USAGE

```
jotspot -m|--movies PATH
jotspot -v|--version
jotspot -h|--help
```

## FLAGS

`-m`, `--movies`
* Specify a path to a movie library root directory. More than one of these flags can be passed.

`-V`, `--version`
* Output the version number.

`-h`, `--help`
* Output the usage and flags.

## BUILD

jotspot is written in the D programming language, which means you need [dub](https://dub.pm/) to compile jotspot:

```
dub build
```

## SUPPORTED OPERATING SYSTEMS

* Linux
* FreeBSD

## CAVEATS

Currently, jotspot is limited to linting movies, but the goal is to eventually be able to lint TV shows and music as well.
