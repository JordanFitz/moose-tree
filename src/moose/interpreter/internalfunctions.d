module moose.interpreter.internalfunctions;

import std.variant: Variant;
import std.exception: enforce;

import moose.interpreter.ffi;
import moose.interpreter.main: Struct, Scope;

private
{
    static enum { bind };
    static Variant function(Variant[])[string] _funcs;

    static this() 
    {
        foreach(member; __traits(allMembers, moose.interpreter.internalfunctions))
        {
            foreach(attribute; __traits(getAttributes, __traits(getMember, moose.interpreter.internalfunctions, member)))
            {
                static if(attribute == bind)
                    _funcs[member] = &__traits(getMember, moose.interpreter.internalfunctions, member);
            }
        }
    }
}

public Variant _internalCall(string name, Variant[] args)
{
    enforce(name in _funcs, `Unknown internal function "` ~ name ~ `"`);
    return _funcs[name](args);
}

// Begin internal functions

@bind
private
{
    Variant print(Variant[] args)
    {
        import std.stdio: write;
        foreach(arg; args) arg.write;
        return Variant(null);
    }

    Variant read_line(Variant[] args)
    {
        import std.stdio: readln;
        return Variant(readln[0 .. $ - 1]);
    }

    Variant read_char(Variant[] args)
    {
        import core.stdc.stdio: getchar;
        char c = cast(char) getchar();
        return Variant(c ~ "");
    }

    Variant convert_to_string(Variant[] args)
    {
        enforce(args.length == 1, "convert_to_string expects one argument.");
        import std.conv: to;
        return Variant(args[0].to!string);
    }

    Variant convert_to_number(Variant[] args)
    {
        enforce(args.length == 1, "convert_to_number expects one argument.");
        import std.conv: to;
        return Variant(args[0].to!string.to!float);
    }

    Variant get_char_code(Variant[] args)
    {
        enforce(args.length == 1, "get_char_code expects one argument.");
        enforce(args[0].convertsTo!string, "Cannot get char code from a non-string type.");

        string input = args[0].get!string;

        enforce(input.length == 1, "get_char_code expects exactly one character.");

        return Variant(cast(float) input[0]);
    }

    Variant convert_char_code(Variant[] args)
    {
        enforce(args.length == 1, "convert_char_code expects one argument.");
        enforce(args[0].convertsTo!float, "Cannot convert char code from a non-number type.");

        float input = args[0].get!float;

        // TODO: Check for invalid ASCII codes.
        if(input % 1 != 0)
            enforce(0, "Invalid ASCII code.");

        return Variant((cast(char) input) ~ "");
    }

    Variant array_append(Variant[] args)
    {
        if(args.length != 2) 
            enforce(0, "array_append expects two arguments.");

        if(!(args[0].convertsTo!(Variant[])))
            enforce(0, "Cannot append to non-array type.");

        Variant[] array = args[0].get!(Variant[]);
        array ~= args[1];

        return Variant(array);
    }

    Variant array_remove(Variant[] args)
    {
        if(args.length != 2) 
            enforce(0, "array_remove expects two arguments.");

        if(!(args[0].convertsTo!(Variant[])))
            enforce(0, "array_remove cannot remove from a non-array type.");

        if(!(args[1].convertsTo!float))
            enforce(0, "array_remove expects an index as its second parameter.");

        Variant[] array = args[0].get!(Variant[]);

        uint index = cast(uint) args[1].get!float;

        return Variant(array[0 .. index] ~ array[index + 1 .. $]);
    }

    Variant exit(Variant[] args) 
    {
        import std.stdio: writeln;

        if(args.length == 1)
            writeln(args[0]);
        else enforce(0, "exit expects one argument.");

        import core.stdc.stdlib: exit;
        exit(0);

        return Variant(null);
    }

    version(Posix)
    Variant load_external_func(Variant[] args)
    {
        if(args.length != 2 || !args[0].convertsTo!string || !args[1].convertsTo!string)
            enforce(0, "load_external_func expects exactly two string arguments.");

        return Variant(
            FFI.loadExternalFunc(args[0].get!string, args[1].get!string)
        );
    }

    version(Posix)
    Variant load_library(Variant[] args)
    {
        if(args.length != 1 || !args[0].convertsTo!string)
            enforce(0, "load_library expects exactly one string argument.");

        string[] funcTable = FFI.loadFuncTable(args[0].get!string);

        foreach(func; funcTable)
        {
            string code = func ~ `: __internal(load_external_func, "` ~ args[0].get!string ~ `", "` ~ func ~ `");`;
            evaluate([Variant(code)]);
        }

        return Variant(null);
    }

    Variant evaluate(Variant[] args)
    {
        if(args.length != 1 || !args[0].convertsTo!string)
            enforce(0, "evaluate expects exactly one string argument.");

        import moose.tokenizer.main: Tokenizer;
        import moose.tokenizer.token: Token;
        import moose.interpreter.main: Interpreter, Scope;
        import moose.ast.generator: ASTGenerator;

        Token[] stream = new Tokenizer(args[0].get!string, "evaluate()").stream;

        // NOTE: This will not cause any flow control to stop so `evaluate`ing something like a 
        //       return statement will be useless for now. 's' is a null Scope because we want to 
        //       use the Interpreter's current scope and you can't pass "null" directly to a ref
        //       argument.

        bool  stop = false;
        Scope s = null;

        ASTGenerator.init(stream);

        return Interpreter.instance.evaluate(
            ASTGenerator.result, stop, s
        );
    }

    // TODO: When we have static struct stuff, make it so you can pass the struct itself to this
    //       method, rather than passing an object. 
    
    Variant has_member(Variant[] args)
    {
        if(args.length != 2 || !args[0].convertsTo!Struct || !args[1].convertsTo!string)
            enforce(0, "has_member expects exactly two arguments: An object and a string.");

        // We don't care about foundScope or the type of the found thing (s and t, respectively).
        Scope s;
        char  t;

        bool found = (args[0].get!Struct).bodyScope.find(args[1].get!string, t, s);

        return Variant(found);
    }

    Variant conv(Variant[] args)
    {
        enforce(0);

        if(args.length != 2 || !args[1].convertsTo!string)
            enforce(0, "conv expects exactly two arguments, with the second being a string.");

        string to = args[1].get!string;

        switch(to)
        {
            case "uint": return Variant(cast(uint) args[0].get!float);
            case "int":  return Variant(cast(int)  args[0].get!float);
            
            default: enforce(0);
        }

        return Variant(null);
    }
}