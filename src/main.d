import moose.tokenizer.main;
import moose.ast.generator;
import moose.interpreter.main;

void main(string[] args)
{
    import std.file: readText;
    import std.stdio: writeln;

    if(args.length > 1)
    {
        for(uint i = 1; i < args.length; i++)
        {
            new Interpreter(args[i]);
        }
    }
    else
    {
        new Interpreter("tests/calculator.moo");

        //import std.file: dirEntries, SpanMode;
        //foreach(string name; dirEntries("tests", SpanMode.shallow))
        //{
        //    if(name == "tests/calculator.moo") continue;

        //    writeln("\n\n-----> TESTING ", name, "\n\n");
        //    new Interpreter(name);
        //}
    }
}
