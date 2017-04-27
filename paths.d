
// ref: https://dlang.org/phobos/std_path.html

import io = std.stdio : write, writeln, writefln;
import re = std.regex : regex, replaceAll, split;
import std.path : pathSeparator, pathSplitter, isValidPath;
import std.string : strip, chomp, toLower;
import std.format : format;
import std.array : array, join;
import std.algorithm.iteration : map, filter;
import std.algorithm.searching : canFind;
import std.algorithm.comparison : equal;
import core.stdc.stdlib : exit;

static immutable HELPTEXT = format("  %s", strip("
  \033[1;4mpaths 0.0.1\033[0m

    A utility for manipulating paths ($PATH, $MANPATH, $INFOPATH, etc.)
    Copyright (c) 2017 kafene software (https://kafene.org/), MIT Licensed.
    Latest version available at <https://github.com/kafene/paths>.

  \033[1mUsage\033[0m:
    paths [help]
          [version]
          [normalize-dir] <dir>
          [normalize]     <path>
          [split]         <path>
          [filter]        <path>
          [has]           <path> <dir>
          [prepend]       <path> <dir>...
          [append]        <path> <dir>...

  \033[1mnormalize-dir\033[0m - Normalize a directory.
    $ paths normalize-dir \"//foo//bar/baz///\"
    > /foo/bar/baz

  \033[1mnormalize\033[0m - Normalize a path.
    $ paths normalize \":/bin/::/usr/bin\"
    > /bin:/usr/bin

  \033[1msplit\033[0m - Split a path.
    $ paths split \":/bin/:://a:/usr/bin\"
    > /bin /a /usr/bin

  \033[1mfilter\033[0m - Removes duplicates and non-existent dirs.
    $ paths filter \"/bin:/opt/atom//:/usr/bin:/usr/fake:/opt/atom\"
    > /bin:/opt/atom:/usr/bin

  \033[1mhas\033[0m - Check if the given dir appears in the given path.
    $ paths has \"/bin:/usr/bin/\" \"/usr/bin\"; echo $?;
    > 0

  \033[1mprepend\033[0m - Prepend the given dir(s) to the path.
    $ paths prepend \"/bin\" \"/usr/bin\" \"/usr/share/go/bin\"
    > /usr/share/go/bin:/usr/bin:/bin

  \033[1mappend\033[0m - Append the given dir(s) to the path.
    $ paths append \"/bin\" \"/usr/bin/\" \"/usr/fake\" \"/opt/atom\"
    > /bin:/usr/bin:/usr/fake:/opt/atom
"));

// Deduplicates (i.e. makes unique) the values in "items"
// @see <https://forum.dlang.org/post/wisybtkdxfitbwsbkttk@forum.dlang.org>
T[] dedupe(T)(in T[] items)
{
    T[] result;

    foreach (T item; items) {
        if (!result.canFind(item)) {
            result ~= item;
        }
    }

    return result;
}

string dir_normalize(string dir)
{
    dir = strip(dir);
    // dir = re.replaceAll(dir, re.regex(r"\\/+", "g"), "/");
    dir = re.replaceAll(dir, re.regex("\\/+", "g"), "/");
    dir = dir == "/" ? dir : chomp(dir, "/");

    return dir;
}

string[] _path_split(string path)
{
    return re.split(path, re.regex("\\s*" ~ pathSeparator ~ "\\s*"));
}

string path_split(string path)
{
    path = path_normalize(path);

    string[] path_parts = _path_split(path);
    path_parts = array(path_parts.map!(part => replaceAll(part, re.regex("(\\s)", "g"), "\\$1")));

    path = path_parts.join(" ");

    return path;
}

string path_normalize(string path)
{
    path = strip(path);
    path = re.replaceAll(path, re.regex("(?:^:+|:+$)"), "");
    path = re.replaceAll(path, re.regex(":+", "g"), ":");

    string[] path_parts = _path_split(path);
    path_parts = array(path_parts.map!(dir_normalize));

    path = join(path_parts, pathSeparator);

    assert(isValidPath(path));

    return path;
}

string path_filter(string path)
{
    import fs = std.file : isDir, exists;

    path = path_normalize(path);

    string[] path_parts = _path_split(path);
    path_parts = array(path_parts.filter!(part => fs.exists(part) && fs.isDir(part)));
    path_parts = path_parts.dedupe();

    path = join(path_parts, pathSeparator);

    assert(isValidPath(path));

    return path;
}

bool path_has(string path, string dir)
{
    path = path_normalize(path);
    dir = dir_normalize(dir);

    string[] path_parts = _path_split(path);

    return path_parts.filter!(p => p.length > 0).canFind(dir);
}

string path_prepend(string path, string[] dirs)
{
    path = path_normalize(path);

    string[] path_parts = _path_split(path);

    foreach (string dir; dirs.map!(dir_normalize)) {
        if (!path_parts.canFind(dir)) {
            path_parts = [dir] ~ path_parts;
        }
    }

    path = join(path_parts, pathSeparator);

    assert(isValidPath(path));

    return path;
}

string path_append(string path, string[] dirs)
{
    path = path_normalize(path);

    string[] path_parts = _path_split(path);

    foreach (string dir; dirs.map!(dir_normalize)) {
        if (!path_parts.canFind(dir)) {
            path_parts ~= [dir];
        }
    }

    path = join(path_parts, pathSeparator);

    assert(isValidPath(path));

    return path;
}

void show_error(string err_msg)
{
    io.writefln("  \033[1mError:\033[0m %s\n         Use --help for help.", err_msg);
    exit(1);
}

void check_min_args_length(ulong args_length, int min_length, string err_msg)
{
    if (args_length < min_length) {
        show_error(err_msg);
    }
}

unittest
{
    import core.exception : AssertError;

    string path;
    string expected;
    string actual;

    try {
        path = ":/bin/:://a:/usr/bin:::á, é, ü/ñ@¿://bin://foo//bar/baz///";
        expected = "/bin:/a:/usr/bin:á, é, ü/ñ@¿:/bin:/foo/bar/baz";
        actual = path_normalize(path);
        assert(equal(expected, actual));

        path = ":/bin/:://a:/usr/bin:::á,   é, ü/ñ@¿://bin://foo//bar/baz///";
        expected = "/bin /a /usr/bin á,\\ \\ \\ é,\\ ü/ñ@¿ /bin /foo/bar/baz";
        actual = path_split(path);
        assert(equal(expected, actual));

        path = ":/bin/:://a:/usr/bin:::á, é, ü/ñ@¿://bin://foo//bar/baz///";
        expected = "/bin:/usr/bin";
        actual = path_filter(path);
        assert(equal(expected, actual));

        path = ":/bin/:://a:/usr/bin:::á, é, ü/ñ@¿://bin://foo//bar/baz///";
        assert(path_has(path, "á, é, ü/ñ@¿") == true);

        path = ":/bin/:://a:/usr/bin:::á, é, ü/ñ@¿://bin://foo//bar/baz///";
        expected = "/foo:/bin:/a:/usr/bin:á, é, ü/ñ@¿:/bin:/foo/bar/baz";
        actual = path_prepend(path, ["/foo/"]);
        assert(equal(expected, actual));

        path = ":/bin/:://a:/usr/bin:::á, é, ü/ñ@¿://bin://foo//bar/baz///";
        expected = "/bin:/a:/usr/bin:á, é, ü/ñ@¿:/bin:/foo/bar/baz:/bar:baz";
        actual = path_append(path, ["/bar/", "baz/"]);
        assert(equal(expected, actual));
    } catch (AssertError ex) {
        writefln("PATH     = %s", path);
        writefln("EXPECTED = %s", expected);
        writefln("ACTUAL   = %s", actual);

        throw ex;
    }
}

void main(string[] args)
{
    // args[0] is the path to this program.
    check_min_args_length(args.length, 2, "No command specified.");

    string cmd = toLower(args[1]);

    if (["help", "-h", "--h", "-help", "--help"].canFind(cmd)) {
        io.writeln(HELPTEXT);
        exit(0);
    }
    if (["version", "-v", "--v", "-version", "--version"].canFind(cmd)) {
        io.writeln(HELPTEXT);
        exit(0);
    }

    check_min_args_length(args.length, 3, "No arguments specified.");

    args = args[2..$];

    switch (cmd)
    {
        case "normalize-dir":
        {
            string dir = args[0];
            io.write(dir_normalize(dir));
            break;
        }
        case "normalize":
        {
            string path = args[0];
            io.write(path_normalize(path));
            break;
        }
        case "split":
        {
            string path = args[0];
            io.write(path_split(path));
            break;
        }
        case "filter":
        {
            string path = args[0];
            io.write(path_filter(path));
            break;
        }
        case "has":
        {
            check_min_args_length(args.length, 2, "No 'dir' specified.");
            string path = args[0];
            string dir = args[1];
            exit(path_has(path, dir) ? 0 : 1);
            break;
        }
        case "prepend":
        {
            check_min_args_length(args.length, 2, "No 'dir' specified.");
            string path = args[0];
            string[] dirs = args[1..$];
            io.write(path_prepend(path, dirs));
            break;
        }
        case "append":
        {
            check_min_args_length(args.length, 2, "No 'dir' specified.");
            string path = args[0];
            string[] dirs = args[1..$];
            io.write(path_append(path, dirs));
            break;
        }
        default:
        {
            show_error("Invalid command.");
            break;
        }
    }

    exit(0);
}
