# plexlint [![D](https://github.com/mario-campos/plexlint/actions/workflows/d.yml/badge.svg)](https://github.com/mario-campos/plexlint/actions/workflows/d.yml)

plexlint is a command-line tool for scanning Plex library directories for potential problems. plexlint tries to identify files and directories that do not conform to Plex’s recommended layout and naming conventions.

It couldn't be easier to use plexlint! Once compiled, simply supply one or more movie-library root directories with the `-m` flag.

```shell
$ plexlint -m /path/to/movies
PXLINT001  /path/to/movies/my_empty_folder
```

The output is be a tab-separated value of two "columns": the first contains the check ID&mdash;it's meaning can be referenced at the [homepage](https://mario-campos.github.io/software/plexlint/). The second column contains the problematic movie file/folder to which the check is referring.

### BUILD

plexlint is written in the D programming language, which means you need [dub](https://dub.pm/) to compile plexlint.

```
dub build
```

### CAVEATS

Currently, plexlint is limited to linting movies, but the goal is to eventually be able to lint TV shows and music as well.

Due to my own needs, plexlint is designed only for GNU/Linux and FreeBSD&mdash;YMMV for Windows and macOS.
