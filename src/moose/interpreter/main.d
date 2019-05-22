module moose.interpreter.main;

import core.time: MonoTime, Duration;

import std.stdio: writeln, write;
import std.variant: Variant, VariantN;
import std.algorithm: canFind;
import std.conv: to;
import std.array: join;
import std.exception: enforce;

import std.path: buildNormalizedPath, absolutePath, dirName;

import std.file:
    isDir,
    isFile,
    thisExePath,
    exists,
    readText;

import property;

import moose.ast.node;
import moose.tokenizer.token;
import moose.interpreter.rpn;
import moose.tokenizer.main;
import moose.ast.generator;
import moose.interpreter.internalfunctions;
import moose.interpreter.ffi;

private static const
{
    string ARG_LIST_NAME = "args";
    string INTERNAL_FUNC_NAME = "__internal";
}

private bool structIsStatic(Struct s)
{
    return s.name.length > "__static:".length && s.name[0 .. "__static".length + 1] == "__static:";
}

class Function
{
private:
    string m_ident;
    Scope m_funcScope;
    uint m_argCount;
    string[] m_argIdents;
    bool m_exported = false;
    bool m_privated = false;
    bool m_staticed = false;
    bool m_any      = false;
    bool m_merged = false;
    bool[] m_refArgs;
    BaseNode m_body;

    Struct m_parentStruct = null;

    MooseFunc m_externalFunc = null;    

    Scope m_containerScope;

public:
    mixin Property!(bool,   "exported" );
    mixin Getter!(bool,     "privated");
    mixin Getter!(bool,     "staticed");
    mixin Getter!(bool,     "any"      );
    mixin Getter!(string,   "ident"    );
    mixin Getter!(string[], "argIdents");
    mixin Getter!(uint,     "argCount" );
    mixin Getter!(Scope,    "funcScope");
    mixin Property!(Scope,  "containerScope");
    mixin Property!(bool,   "merged");

    mixin Property!(Struct, "parentStruct");

    this(FuncDefNode node)
    {
        m_exported = node.exported;
        m_privated = node.privated;
        m_staticed = node.staticed;

        ArgListNode args = cast(ArgListNode) node.children[1];

        m_any = args.any;

        m_ident    = (cast(IdentNode) node.children[0]).value;
        m_argCount =  cast(uint)      args.children.length;

        foreach(i, arg; args.children)
        {
            m_argIdents ~= (cast(IdentNode) arg).value;
            m_refArgs   ~= (cast(IdentNode) arg).flagged;

            if(m_argIdents[i] == ARG_LIST_NAME)
                Interpreter.instance.halt(
                    `"` ~ ARG_LIST_NAME ~ `" is a reserved identifier within functions.`
                );
        }

        m_body = cast(BaseNode) node.children[2];
    }

    this(string ident, MooseFunc externalFunc)
    {
        m_ident = ident;
        m_externalFunc = externalFunc;

        m_any = true;
    }

    Variant eval(Variant[] args, string[] identArgs, Scope callerScope, Scope parentScope)
    {
        if(m_externalFunc !is null)
            return m_externalFunc(args);

        if(!m_any && args.length != m_argCount)
        {
            Interpreter.instance.halt(
                "Wrong number of arguments to \"", m_ident,
                "\" (Expected ", m_argCount, ", but got ", args.length, ")."
            );
        }

        m_funcScope = new Scope(m_ident, parentScope);

        m_funcScope.defineVariable(
            new Variable(ARG_LIST_NAME, Variant(args))
        );

        foreach(i, arg; args)
        {
            if(i < m_argIdents.length)
                m_funcScope.defineVariable(
                    new Variable(m_argIdents[i], arg)
                );
        }

        bool _;

        Interpreter.instance.currentFunction = this;
        Variant result = Interpreter.instance.evaluate(m_body, _, m_funcScope);
        Interpreter.instance.currentFunction = null;

        char  ft;
        Scope foundScope;

        foreach(i, ident; m_argIdents)
        {
            if(m_refArgs[i] && identArgs[i] !is null)
            {
                enforce(callerScope.find(identArgs[i], ft, foundScope, true));
                
                foundScope.defineVariable(new Variable(
                    identArgs[i], m_funcScope.getValue(ident)
                ));
            }
            else if(m_refArgs[i] && identArgs[i] is null)
                Interpreter.instance.halt(
                    "Cannot pass a non-assignable argument (",
                    ident, " = ", args[i],
                    ") to a function which expects a ref argument."
                );
        }

        return result;
    }
}

class Variable
{
private:
    string m_ident;
    Scope m_scope;
    TokenType m_type;
    Variant m_value;
    bool m_exported = false;
    bool m_privated = false;
    bool m_staticed = false;
    bool m_merged = false;

public:
    mixin Getter!(string, "ident"   );
    mixin Getter!(bool,   "exported");
    mixin Getter!(bool,   "privated");
    mixin Getter!(bool,   "staticed");
    mixin Property!(bool, "merged");

    Variant value() @property
    {
        return m_value;
    }

    this(VarDefNode node, Variant value)
    {
        m_exported = node.exported;
        m_privated = node.privated;        
        m_staticed = node.staticed;        
        m_ident = (cast(IdentNode) node.children[0]).value;
        m_value = value;
    }

    this(string ident, Variant value, bool privated = false, bool staticed = false)
    {
        m_ident = ident;
        m_value = value;
        m_privated = privated;
        m_staticed = staticed;
    }
}

class Struct
{
private:
    string m_name;
    bool m_exported = false;
    bool m_privated = false;
    Struct m_staticInstance = null;
    Struct m_parent = null;
    bool m_merged = false;

public:
    mixin Getter!(string, "name"    );
    mixin Getter!(bool,   "exported");
    mixin Getter!(bool,   "privated");
    mixin Getter!(Struct, "staticInstance");
    mixin Getter!(Struct, "parent");
    mixin Property!(bool, "merged");

    Scope bodyScope;

    this(string name, bool exported, bool privated, bool createStatic = false)
    {
        m_exported = exported;
        m_privated = privated;

        m_name = name;
        bodyScope = new Scope("struct " ~ name, Interpreter.instance.currentScope);
        bodyScope.setStruct(this);

        if(createStatic)
        {
            m_staticInstance = new Struct("__static:" ~ name, false, false, false);
            m_staticInstance.setParent(this);
        }
    }

    void setParent(Struct s)
    {
        m_parent = s;
    }

    override string toString()
    {
        return "struct:" ~ name;
    }
}

class Scope
{
private:
    string m_filePath = null;

    Scope[] m_children;
    Scope m_parent = null;

    Struct[string] m_structs;
    Variable[string] m_vars;
    Function[][string] m_funcs;

    string[string] m_loadedModules;

    string m_name;

    Struct m_parentStruct;

public:
    mixin Property!(Scope, "parent");
    mixin   Getter!(string[string], "loadedModules");
    mixin   Getter!(Struct, "parentStruct");

    mixin Property!(string, "filePath");
    mixin   Getter!(string, "name");

    this(string name, Scope parent = null)
    {
        m_name = name;
        m_parent = parent;

        if(parent !is null) m_filePath = parent.filePath;
    }

    void setStruct(Struct s)
    {
        m_parentStruct = s;
    }

    // NOTE: This is a nested function which searches every child scope and their children recursively 
    bool hasChild(Scope searchScope, bool nested = false)
    {
        foreach(child; m_children)
        {
            if(child == searchScope)
                return true;
        }

        // NOTE: I don't know if looping twice is the best solution but I wanted to 
        //       search this scope's children before diving into the next layer.
        foreach(child; m_children)
        {
            if(child.hasChild(searchScope))
                return true;
        }

        return false;
    }

    void addModule(string name, string path)
    {
        m_loadedModules[name] = path;
    }

    void addChild(Scope child)
    {
        if(child.parent is null)
            child.parent = this;

        m_children ~= child;
    }

    void defineVariable(Variable variable, bool allowSelf = false)
    {
        if(!allowSelf && variable.ident == "self")
        {
            Interpreter.instance.halt(
                `"self" is a reserved identifier and cannot defined or assigned.`
            );
        }

        m_vars[variable.ident] = variable;
    }

    void defineFunction(Function func)
    {
        if(func.containerScope is null)
            func.containerScope = this;

        m_funcs[func.ident] ~= func;
    }

    void defineStruct(Struct newStruct)
    {
        // We shouldn't ever want to redefine a struct, I think?
        enforce(newStruct.name !in m_structs);

        foreach(stat; newStruct.bodyScope.getStaticVars)
            newStruct.staticInstance.bodyScope.defineVariable(stat);

        foreach(stat; newStruct.bodyScope.getStaticFuncs)
            newStruct.staticInstance.bodyScope.defineFunction(stat);

        m_structs[newStruct.name] = newStruct;
    }

    Variant getValue(string ident)
    {
        enforce(ident in m_vars);
        return m_vars[ident].value;
    }

    Variable[] getStaticVars()
    {
        Variable[] result;

        foreach(name, var; m_vars)
            if(var.staticed) result ~= var;

        return result;
    }

    Function[] getStaticFuncs() 
    {
        Function[] result;

        foreach(name, funcs; m_funcs)
        {
            foreach(func; m_funcs[name])
                if(func.staticed) result ~= func;
        }

        return result;
    }

    Variant getValue(string ident, ref bool isPrivate, ref bool isStatic)
    {
        enforce(ident in m_vars);
        isPrivate = m_vars[ident].privated;
        isStatic = m_vars[ident].staticed;
        return m_vars[ident].value;
    }

    Variable getVariable(string ident)
    {
        enforce(ident in m_vars);
        return m_vars[ident];
    }

    Type getRawValue(Type)(string ident)
    {
        if(ident in m_vars)
            return m_vars[ident].value.get!Type;

        enforce(0);
        assert(0);
    }

    Function getFunc(string ident)
    {
        enforce(ident in m_funcs);

        if(m_funcs[ident].length != 1) 
            Interpreter.instance.halt(`Ambiguous function identifier "` ~ ident ~ '"');

        return m_funcs[ident][0];
    }

    Function getFunc(string ident, uint argCount, ref bool isPrivate, ref bool isStatic)
    {
        enforce(ident in m_funcs);

        foreach(func; m_funcs[ident])
        {
            if((func.any && argCount >= func.argCount) || (!func.any && argCount == func.argCount))
            {
                isPrivate = func.privated;
                isStatic = func.staticed;
                return func;
            }
        }

        enforce(0, "called getFunc but didn't find a matching function");

        return null;
    }

    Struct getStruct(string name)
    {
        enforce(name in m_structs);
        return m_structs[name];
    }

    void merge(Scope newScope, bool requireExport, bool fromModule = false)
    {
        // NOTE: The .merged property prevents things from being merged into scopes when they
        //       themselves were loaded from another module.

        foreach(name, var; newScope.m_vars)
        {
            if(!requireExport || var.exported)
            {
                if(!fromModule || !var.merged)
                {
                    var.merged = true;
                    defineVariable(var);
                }
            }
        }

        foreach(name, strct; newScope.m_structs)
        {
            if(!requireExport || strct.exported)
            {
                if(!fromModule || !strct.merged)
                {
                    strct.merged = true;
                    defineStruct(strct);
                }
            }
        }

        foreach(name, funcList; newScope.m_funcs)
        {
            foreach(func; newScope.m_funcs[name])
            {
                if(!requireExport || func.exported)
                {
                    if(!fromModule || !func.merged)
                    {
                        func.merged = true;
                        defineFunction(func);
                    }
                }
            }
        }
    }

    bool findStruct(string name, ref Scope foundScope, bool nested = false)
    {
        if(name in m_structs)
        {
            foundScope = this;
            return true;
        }

        if(nested && m_parent !is null)
            return m_parent.findStruct(name, foundScope, nested);

        return false;
    }

    // `type` will be 'v' if the ident is found to be a variable, 
    // 'f' if the ident is found to be a function, and 's' if the ident
    // is found to be a struct. `foundScope` is the scope that the ident
    // was found in, if it's found. If type is 'f' and the function
    //  returns false, then the function was found but the number of
    // arguments supplied was incorrect. 

    bool find(string ident, ref char type, ref Scope foundScope, bool nested = false, int argCount = -1)
    {
        type = '\0';

        if(findStruct(ident, foundScope, nested))
        {
            type = 's';
            return true;
        }

        if(ident in m_vars) 
        {
            foundScope = this;
            type = 'v';
            return true;
        }

        if(ident in m_funcs)
        {
            foundScope = this;
            type = 'f';

            // If no argCount is supplied, there must only be one overload of the given identifier.
            if(argCount == -1)
            {
                if(m_funcs[ident].length == 1) return true;
                Interpreter.instance.halt(`Ambiguous function identifier "`, ident, `".`);
            }

            foreach(func; m_funcs[ident])
            {
                if((func.any && func.argCount <= argCount) || (!func.any && func.argCount == argCount))
                    return true;
            }
        }

        if(nested && m_parent !is null)
            return m_parent.find(ident, type, foundScope, nested, argCount);

        foundScope = null;

        return false;
    }

    void print(string indent = "  ")
    {
        import std.stdio: writeln;
        import std.array: join;

        writeln(indent[0 .. $ - 2], "> ", m_name);

        foreach(ident, var; m_vars)
            writeln(indent, var.privated ? "private " : "", ident, " = ", var.value);

        foreach(ident, funcList; m_funcs)
            foreach(func; funcList)
                writeln(indent, func.privated ? "private " : "", ident, '(', func.argIdents.join(", "), ')');

        foreach(child; m_children)
            child.print(indent ~ "  ");
    }
}

public bool isA(Type)(Node node)
{
    return (typeid(Type) == typeid(node));
}

private static BaseNode[string] CODE_CACHE;

class Interpreter
{
private:
    static Interpreter m_instance = null;

    Scope m_globalScope;
    Scope m_currentScope;

    alias s = m_currentScope;
    alias g = m_globalScope;

    string m_path = null;
    string m_fileName = null;

    Function m_currentFunction;

    string _getFinalPath(string path)
    {
        bool check(string p)
        {
            return p.exists && p.isFile && !p.isDir;
        }

        string result;

        result = buildNormalizedPath(m_path, path);
        if(check(result)) return result;

        result = buildNormalizedPath(thisExePath.dirName, "lib", path);
        if(check(result)) return result;

        halt("Nonexistent file: ", path);

        return null;
    }

    bool _variantAsBool(Variant v)
    {
        if(v.convertsTo!float)
            return v != 0;

        if(v.convertsTo!string)
            return true;

        if(v.convertsTo!bool)
            return v.get!bool;

        if(v.type == typeid(null))
            return false;

        if(v.type == typeid(Struct))
            return true;

        // enforce(0, "Cannot evaluate variant as a boolean: " ~ v.toString);

        // NOTE: If the variant is any other type, it's going to be an object which should
        //       evaluate as 'true'

        return true;
    }

    Variant[] _trySpread(Node node)
    {
        if(node.isA!SpreadNode)
        {
            Variant spreading = resolveValue(node.children[0]);

            if(!spreading.convertsTo!(Variant[]))
                halt("Cannot spread non-array type ", spreading.type);

            return spreading.get!(Variant[]);
        }
        else
        {
            return [resolveValue(node)];
        }
    }

    // NOTE: The last two arguments are for use with DotNodes.
    //       If skipFirstArg is true, then the first argument passed
    //       to the function will not be evaluated and instead,
    //       the firstArg parameter will be used as the argument.
    //       This is to prevent multiple evaluations after the _dot
    //       method processes the first part of a DotNode to check
    //       its type.

    Variant _funcCall(FuncCallNode node, bool skipFirstArg = false, Variant firstArg = null)
    {
        char  foundType  = '\0';
        Scope foundScope = null;

        string ident = (cast(IdentNode) node.children[0]).value;

        // If the function that is being called is __internal()
        if(ident == INTERNAL_FUNC_NAME)
        {
            Variant[] args;

            foreach(argNode; node.children[2..$])
                args ~= _trySpread(argNode);

            return _internalCall(
                (cast(IdentNode) node.children[1]).value, args
            );
        }

        // Creating an instance of a struct by using its name as a function.
        // For instance, with a struct Person, you'd call Person(); to create
        // an instance of the Person struct.
        if(s.findStruct(ident, foundScope, true))
        {
            // The scope which the 'constructor' was called from
            Scope  callScope   = foundScope;
            Struct foundStruct = foundScope.getStruct(ident);

            Variant[] args;
            foreach(argNode; node.children[1..$])
                args ~= _trySpread(argNode);

            // TODO: Consider changing name of 'constructor' from 'new'
            if(foundStruct.bodyScope.find(
                "new", foundType, foundScope, false,
                cast(uint) args.length) && foundType == 'f')
            {

                Struct newStruct = new Struct(ident, foundStruct.exported, foundStruct.privated);
                newStruct.bodyScope.parent = foundStruct.bodyScope.parent;

                // The original copy of the struct's members is given to the actual instance
                // of the struct by merging the two scopes.

                newStruct.bodyScope.merge(foundStruct.bodyScope, false);

                // NOTE: We don't care if the constructor is private, I think.
                //       The last param to getFunc is a ref bool that says whether
                //       the returned function is private, as the name suggests.

                bool _;  // isPrivate
                bool __; // isStatic

                Function constructor = newStruct.bodyScope.getFunc("new", cast(uint) args.length, _, __);

                newStruct.bodyScope.defineVariable(
                    new Variable("self", Variant(newStruct)), true
                );

                // NOTE: We're passing [] as identArgs because I don't think constructors should be able to 
                //       have "ref" params. I should probably show an error if the user tries to write a 
                //       constructor with an @arg. Right now it will just not work.

                // NOTE: The last parameter is the parentScope which is the scope that gets
                //       passed to the function's scope constructor as its parent. The struct's
                //       members should be accessible to functions within the struct so it has to 
                //       have the proper parent scope.

                constructor.eval(args, [], callScope, newStruct.bodyScope);

                return Variant(newStruct);
            }
            else if(foundType == '\0' && node.children.length == 1)
            {
                Struct newStruct = new Struct(ident, foundStruct.exported, foundStruct.privated);

                newStruct.bodyScope.parent = foundStruct.bodyScope.parent;
                newStruct.bodyScope.merge(foundStruct.bodyScope, false);
                newStruct.bodyScope.defineVariable(
                    new Variable("self", Variant(newStruct)), true
                );

                return Variant(newStruct);
            }
            //else if(foundType == 'f' || (foundType == '\0' && node.children.length - 1 > 0))
            else
            {
                halt(
                    "No constructor for struct ", ident, 
                    " that expects ", node.children.length - 1,
                    " argument", node.children.length != 2 ? "s" : "", "."
                );
            }

            enforce(0);
        }

        foundType = '\0';
        foundScope = null;

        Variant[] args;
        string[]  identArgs;

        if(skipFirstArg)
            args ~= firstArg;

        //Node[] argNodes =
        //    skipFirstArg ? node.children[2 .. $] : node.children[1 .. $];

        foreach(i, argNode; node.children[1 .. $])
        {
            if(argNode.isA!IdentNode)
                identArgs ~= (cast(IdentNode) argNode).value;
            else identArgs ~= null;

            if(!skipFirstArg || i > 0)
                args ~= _trySpread(argNode);
        }

        if(s.find(ident, foundType, foundScope, true, cast(uint) args.length))
        {
            if(foundType == 'f')
            {
                bool _;  // We don't care if the function is private because we know it isn't a struct member.
                bool __; // Ditto, except for static
                return foundScope.getFunc(ident, cast(uint) args.length, _, __).eval(args, identArgs, s, null);
            }
            else if(foundType == 'v')
            {
                Variant value = foundScope.getValue(ident);

                if(value.convertsTo!Function)
                    return (value.get!Function).eval(args, identArgs, s, null);
                else halt('"', ident, `" is not a function.`);
            }
            else halt('"', ident, `" is not a function.`);
        }
        else
        {
            if(foundType == '\0')
                halt(`Function "`, ident, `" is not defined.`);

            if(foundType == 'f')
                halt(
                    `No overload of "`,
                    ident, `" expects `,
                    node.children.length - 1, " argument",
                    node.children.length != 2 ? "s" : "", "."
                );
        }

        enforce(0);

        return Variant(null);
    }

    // NOTE: This is gross but it rearranges chained DotNodes 
    //       so that they are in the proper order because it 
    //       was easier than changing the AST generator...

    void _rearrangeDot(ref DotNode node)
    {
        while(node.children[1].isA!DotNode)
        {
            DotNode child = cast(DotNode) node.children[1];
            DotNode newDot = new DotNode;

            newDot.addChild(node.children[0]);
            newDot.addChild(child.children[0]);

            DotNode parentDot = new DotNode;

            parentDot.addChild(newDot);
            parentDot.addChild(child.children[1]);

            node = parentDot;
        }
    }

    Variant _dot(DotNode node)
    {
        _rearrangeDot(node);

        Variant operand = resolveValue(node.children[0]);

        if(operand.type == typeid(Struct))
        {
            Struct operandStruct = operand.get!Struct;

            char  foundType  = '\0';
            Scope foundScope = null;

            if(node.children[1].isA!IdentNode)
            {
                string memberIdent = (cast(IdentNode) node.children[1]).value;

                if(operandStruct.bodyScope.find(
                    memberIdent, foundType, foundScope, false) && foundType == 'v')
                {
                    bool isPrivate;
                    bool isStatic;
                    Variant memberValue = foundScope.getValue(memberIdent, isPrivate, isStatic);

                    if(isStatic && !structIsStatic(operandStruct))
                        halt(`Cannot access static struct member "`, memberIdent, `" via object.`);

                    if(!isPrivate || (s == foundScope || foundScope.hasChild(s)))
                        return memberValue;
                    else halt(`Cannot access private struct member "`, memberIdent, `".`);
                }
                else if(foundType != 'v')
                    halt("Struct ", operandStruct.name, ` has no data member "`, memberIdent, `".`);
            }

            else if(node.children[1].isA!FuncCallNode)
            {
                foundType = '\0';
                foundScope = null;

                FuncCallNode fCallNode = cast(FuncCallNode) node.children[1];

                string funcIdent = (cast(IdentNode) fCallNode.children[0]).value;

                Variant[] args;
                string[]  identArgs;

                foreach(i, argNode; fCallNode.children[1..$])
                {
                    if(argNode.isA!IdentNode)
                    {
                        identArgs ~= (cast(IdentNode) argNode).value;
                    }
                    else identArgs ~= null;

                    args ~= _trySpread(argNode);
                }

                if(operandStruct.bodyScope.find(
                    funcIdent, foundType, foundScope, false,
                    cast(uint) args.length) && foundType == 'f')
                {
                    bool isPrivate;
                    bool isStatic;
                    Function func = foundScope.getFunc(funcIdent, cast(uint) args.length, isPrivate, isStatic);

                    if(isStatic && !structIsStatic(operandStruct))
                        halt(`Cannot access static struct member "`, funcIdent, `" via object.`);

                    if(isPrivate && (s != foundScope && !foundScope.hasChild(s)))
                        halt(`Cannot access private struct member "`, funcIdent, `".`);

                    return func.eval(args, identArgs, s, operandStruct.bodyScope);
                }
                else if(foundType == 'f')
                {
                    halt(
                        "No overload of ", operandStruct.name,
                        '.', funcIdent, "() expects ",
                        fCallNode.children.length - 1, " argument",
                        fCallNode.children.length != 2 ? "s" : "", '.'
                    );
                }

                // TODO: Consider removing this and moving on to the next _dot check so that
                //       you can do dot calls on struct objects with functions that aren't
                //       members of the struct.

                else if(foundType != 'f')
                    halt("Function ", operandStruct.name, '.', funcIdent, "() is not defined.");
            }

            enforce(0);
        }

        if(node.children[1].isA!FuncCallNode)
        {
            FuncCallNode oldFunc = cast(FuncCallNode) node.children[1];
            FuncCallNode func = new FuncCallNode;

            func.addChild(oldFunc.children[0]);
            func.addChild(node.children[0]);

            for(uint i = 1; i < oldFunc.children.length; i++)
                func.addChild(oldFunc.children[i]);

            return _funcCall(func, true, operand);
        }

        writeln("\n\n\nUnresolved dot call");
        node.printTree;

        return Variant(null);
    }

    void _node(Node node, ref bool hasResult, ref Variant result, ref bool stop, ref BaseNode replacementNode)
    {
        hasResult = false;
        stop = false;

        replacementNode = null;

        // For use with Scope.find.
        char  foundType;
        Scope foundScope;

        if(node.isA!ReturnNode)
        {
            if(node.children.length > 0)
                result = resolveValue(cast(ValueNode) node.children[0]);
            else result = Variant();

            hasResult = true;
            stop = true;
        }

        if(node.isA!BreakNode)
        {
            stop = true;
        }

        if(node.isA!FuncCallNode)
        {
            _funcCall(cast(FuncCallNode) node);
        }

        if(node.isA!DotNode)
        {
            _dot(cast(DotNode) node);
        }

        if(node.isA!StructNode)
        {
            string name = (cast(IdentNode) node.children[0]).value;

            if(s.findStruct(name, foundScope))
                halt("A struct with the name ", name, " is already defined in this scope.");

            foundScope = null;

            bool _; // We don't care about the 'stop' parameter because we're not
                    // doing flow control in the body of a struct.

            Struct newStruct = new Struct(name,
                (cast(StructNode) node).exported,
                (cast(StructNode) node).privated,
                true
            );

            newStruct.bodyScope.filePath = m_fileName;
            newStruct.bodyScope.parent = s;

            Interpreter.instance.evaluate(
                cast(BaseNode) node.children[1],
                _, newStruct.bodyScope
            );

            s.defineStruct(newStruct);
        }

        if(node.isA!LoadNode)
        {
            string name = (cast(LiteralNode) node.children[0]).value.get!string;            
            string finalPath = _getFinalPath(name);

            bool loadedBefore = false;
            foreach(modName, path; s.loadedModules)
            {
                if(path == finalPath)
                {
                    loadedBefore = true;
                    break;
                }
            }

            if(!loadedBefore)
            {
                BaseNode ast;

                if(finalPath in CODE_CACHE)
                    ast = CODE_CACHE[finalPath];
                else
                {
                    string file = finalPath.readText;                    
                    Token[] stream = new Tokenizer(file, name).stream;
                    ASTGenerator.init(stream);

                    ast = ASTGenerator.result;
                    CODE_CACHE[finalPath] = ast;
                }

                //ast.printTree;

                if(ast.children.length == 0 || !(ast.children[0].isA!ModNode))
                    halt(`File "`, name, `" does not have a mod statement and cannot be loaded as a result.`);

                string modName = (cast(IdentNode) ast.children[0].children[0]).value;

                // Show a warning if we try to load two modules by the same name
                // but from different files.
                if(modName in s.loadedModules && s.loadedModules[modName] != finalPath)
                    writeln(
                        '\n', `Warning: Module "`, modName, `" from file "`, finalPath,
                        `" was not loaded because a module `, '\n', 
                        `by that name was already loaded from "`,
                        s.loadedModules[modName], `".`
                    );
                else if(modName !in s.loadedModules)
                {
                    s.addModule(modName, finalPath);

                    Scope newScope = new Interpreter(ast, finalPath).globalScope;
                    s.merge(newScope, true, true);
                }
            }
        }

        if(node.isA!ValueNode)
        {
            if(node.children[0].isA!DotNode)
                _node(node.children[0], hasResult, result, stop, replacementNode);
            else resolveValue(node.children[0]);
        }

        if(node.isA!IfNode)
        {
            hasResult = false;
            result = Variant(null);

            Variant condition = resolveValue(node.children[0]);

            bool reachedElse = false;

            Scope ifScope;
            BaseNode ifBody;

            if(_variantAsBool(condition))
            {
                ifScope = new Scope("if " ~ condition.toString, s);
                ifBody = cast(BaseNode) node.children[1];

                result = Interpreter.instance.evaluate(ifBody, stop, ifScope);

                if(typeid(null) != result.type) hasResult = true;
            }
            else
            {
                uint i = 2; 
                while(i < node.children.length)
                {
                    Node child = node.children[i];

                    if(child.isA!ElseNode)
                    {
                        if(child.children.length == 1)
                        {
                            ifScope = new Scope("else", s);
                            ifBody = cast(BaseNode) child.children[0];

                            result = Interpreter.instance.evaluate(ifBody, stop, ifScope);
                            if(typeid(null) != result.type) hasResult = true;

                            reachedElse = true;

                            break;
                        }
                        else
                        {
                            condition = resolveValue(child.children[0]);

                            if(_variantAsBool(condition))
                            {
                                ifScope = new Scope("if " ~ condition.toString, s);
                                ifBody = cast(BaseNode) child.children[1];

                                result = Interpreter.instance.evaluate(ifBody, stop, ifScope);
                                if(typeid(null) != result.type) hasResult = true;

                                break;
                            }
                        }
                    }
                    else enforce(0);

                    i++;
                }

                if(reachedElse && i < node.children.length - 1)
                {
                    halt("Invalid flow control.");
                }
            }
        }

        if(node.isA!ForNode)
        {
            string ident = (cast(IdentNode) node.children[0]).value;
            Variant value = resolveValue(node.children[1]);

            if(!value.convertsTo!(Variant[]) && !value.convertsTo!string)
                halt("Cannot iterate over non-iterable type.");

            Scope forScope;

            BaseNode forBody = cast(BaseNode) node.children[2];

            stop = false;
            hasResult = false;
            result = Variant(null);

            if(value.convertsTo!(Variant[]))
            {
                Variant[] list = value.get!(Variant[]);

                foreach(item; list)
                {
                    forScope = new Scope("for " ~ ident, s);

                    forScope.defineVariable(new Variable(ident, item));
                    result = Interpreter.instance.evaluate(forBody, stop, forScope);

                    if(stop) break;
                }
            }
            else 
            {
                string str = value.get!string;

                foreach(character; str)
                {
                    forScope = new Scope("for " ~ ident, s);

                    forScope.defineVariable(new Variable(ident, Variant(character ~ "")));
                    result = Interpreter.instance.evaluate(forBody, stop, forScope);

                    if(stop) break;
                }
            }

            stop = false;

            if(typeid(null) != result.type)
            {
                stop = true;
                hasResult = true;
            }
        }

        if(node.isA!WhileNode)
        {
            Variant value  = resolveValue(node.children[0]);
            bool condition = _variantAsBool(value);

            BaseNode whileBody = cast(BaseNode) node.children[1];
            Scope    whileScope;

            stop = false;
            hasResult = false;
            result = Variant(null);

            while(condition)
            {
                whileScope = new Scope("while " ~ value.toString, s);

                result = Interpreter.instance.evaluate(whileBody, stop, whileScope);

                if(stop) break;

                condition = _variantAsBool(
                    resolveValue(cast(ValueNode) node.children[0])
                );
            }

            stop = false;

            if(typeid(null) != result.type)
            {
                stop = true;
                hasResult = true;
            }
        }

        if(node.isA!FuncDefNode)
        {
            if(node.children.length != 3)
            {
                node.printTree;
                enforce(0, "FuncDefNode length was not 3");
            }

            string ident = (cast(IdentNode) node.children[0]).value;

            if(ident == INTERNAL_FUNC_NAME)
                halt(`Identifier "`, ident, `" is a reserved function name.`);

            if(s.find(ident, foundType, foundScope, false, cast(uint) node.children[1].children.length))
                halt("A function with the identifier \"", ident, "\" is already defined.");
            else
            {
                Function func = new Function(cast(FuncDefNode) node);

                if(m_currentFunction !is null)
                    func.containerScope = m_currentFunction.containerScope;

                s.defineFunction(func);
            }
        }

        if(node.isA!VarDefNode)
        {
            if(node.children.length != 2)
            {
                node.printTree;
                enforce(0, "VarDefNode length was not 2");
            }

            string ident = (cast(IdentNode) node.children[0]).value;

            if(ident == INTERNAL_FUNC_NAME)
                halt(`Identifier "`, ident, `" is a reserved function name.`);

            if(s.find(ident, foundType, foundScope))
                halt("Identifier \"", ident, "\" is already defined.");
            else
            {
                Variant value = resolveValue(node.children[1]);

                if(value.type == typeid(MooseFunc))
                {
                    Function externalFunc = new Function(
                        ident, value.get!MooseFunc
                    );

                    externalFunc.exported = (cast(VarDefNode) node).exported;

                    s.defineFunction(externalFunc);
                }
                else 
                {
                    s.defineVariable(
                        new Variable(cast(VarDefNode) node, value)
                    );
                }
            }
        }

        if(node.isA!VarAssignNode)
        {
            TokenType type = (cast(VarAssignNode) node).type;

            if(node.children.length != 2)
            {
                node.printTree;
                enforce(0, "VarAssignNode length was not 2");
            }

            string ident;
            Scope searchScope = s;

            Variant value = resolveValue(cast(ValueNode) node.children[1]);

            if(node.children[0].isA!IdentNode)
            {
                ident = (cast(IdentNode) node.children[0]).value;                
            }
            else if(node.children[0].isA!DotNode)
            {
                DotNode dotNode = cast(DotNode) node.children[0];
                _rearrangeDot(dotNode);

                enforce(dotNode.children[1].isA!IdentNode);

                ident = (cast(IdentNode) dotNode.children[1]).value;

                Variant operand = resolveValue(dotNode.children[0]);

                if(operand.type == typeid(Struct))
                {
                    Struct operandStruct = operand.get!Struct;
                    searchScope = operandStruct.bodyScope;
                }
                else halt("Unimplemented assign to non-struct DotNode");
            }
            else if(node.children[0].isA!IndexNode)
            {
                IndexNode indexNode = cast(IndexNode) node.children[0];

                if(!indexNode.children[0].isA!IdentNode)
                    halt("Cannot assign to array index of non-assignable type.");

                ident = (cast(IdentNode) indexNode.children[0]).value;

                Variant operand = resolveValue(indexNode.children[0]);
                Variant index   = resolveValue(indexNode.children[1]);

                // Combine these checks
                if(!(index.convertsTo!float))
                    halt("Index ", index, " must be a positive integral number.");
                else if(index.get!float % 1 != 0 || index.get!float < 0)
                    halt("Index ", index, " must be a positive integral number.");

                uint i = cast(uint) index.get!float;

                if(!(operand.convertsTo!string) && !(operand.convertsTo!(Variant[])))
                    halt("Cannot index ", operand.type, " type");

                if(operand.convertsTo!string)
                {
                    if(!value.convertsTo!string)
                        halt("Cannot assign string ", ident, '[', i, ']', " to a non-string type.");

                    string str = operand.get!string;
                    value = Variant(str[0 .. i] ~ value.get!string ~ str[i + 1 .. $]);
                }

                if(operand.convertsTo!(Variant[]))
                {
                    Variant[] list = operand.get!(Variant[]);
                    value = Variant(list[0 .. i] ~ value ~ list[i + 1 .. $]);
                }
            }
            else halt("Cannot assign to a non-assignable type.");

            if(!searchScope.find(ident, foundType, foundScope, true))
            {
                halt("Cannot assign undefined identifier \"", ident, "\".");
            }
            else
            {
                if(foundType == 'v')
                {
                    Variant identValue = resolveValue(node.children[0]);

                    bool isPrivate;
                    bool isStatic;
                    Variant oldValue = foundScope.getValue(ident, isPrivate, isStatic);

                    with(TokenType)
                    if(type == OP_MULTIPLY_EQUAL || type == OP_DIVIDE_EQUAL || type == OP_MINUS_EQUAL)
                    {
                        if(!identValue.convertsTo!float || !value.convertsTo!float)
                        {
                            halt(
                                "Invalid types in assignment expression. (",
                                identValue.type, " and ", value.type, ")"
                            ); // TODO: Use more friendly types rather than Variant.type
                        }

                        switch(type) with(TokenType)
                        {
                            case OP_MULTIPLY_EQUAL:
                                value = identValue * value; break;

                            case OP_DIVIDE_EQUAL:
                                value = identValue / value; break;

                            case OP_MINUS_EQUAL:
                                value = identValue - value; break;

                            default: enforce(0); break;
                        }
                    }
                    else if(type == OP_PLUS_EQUAL)
                    {
                        if((identValue.convertsTo!string && !value.convertsTo!string) ||
                           (identValue.convertsTo!float  && !value.convertsTo!float ))
                        {
                            halt(
                                "Invalid types in assignment expression. (",
                                identValue.type, " and ", value.type, ")"
                            ); // TODO: Use more friendly types rather than Variant.type
                        }

                        if(identValue.convertsTo!string)
                            value = Variant(identValue.get!string ~ value.get!string);
                        else value = identValue + value;
                    }

                    if(isStatic)
                    {
                        enforce(foundScope.parentStruct !is null, "Static definitions must belong to a struct.");

                        if(!structIsStatic(foundScope.parentStruct))
                        {
                            Struct staticStruct = foundScope.parentStruct.bodyScope.parent.getStruct(
                                foundScope.parentStruct.name
                            ).staticInstance;

                            staticStruct.bodyScope.defineVariable(
                                new Variable(ident, value, isPrivate, isStatic)
                            );
                        }
                        else
                        {
                            foundScope.parentStruct.bodyScope.defineVariable(
                                new Variable(ident, value, isPrivate, isStatic)
                            );
                        }
                    }
                    else 
                    {
                        foundScope.defineVariable(
                            new Variable(ident, value, isPrivate, isStatic)
                        );
                    }
                }
                else
                {
                    halt(
                        "Cannot assign \"", ident,
                        "\" because it is a ", 
                        foundType == 'f' ? "function" : "struct",
                        "."
                    );
                }
            }
        }
    }

public:
    static mixin Getter!(Interpreter, "instance"   );
           mixin Getter!(Scope,       "globalScope");
           mixin Property!(Scope,     "currentScope");
           mixin Property!(Function, "currentFunction");

    void halt(Type...)(Type messageParts)
    {
        import std.conv:   to;
        import std.stdio:  stderr;
        import std.format: format;

        string message;

        if(m_currentFunction is null) 
            message = format("Fatal error (%s): ", m_globalScope.filePath);
        else message = format("Fatal error (%s): ", m_currentFunction.containerScope.filePath);

        foreach(part; messageParts)
            message ~= part.to!string;

        stderr.writeln(message);

        throw new Exception("Interpreter Exception");
    }

    Variant resolveValue(Node value)
    {
        if(value.isA!ValueNode)
            return resolveValue(cast(ValueNode) value);

        return resolveValue(cast(ValueNode) (new ValueNode).addChild(value));
    }

    Variant resolveValue(ValueNode value)
    {
        Node node = value.children[0];

        char foundType;
        Scope foundScope;

        if(node.isA!ParenNode)
        {
            enforce(node.children.length == 1, "ParenNode had more than 1 child");
            node = node.children[0];
        }

        if(node.isA!DotNode)
        {
            return _dot(cast(DotNode) node);
        }

        if(node.isA!LiteralNode)
            return (cast(LiteralNode) node).value;

        if(node.isA!IdentNode)
        {
            string ident = (cast(IdentNode) node).value;

            if(m_currentScope.find(ident, foundType, foundScope, true))
            {
                if(foundType == 'v')
                {
                    bool _, isStatic;
                    Variant result = foundScope.getValue(ident, _, isStatic);
                    
                    if(isStatic)
                    {
                        return foundScope.parentStruct.bodyScope.parent.getStruct(
                            foundScope.parentStruct.name
                        ).staticInstance.bodyScope.getValue(ident);
                    }

                    return result;
                }
                else if(foundType == 'f')
                {
                    return Variant(foundScope.getFunc(ident));
                }
                else if(foundType == 's')
                {
                    //enforce(0, "Unimplemented type as value: " ~ ident);
                    return Variant(foundScope.getStruct(ident).staticInstance);
                }
                else enforce(0); // Future proofing I guess
            }
            else
            {
                m_currentScope.print;
                halt("Undefined identifier: ", ident);
            }
        }

        if(node.isA!FuncCallNode)
        {
            return _funcCall(cast(FuncCallNode) node);
        }

        if(node.isA!NotNode)
        {
            return Variant(!_variantAsBool(
                resolveValue(node.children[0])
            ));
        }

        if(node.isA!TypeNode)
        {
            Variant typeValue = resolveValue(node.children[0]);

            if(typeValue.convertsTo!string)
                return Variant("string");

            if(typeValue.convertsTo!float)
            {
                string typeString = typeValue.to!string;

                if(typeString == "true" || typeString == "false")
                    return Variant("boolean");

                return Variant("number");
            }

            if(typeValue.convertsTo!(Variant[]))
                return Variant("array");

            if(typeValue.convertsTo!Struct)
                return Variant("struct:" ~ (typeValue.get!Struct).name);

            // TODO: Create way to find how many arguments a function requires,
            //       probably from a method other than type_of.
            if(typeValue.convertsTo!Function)
                return Variant("function");

            return Variant(typeValue.type.toString);
        }

        if(node.isA!ArrayNode)
        {
            Variant[] result;

            foreach(item; node.children)
                result ~= resolveValue(item);

            return Variant(result);
        }

        if(node.isA!SignedNode)
        {
            char sign = (
                (cast(MathOpNode) node.children[0]).type == TokenType.OP_PLUS
            ) ? '+' : '-';

            Variant signedValue = resolveValue(node.children[1]);

            if(!signedValue.convertsTo!float)
                halt("Cannot apply a sign to a non-number type.");

            return Variant(
                sign == '+' ? +(signedValue.get!float) : -(signedValue.get!float)
            );
        }

        if(node.isA!IndexNode)
        {
            Variant operand = resolveValue(node.children[0]);
            Variant index   = resolveValue(node.children[1]);

            // Combine these checks
            if(!(index.convertsTo!float))
                halt("Index ", index, " must be a positive integral number.");
            else if(index.get!float % 1 != 0 || index.get!float < 0)
                halt("Index ", index, " must be a positive integral number.");

            if(!(operand.convertsTo!string) && !(operand.convertsTo!(Variant[])))
                halt("Cannot index ", operand.type, " type");

            if(operand.convertsTo!string)
                return Variant((operand.get!string)[cast(uint) index.get!float] ~ "");

            if(operand.convertsTo!(Variant[]))
                return Variant((operand.get!(Variant[]))[cast(uint) index.get!float]);
        }

        if(node.isA!CompNode)
        {
            // TODO: CHANGE THIS
            if(node.children.length != 3)
            {
                node.printTree;
                halt("Comparison didn't contained exactly two operands.");
            }

            Variant a = resolveValue(node.children[0]);
            Variant b = resolveValue(node.children[2]);

            TokenType operator = (cast(CompOpNode) node.children[1]).type;

            with(TokenType)
            switch(operator)
            {
                case OP_EQUAL:          return Variant(a == b);
                case OP_NOT_EQUAL:      return Variant(a != b);
                case OP_GREATER:        return Variant(a  > b);
                case OP_LESS:           return Variant(a  < b);
                case OP_GREATER_EQUAL:  return Variant(a >= b);
                case OP_LESS_EQUAL:     return Variant(a <= b);

                default: enforce(0);
            }
        }

        if(node.isA!LogicalNode)
        {
            enforce(
                node.children.length >= 3 && node.children.length % 2 != 0,
                "Invalid logical expresion."
            );

            bool a, b;
            TokenType operator;

            with(TokenType)
            for(uint i = 0; i < node.children.length; i++)
            {
                if(i == 0)
                {
                    a = _variantAsBool(
                        resolveValue(node.children[0])
                    );

                    operator = (cast(LogicalOpNode) node.children[i + 1]).type;
                    
                    if(operator == OP_AND && !a) return Variant(false);

                    b = _variantAsBool(
                        resolveValue(node.children[2])
                    );

                    if(operator == OP_OR)
                         a = a || b;
                    else a = a && b;

                    i += 2;
                }
                else
                {
                    
                    operator = (cast(LogicalOpNode) node.children[i]).type;

                    if(operator == OP_AND && !a) return Variant(false);

                    b = _variantAsBool(
                        resolveValue(node.children[i + 1])
                    );

                    if(operator == OP_OR)
                         a = a || b;
                    else a = a && b;

                    i++;
                }
            }

            return Variant(a);
        }

        // TODO: Consider getting rid of StrCatNode in favor of MathNode.
        //       Although, debugging MathNode is essentially hell on Earth.
        if(node.isA!StrCatNode)
        {
            string concatted;

            foreach(child; node.children)
                concatted ~= resolveValue(child).get!string;

            return Variant(concatted);
        }

        if(node.isA!MathNode)
        {
            string[] mathStream;

            TokenType exprType = TokenType.NONE;

            with(TokenType)
            foreach(child; node.children)
            {
                if(child.isA!MathOpNode)
                {
                    TokenType type = (cast(MathOpNode) child).type;

                    if(exprType == STRING)
                    {
                        if(type != OP_PLUS)
                            halt("Cannot operate on a string with operator ", type, '.');

                        continue;
                    }

                    switch(type)
                    {
                        case OP_PLUS:       mathStream ~= "+"; break;
                        case OP_MINUS:      mathStream ~= "-"; break;
                        case OP_DIVIDE:     mathStream ~= "/"; break;
                        case OP_MULTIPLY:   mathStream ~= "*"; break;
                        case OP_MODULO:     mathStream ~= "%"; break;

                        default: enforce(0);
                    }
                }
                else
                {
                    Variant operand = resolveValue(
                        cast(ValueNode) ((new ValueNode).addChild(child))
                    );

                    if(exprType == NONE)
                    {
                        if(operand.convertsTo!float)
                            exprType = NUMBER;

                        else if(operand.convertsTo!string)
                            exprType = STRING;

                        else halt(`Cannot operate on "`, operand, '"');
                    }
                    else if(
                        (exprType == NUMBER && !(operand.convertsTo!float )) ||
                        (exprType == STRING && !(operand.convertsTo!string)) ||
                        (!(operand.convertsTo!float) && !(operand.convertsTo!string))
                    ) 
                    {
                        node.printTree;
                        writeln(exprType);
                        writeln(operand);
                        writeln(operand.type);
                        halt(`Mismatched types in math expression.`);
                    }

                    string opStr = operand.to!string;

                    // Because apparently true and false convertTo!float...
                    if(opStr == "true" || opStr == "false")
                        halt(`Unexpected boolean in math expression.`);


                    mathStream ~= opStr;
                }
            }

            if(exprType == TokenType.STRING)
                return  Variant(mathStream.join);
            else return Variant(MathParser.parseInfix(mathStream));
        }

        writeln("\n\n\nUnresolved value");
        value.printTree;

        return Variant(null);
    }

    Variant getGlobalVariable(string ident)
    {
        Scope s;
        char  t;

        if(g.find(ident, t, s) && t == 'v')
            return g.getValue(ident);
        else return Variant(null);
    }

    this(string path)
    {
        //auto startTime = MonoTime.currTime;

        m_fileName = path;
        //m_path = path.absolutePath.dirName;

        Token[] tokenStream = new Tokenizer(readText(path), m_fileName).stream;

        ASTGenerator.init(tokenStream);
        //ASTGenerator.result.printTree;

        m_globalScope = new Scope("global");
        m_globalScope.filePath = path;

        m_currentScope = m_globalScope;

        Interpreter oldInstance = m_instance;
        m_instance = this;

        bool _;

        evaluate(ASTGenerator.result, _, m_globalScope);

        if(oldInstance !is null)
            m_instance = oldInstance;

        /*auto now = MonoTime.currTime;
        auto elapsed = cast(Duration)(now - startTime);*/

        //writeln(cast(float) elapsed.total!"usecs" / 1000.0f, "ms");

        //writeln("\n\n\n");
        //m_globalScope.print;
    }

    this(BaseNode ast, string path)
    {
        m_fileName = path;
        m_path = path.absolutePath.dirName;

        m_globalScope = new Scope("global");
        m_globalScope.filePath = path;

        m_currentScope = m_globalScope;

        Interpreter oldInstance = m_instance;

        m_instance = this;

        bool _;
        evaluate(ast, _, m_globalScope);

        if(oldInstance !is null)
            m_instance = oldInstance;
    }

    Variant evaluate(BaseNode base, ref bool stop, ref Scope scp)
    {
        if(scp is null) scp = m_currentScope;

        Scope oldScope = m_currentScope;

        if(scp == m_globalScope)
            m_currentScope = m_globalScope;
        else
        {
            m_currentScope.addChild(scp);
            m_currentScope = scp;
        }

        Variant result = Variant(null);
        bool hasResult = false;

        BaseNode replacementNode = null;

        for(uint i = 0; i < base.children.length; i++)
        {
            Node child = base.children[i];

            _node(child, hasResult, result, stop, replacementNode);

            if(replacementNode !is null)
                base.replaceNode(i--, replacementNode.children);

            if(hasResult || stop) break;
        }

        scp = m_currentScope;
        m_currentScope = oldScope;

        return result;
    }
}
