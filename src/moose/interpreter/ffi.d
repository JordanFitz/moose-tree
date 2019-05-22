module moose.interpreter.ffi;

import std.exception: enforce;
import std.stdio: stderr, writeln;
import std.conv: to;
import std.variant: Variant;
import std.string: toStringz;
import core.stdc.stdio: printf;

public alias MooseFunc = Variant function(Variant[]);

version(Posix):

private import core.sys.posix.dlfcn;

private void*[string] _libs;

static class FFI 
{
private static: 
    void _load(string libName)
    {
        if(libName !in _libs)
        {
            _libs[libName] = dlopen(libName.toStringz, RTLD_LAZY);

            if(!_libs[libName])
            {
                stderr.writeln(dlerror().to!string);
                enforce(0, "Failed to load library " ~ libName);
            }
        }
    }

public static:
    string[] loadFuncTable(string libName)
    {
        _load(libName);

        auto getFuncTable = cast(string[] function()) dlsym(_libs[libName], "getFunctionTable");
        char* error = dlerror;

        if(error) return [];

        return getFuncTable();
    }

    MooseFunc loadExternalFunc(string libName, string funcName)
    {
        _load(libName);

        MooseFunc func = cast(MooseFunc) dlsym(_libs[libName], funcName.toStringz);
        char* error = dlerror;

        if(error)
        {
            stderr.writeln(error.to!string);
            enforce(0, "dlsym failed on " ~ funcName);
        }

        return func;
    }
}