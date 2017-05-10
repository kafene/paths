
// ref: https://dlang.org/phobos/std_path.html

import io = std.stdio : write, writeln, writefln;
import re = std.regex : regex, replaceAll, split;
import std.path : pathSeparator, isValidPath;
import std.string : strip, chomp;
import std.array : array, join;
import std.algorithm.iteration : map, filter;
import std.algorithm.searching : canFind, startsWith;
import std.algorithm.comparison : equal;
import core.stdc.stdlib : exit;

// @see <http://docopt.org/>
// @see <https://github.com/docopt/docopt.d>
static immutable APP_DOC = "
    paths.

    A utility for manipulating paths ($PATH, $MANPATH, $INFOPATH, etc.)
    Copyright (c) 2017 kafene software (https://kafene.org/), MIT Licensed.
    Latest version available at <https://github.com/kafene/paths>.

    Usage:
        paths help
        paths version
        paths normalize-dir <dir>
        paths normalize     <path> [(-e | --existence)]
        paths split         <path>
        paths filter        <path>
        paths has           <path> <dir>
        paths prepend       <path> <dirs>...
        paths append        <path> <dirs>...
        paths join          <dirs>...

    Options:
        -h --help           Show this screen.
        --version           Show version.
        -e --existence      Ensure dirs in output path exist.
";

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

// Normalize the given dir.
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

// Split the given path into a newline-separated string of dirs.
string path_split(string path)
{
    path = path_normalize(path);

    string[] path_parts = _path_split(path);
    path = path_parts.join("\n");

    return path;
}

string path_join(string[] dirs)
{
    dirs = array(dirs.map!(dir_normalize));

    string path = dirs.join(pathSeparator);

    return path;
}

// Normalize the given path.
string path_normalize(string path)
{
    path = strip(path);
    path = re.replaceAll(path, re.regex("(?:^:+|:+$)"), "");
    path = re.replaceAll(path, re.regex(":+", "g"), ":");

    string[] path_parts = _path_split(path);
    path_parts = array(path_parts.map!(dir_normalize));

    path = path_parts.join(pathSeparator);

    assert(isValidPath(path));

    return path;
}

// Remove duplicate and non-existent dirs from the given path.
string path_filter(string path)
{
    import fs = std.file : isDir, exists;

    path = path_normalize(path);

    string[] path_parts = _path_split(path);
    path_parts = array(path_parts.filter!(part => fs.exists(part) && fs.isDir(part)));
    path_parts = path_parts.dedupe();

    path = path_parts.join(pathSeparator);

    assert(isValidPath(path));

    return path;
}

// Check if the given dir appears in the given path.
bool path_has(string path, string dir)
{
    path = path_normalize(path);
    dir = dir_normalize(dir);

    string[] path_parts = _path_split(path);

    return path_parts.filter!(p => p.length > 0).canFind(dir);
}

// Prepend the given dir(s) to the given path.
string path_prepend(string path, string[] dirs)
{
    path = path_normalize(path);

    string[] path_parts = _path_split(path);

    foreach (string dir; dirs.map!(dir_normalize)) {
        if (!path_parts.canFind(dir)) {
            path_parts = [dir] ~ path_parts;
        }
    }

    path = path_parts.join(pathSeparator);

    assert(isValidPath(path));

    return path;
}

// Append the given dir(s) to the path.
string path_append(string path, string[] dirs)
{
    path = path_normalize(path);

    string[] path_parts = _path_split(path);

    foreach (string dir; dirs.map!(dir_normalize)) {
        if (!path_parts.canFind(dir)) {
            path_parts ~= [dir];
        }
    }

    path = path_parts.join(pathSeparator);

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

    string path = "";
    string dir = "";
    string expected = "";
    string actual = "";
    string[] dirs;

    try {
        dir = "//foo//bar/baz///";
        expected = "/foo/bar/baz";
        actual = dir_normalize(dir);
        assert(equal(expected, actual));

        path = ":/bin/::/usr/bin";
        expected = "/bin:/usr/bin";
        actual = path_normalize(path);
        assert(equal(expected, actual));

        path = ":/bin/:://a\"dir\":/usr/bin";
        expected = ["/bin", "/a\"dir\"", "/usr/bin"].join("\n");
        actual = path_split(path);
        assert(equal(expected, actual));

        path = ":/bin/:://a\\  :/usr/bin";
        expected = ["/bin", "/a\\", "/usr/bin"].join("\n");
        actual = path_split(path);
        assert(equal(expected, actual));

        path = "/bin:/usr/bin:/usr/fake-dir:/opt/lol!n0t-there:/usr/bin//";
        expected = "/bin:/usr/bin";
        actual = path_filter(path);
        assert(equal(expected, actual));

        path = "/bin/ : /usr//bin/";
        dir = "/usr/bin";
        assert(path_has(path, dir));

        path = "/bin";
        dirs = ["/usr/bin", "/usr/share/go/bin/", "/usr/bin"];
        expected = "/usr/share/go/bin:/usr/bin:/bin";
        actual = path_prepend(path, dirs);
        assert(equal(expected, actual));

        path = "/bin";
        dirs = ["/usr/bin/", "/usr/share/go/bin/", "/usr/fake-dir", "/usr/bin", "/opt/atom"];
        expected = "/bin:/usr/bin:/usr/share/go/bin:/usr/fake-dir:/opt/atom";
        actual = path_append(path, dirs);
        assert(equal(expected, actual));

        path = ":/bin/:://a:/usr/bin:::á, é, ü/ñ@¿://bin://foo//bar/baz///";
        expected = "/bin:/a:/usr/bin:á, é, ü/ñ@¿:/bin:/foo/bar/baz";
        actual = path_normalize(path);
        assert(equal(expected, actual));

        path = ":/bin/:://a:/usr/bin:::á,   é, ü/ñ@¿://bin://foo//bar/baz///";
        expected = ["/bin", "/a", "/usr/bin", "á,   é, ü/ñ@¿", "/bin", "/foo/bar/baz"].join("\n");
        actual = path_split(path);
        assert(equal(expected, actual));

        path = ":/bin/:://a:/usr/bin:::á, é, ü/ñ@¿://bin://foo//bar/baz///";
        expected = "/bin:/usr/bin";
        actual = path_filter(path);
        assert(equal(expected, actual));

        path = ":/bin/:://a:/usr/bin:::á, é, ü/ñ@¿://bin://foo//bar/baz///";
        dir = "á, é, ü/ñ@¿";
        assert(path_has(path, dir));

        path = ":/bin/:://a:/usr/bin:::á, é, ü/ñ@¿://bin://foo//bar/baz///";
        expected = "/foo:/bin:/a:/usr/bin:á, é, ü/ñ@¿:/bin:/foo/bar/baz";
        actual = path_prepend(path, ["/foo/"]);
        assert(equal(expected, actual));

        path = ":/bin/:://a:/usr/bin:::á, é, ü/ñ@¿://bin://foo//bar/baz///";
        expected = "/bin:/a:/usr/bin:á, é, ü/ñ@¿:/bin:/foo/bar/baz:/bar:baz";
        actual = path_append(path, ["/bar/", "baz/"]);
        assert(equal(expected, actual));
    } catch (AssertError ex) {
        io.writeln();
        io.writefln("PATH     = %s", path);
        io.writefln("EXPECTED = %s", expected);
        io.writefln("ACTUAL   = %s", actual);
        io.writeln();

        throw ex;
    }
}

int main(string[] args)
{
    import docopt : docopt, prettyPrintArgs, ArgValue;

    auto options = docopt(APP_DOC, args[1..$], true, "0.0.2");

    // io.writeln(prettyPrintArgs(options));

    if (options["normalize-dir"].isTrue)
    {
        string dir = options["<dir>"].toString();
        io.write(dir_normalize(dir));
    }
    else if (options["normalize"].isTrue)
    {
        string path = options["<path>"].toString();
        io.write(path_normalize(path));
    }
    else if (options["split"].isTrue)
    {
        string path = options["<path>"].toString();
        io.write(path_split(path));
    }
    else if (options["filter"].isTrue)
    {
        string path = options["<path>"].toString();
        io.write(path_filter(path));
    }
    else if (options["has"].isTrue)
    {
        string path = options["<path>"].toString();
        string dir = options["<dir>"].toString();

        return path_has(path, dir) ? 0 : 1;
    }
    else if (options["prepend"].isTrue)
    {
        string path = options["<path>"].toString();
        string[] dirs = options["<dirs>"].asList;
        io.write(path_prepend(path, dirs));
    }
    else if (options["append"].isTrue)
    {
        string path = options["<path>"].toString();
        string[] dirs = options["<dirs>"].asList;
        io.write(path_append(path, dirs));
    }
    else if (options["join"].isTrue)
    {
        string[] dirs = options["<dirs>"].asList;
        io.write(path_join(dirs));
    }
    else
    {
        io.writeln("Invalid command. Use --help for help.");

        return 1;
    }

    return 0;
}
