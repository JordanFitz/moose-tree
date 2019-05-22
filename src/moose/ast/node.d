module moose.ast.node;

import property;

import moose.tokenizer.token;



private static const
bool SHOW_STREAMS = false;
//bool SHOW_STREAMS = true;



private mixin template NType()
{
    protected override @property
    string _type() { return typeof(this).stringof; }
}

abstract class Node
{
protected:
    Node[] m_children;

    // The subsection of the main token stream which makes up a node.
    Token[] m_stream;

    abstract @property string _type();

public:
    mixin Getter!(Node[], "children");
    mixin Getter!(Token[], "stream");

    this(Token[] stream)
    {
        m_stream = stream;
    }

    Node setChildren(Node[] newChildren)
    {
        m_children = newChildren;
        return this;
    }

    Node addChildren(Node[] newChildren)
    {
        m_children ~= newChildren;
        return this;
    }

    Node addChild(Node child)
    {
        m_children ~= child;
        return this;
    }

    Node setStream(Token[] stream)
    {
        m_stream = stream;
        return this;
    }

    Node replaceNode(uint index, Node[] newNodes)
    {
        Node[] old = m_children;

        if(index > 0)
            m_children = old[0 .. index];
        else m_children = [];

        m_children ~= newNodes ~ old[index + 1 .. $];

        return this;
    }

    void printTree(string indent = "")
    {
        import std.stdio: writeln;

        writeln(indent, _type, " ", SHOW_STREAMS ? m_stream : []);

        foreach(child; m_children)
            child.printTree(indent ~ "   ");
    }
}

/*
 * BASE NODE
 */ 

class BaseNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * TYPE() NODE
 */ 

class TypeNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * STRUCT NODE
 */ 

class StructNode: Node
{
    mixin NType;

    bool m_exported;
    bool m_privated;
    bool m_staticed; // holy shit

public:
    mixin Getter!(bool, "exported");
    mixin Getter!(bool, "privated");
    mixin Getter!(bool, "staticed");
    
    StructNode setAttributes(bool exported, bool privated, bool staticed)
    {
        m_exported = exported;
        m_privated = privated;
        m_staticed = staticed;
        return this;
    }

    this(Token[] stream = [])
    {
        super(stream);
    }
}


/*
 * IDENT NODE
 */ 

class IdentNode: Node
{
    mixin NType;

private:
    string m_value;
    bool m_flagged;

public:
    mixin Getter!(string, "value");
    mixin Getter!(bool, "flagged");

    this(string value, bool flagged = false)
    {
        super([]);
        m_value = value;
        m_flagged = flagged;
    }

    override void printTree(string indent = "")
    {
        import std.stdio: writeln;
        writeln(indent, "ident: ", m_flagged ? "@" : "", m_value);
    }
}

/*
 * VAR DEF NODE
 */ 

class VarDefNode: Node
{
    mixin NType;

    // I would call this `m_export` but `export` is a reserved keyword in D
    bool m_exported;
    bool m_privated;    
    bool m_staticed;    

public:
    mixin Getter!(bool, "exported");
    mixin Getter!(bool, "privated");
    mixin Getter!(bool, "staticed");

    VarDefNode setAttributes(bool exported, bool privated, bool staticed)
    {
        m_exported = exported;
        m_privated = privated;
        m_staticed = staticed;
        return this;
    }

    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * NOT NODE
 */ 

class NotNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * MODULE NODE
 */ 

class ModNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * VAR ASSIGNMENT NODE
 */ 

class VarAssignNode: Node
{
    mixin NType;

    TokenType m_type;

public:
    mixin Getter!(TokenType, "type");

    VarAssignNode setType(TokenType t)
    {
        m_type = t;
        return this;
    }

    this(Token[] stream)
    {
        super(stream);
    }
}


/*
 * FUNC CALL NODE
 */ 

class FuncCallNode: Node
{
    mixin NType;

public:
    this(Token[] stream  = [])
    {
        super(stream);
    }
}

/*
 * FOR LOOP NODE
 */ 

class ForNode: Node
{
    mixin NType;

public:
    this(Token[] stream  = [])
    {
        super(stream);
    }
}

/*
 * WHILE LOOP NODE
 */ 

class WhileNode: Node
{
    mixin NType;

public:
    this(Token[] stream  = [])
    {
        super(stream);
    }
}

/*
 * IF STATEMENT NODE
 */ 

class IfNode: Node
{
    mixin NType;

public:
    this(Token[] stream  = [])
    {
        super(stream);
    }
}

/*
 * LOAD STATEMENT NODE
 */ 

class LoadNode: Node
{
    mixin NType;

public:
    this(Token[] stream  = [])
    {
        super(stream);
    }
}

/*
 * ELSE STATEMENT NODE
 */ 

class ElseNode: Node
{
    mixin NType;

public:
    this(Token[] stream  = [])
    {
        super(stream);
    }
}

/*
 * ARRAY DEFN NODE
 */ 

class ArrayNode: Node
{
    mixin NType;

public:
    this(Token[] stream  = [])
    {
        super(stream);
    }
}

/*
 * MATH EXPR NODE
 */ 

class MathNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * FUNCTION DEFINITION NODE
 */ 

class FuncDefNode: Node
{
    mixin NType;

    bool m_exported;
    bool m_privated;
    bool m_staticed;

public:
    mixin Getter!(bool, "exported");
    mixin Getter!(bool, "privated");
    mixin Getter!(bool, "staticed");

    FuncDefNode setAttributes(bool exported, bool privated, bool staticed)
    {
        m_exported = exported;
        m_privated = privated;
        m_staticed = staticed;
        return this;
    }

    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * LOGICAL EXPR NODE
 */ 

class LogicalNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * DOT EXPR NODE
 */ 

class DotNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * SIGNED THING NODE
 */ 

class SignedNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * LOGICAL EXPR NODE
 */ 

class SpreadNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * RETURN STMT NODE
 */ 

class ReturnNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}


/*
 * BREAK STMT NODE
 */ 

class BreakNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}


/*
 * COMPARISON NODE
 */ 

class CompNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * PAREN EXPR NODE
 */ 

class ParenNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * ARRAY INDEX NODE
 */ 

class IndexNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super(stream);
    }
}

/*
 * MATH OPERATOR NODE
 */ 

class MathOpNode: Node
{
    mixin NType;

private:
    TokenType m_type;

public:
    mixin Getter!(TokenType, "type");

    this(TokenType type)
    {
        super([]);
        m_type = type;
    }

    override void printTree(string indent = "")
    {
        import std.stdio: writeln;
        writeln(indent, _type, " ", m_type);
    }
}

/*
 * COMPARISON OPERATOR NODE
 */ 
class CompOpNode: Node
{
    mixin NType;

private:
    TokenType m_type;

public:
    mixin Getter!(TokenType, "type");

    this(TokenType type)
    {
        super([]);
        m_type = type;
    }

    override void printTree(string indent = "")
    {
        import std.stdio: writeln;
        writeln(indent, _type, " ", m_type);
    }
}

/*
 * COMPARISON OPERATOR NODE
 */ 
class LogicalOpNode: Node
{
    mixin NType;

private:
    TokenType m_type;

public:
    mixin Getter!(TokenType, "type");
    
    this(TokenType type)
    {
        super([]);
        m_type = type;
    }

    override void printTree(string indent = "")
    {
        import std.stdio: writeln;
        writeln(indent, _type, " ", m_type);
    }
}

/*
 * STRING CONCATENATION NODE
 */ 

class StrCatNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super([]);
    }
}

/*
 * VALUE NODE
 */ 

class ValueNode: Node
{
    mixin NType;

public:
    this(Token[] stream = [])
    {
        super([]);
    }
}

/*
 * ARGUMENT LIST NODE
 */ 

class ArgListNode: Node
{
    mixin NType;
    bool m_any = false;

public:
    mixin Property!(bool, "any");

    this(Token[] stream = [])
    {
        super([]);
    }
}

/*
 * LITERAL NODE
 */ 

class LiteralNode: Node
{
    mixin NType;

private:
    Variant m_value;

public:
    Variant value() @property
    {
        return m_value;
    }

    this(Variant value)
    {
        super([]);
        m_value = value;
    }

    override void printTree(string indent = "")
    {
        import std.stdio: writeln;
        writeln(indent, "literal: ", m_value);
    }
}
