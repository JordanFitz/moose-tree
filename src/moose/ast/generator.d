module moose.ast.generator;

debug import std.stdio: writeln;

import std.algorithm: canFind;
import std.exception: enforce;

import property;

import moose.ast.node;
import moose.tokenizer.token;

private enum {
    F_BASE          = 1 << 0,
    F_IDENT         = 1 << 1,
    F_OP_DEF        = 1 << 2,
    F_LITERAL       = 1 << 3,
    F_MATH_OP       = 1 << 4,
    F_STR_CAT       = 1 << 5,
    F_PAREN         = 1 << 6,
    F_COMP_OP       = 1 << 7,
    F_LOGICAL_OP    = 1 << 8,
    F_ARG_LIST      = 1 << 9,
    F_BRACKET       = 1 << 10,
    F_FOR           = 1 << 11,
    F_TERM          = 1 << 12,
    F_IF            = 1 << 13,
    F_SQUARE        = 1 << 14,
    F_ASSIGN        = 1 << 15,
    F_RETURN        = 1 << 16,
    F_INDEX         = 1 << 17,
    F_DOT           = 1 << 18,
    F_SPREAD        = 1 << 19,
    F_WHILE         = 1 << 20,
    F_ELSE          = 1 << 21,
    F_LOAD          = 1 << 22,
    F_TYPE          = 1 << 23,
    F_MOD           = 1 << 24,
    F_NOT           = 1 << 25,
    F_EXPORT        = 1 << 26,
    F_OP_STRUCT     = 1 << 27,
    F_PRIVATE       = 1 << 28,
    F_BREAK         = 1 << 29,
    F_STATIC        = 1 << 30,
}

private enum {
    RETN         = F_BASE | F_RETURN,
    DEFN         = F_BASE | F_IDENT | F_OP_DEF,
    ASSIGN       = F_BASE | F_IDENT | F_ASSIGN,
    FCALL        = F_BASE | F_IDENT | F_PAREN,
    FOR_IDENT    = F_BASE | F_FOR   | F_IDENT,
    IF_STMT      = F_BASE | F_IF    | F_BRACKET,
    STRUCT_DEFN  = F_BASE | F_IDENT | F_OP_STRUCT,
    ELSE_STMT    = F_BASE | F_IF    | F_BRACKET | F_ELSE,
    FOR_TERM     = F_BASE | F_FOR   | F_IDENT   | F_TERM,
    ARG_LIST     = F_BASE | F_IDENT | F_OP_DEF  | F_ARG_LIST,
    FDEFN        = F_BASE | F_IDENT | F_OP_DEF  | F_ARG_LIST | F_BRACKET,
    FOR_LOOP     = F_BASE | F_FOR   | F_IDENT   | F_TERM     | F_BRACKET,
}

private alias TT = TokenType;

private static
TT[] _mathOperators = [
    TT.OP_PLUS,
    TT.OP_MINUS,
    TT.OP_DIVIDE,
    TT.OP_MULTIPLY,
    TT.OP_MODULO,
];

private static 
TT[] _comparisonOperators = [
    TT.OP_EQUAL,
    TT.OP_NOT_EQUAL,
    TT.OP_GREATER,
    TT.OP_GREATER_EQUAL,
    TT.OP_LESS,
    TT.OP_LESS_EQUAL,
];

private static
TT[] _operators = [
    TT.OP_PLUS,
    TT.OP_MINUS,
    TT.OP_DIVIDE,
    TT.OP_MULTIPLY,
    TT.OP_MODULO,
    TT.OP_EQUAL,
    TT.OP_NOT_EQUAL,
    TT.OP_GREATER,
    TT.OP_GREATER_EQUAL,
    TT.OP_LESS,
    TT.OP_LESS_EQUAL,
    TT.OP_AND,
    TT.OP_OR,
];

private static 
TT[] _assignmentOperators = [
    TT.OP_ASSIGN,
    TT.OP_MULTIPLY_EQUAL,
    TT.OP_DIVIDE_EQUAL,
    TT.OP_PLUS_EQUAL,
    TT.OP_MINUS_EQUAL
];

private static bool isLiteral(Token token)
{
    return isLiteral(token.type);
}

private static bool isLiteral(TokenType type)
{
    with(TokenType)
    return type == STRING || type == NULL || type == NUMBER || type == BOOLEAN;
}

static class ASTGenerator
{
private static:
    Token[] m_stream;

    BaseNode m_result;

public static:
    mixin Property!(BaseNode, "result");

    void init(Token[] stream)
    {
        m_stream = stream;
        m_result = new BaseNode(stream);

        uint i = 0;

        processBase(stream, i, m_result, TT.END_OF_INPUT, true);
    }
}

private void expect(bool condition, string message, Token token)
{
    if(condition) return;

    import std.stdio: stderr;

    token.indicate;
    stderr.writeln("Parse error: ", message);

    throw new Exception("Parse Error");
}

private void processBase(
    Token[] stream,
    ref uint i,
    Node cn,
    TokenType endDelim,
    bool isBase    = false,
    bool exporting = false,
    bool privating = false,
    bool staticing = false, // the sickest word
    bool exportStatement = false)
{
    int flags = F_BASE;
    uint start = i;
    uint storedIndex = 0;

    ArgListNode argList;

    Token fDefnIdent;
    Token forIdent;

    ValueNode forValue;
    ValueNode condition;

    with(TokenType)
    for(; i < stream.length; i++)
    {
        Token token = stream[i];

        if(token.type == COMMENT) continue;

        if(flags == F_BASE)
        {
            if(token.type == endDelim) break;

            storedIndex = i;

            if(token.type == IDENT)
            {
                flags |= F_IDENT;
                token = stream[++i];

                if(token.type == OP_DEFINE)
                    flags |= F_OP_DEF;

                else if(token.type == OP_STRUCT_DEFINE)
                    flags |= F_OP_STRUCT;

                else if(_assignmentOperators.canFind(token.type))
                    flags |= F_ASSIGN;

                else 
                {
                    i--;

                    ValueNode value = eatValue(stream, i, TERMINATOR ~ _assignmentOperators);

                    if(_assignmentOperators.canFind(stream[i].type))
                    {
                        
                        i++;
                        ValueNode assignment = eatValue(stream, i, [TERMINATOR]);

                        cn.addChild(
                            (new VarAssignNode(stream[storedIndex .. i + 1]).setType(stream[i].type))
                                .addChildren(value.children)
                                .addChild(assignment)
                        );

                    }
                    else cn.addChildren(value.children);

                    flags = F_BASE;
                }
            }

            else if(token.type == FOR)
                flags |= F_FOR;

            else if(token.type == IF)
                flags |= F_IF;

            else if(token.type == RETURN)
                flags |= F_RETURN;

            else if(token.type == WHILE)
                flags |= F_WHILE;

            else if(token.type == LOAD)
                flags |= F_LOAD;

            else if(token.type == EXPORT)
                flags |= F_EXPORT;

            else if(token.type == PRIVATE)
                flags |= F_PRIVATE;

            else if(token.type == STATIC)
                flags |= F_STATIC;

            else if(token.type == MODULE)
            {
                expect(
                    cn.children.length == 0 && isBase,
                    "'mod' statement must be at the beginning of the file.",
                    token
                );

                flags |= F_MOD;
            }

            else if(token.type == BREAK)
                flags |= F_BREAK;

            else
            {
                cn.addChildren(eatValue(stream, i, [TERMINATOR]).children);
                flags = F_BASE;
            }
        }

        else if(flags == (F_BASE | F_BREAK))
        {
            expect(token.type == TERMINATOR, "Expected ; after 'break' keyword.", token);
            cn.addChild(new BreakNode);
            flags = F_BASE;
        }

        else if(flags == (F_BASE | F_EXPORT))
        {
            expect(isBase, "Cannot use 'export' outside of global scope.", stream[i-1]);

            if(token.type == OBRACKET)
            {
                i++;

                BaseNode bodyNode = new BaseNode;
                processBase(stream, i, bodyNode, CBRACKET, false, true);

                cn.addChildren(bodyNode.children);
            }
            else if(token.type == IDENT)
            {
                BaseNode bodyNode = new BaseNode;
                processBase(stream, i, bodyNode, TERMINATOR, false, true, false, false, true);

                Node child = bodyNode.children[0];

                // Make sure the thing we're exporting is a definition of some sort.
                if(bodyNode.children.length != 1 || (
                   typeid(child) != typeid(FuncDefNode) &&
                   typeid(child) != typeid(VarDefNode)  &&
                   typeid(child) != typeid(StructNode)
                )) expect(false, "Cannot export non-definition statements.", token);

                cn.addChild(child);
            }
            else expect(false, "Expected { or an identifier after 'export' keyword.", token);

            flags = F_BASE;
        }

        else if(flags == (F_BASE | F_PRIVATE))
        {
            if(token.type == OBRACKET)
            {
                i++;

                BaseNode bodyNode = new BaseNode;
                processBase(stream, i, bodyNode, CBRACKET, false, false, true, staticing);

                cn.addChildren(bodyNode.children);
            }
            else if(token.type == IDENT/* || token.type == STATIC*/) // TODO: Make it so you can private static
            {
                BaseNode bodyNode = new BaseNode;
                processBase(stream, i, bodyNode, TERMINATOR, false, false, true, staticing, true);

                Node child = bodyNode.children[0];

                // Make sure the thing we're privating is a var def or func def.
                if(bodyNode.children.length != 1 || (
                   typeid(child) != typeid(FuncDefNode) &&
                   typeid(child) != typeid(VarDefNode)
                )) expect(false, "Cannot make private non-definition statements.", token);

                cn.addChild(child);
            }
            else expect(false, "Expected { or an identifier after 'private' keyword.", token);

            flags = F_BASE;
        }

        else if(flags == (F_BASE | F_STATIC))
        {
            if(token.type == OBRACKET)
            {
                i++;

                BaseNode bodyNode = new BaseNode;
                processBase(stream, i, bodyNode, CBRACKET, false, false, privating, true);

                cn.addChildren(bodyNode.children);
            }
            else if(token.type == IDENT/* || token.type == PRIVATE*/)
            {
                BaseNode bodyNode = new BaseNode;
                processBase(stream, i, bodyNode, TERMINATOR, false, false, privating, true, true);

                Node child = bodyNode.children[0];

                // Make sure the thing we're staticing is a var def or func def.
                if(bodyNode.children.length != 1 || (
                   typeid(child) != typeid(FuncDefNode) &&
                   typeid(child) != typeid(VarDefNode)
                )) expect(false, "Cannot make static non-definition statements.", token);

                cn.addChild(child);
            }
            else expect(false, "Expected { or an identifier after 'static' keyword.", token);

            flags = F_BASE;
        }

        else if(flags == (F_BASE | F_MOD))
        {
            expect(token.type == IDENT, "Expected an identifier after 'mod'.", token);
            expect(
                stream[i+1].type == TERMINATOR,
                "Expected ; after mod " ~ token.contents,
                stream[i+1]
            );

            cn.addChild(
                (new ModNode).addChild(
                    new IdentNode(token.contents)
                )
            );

            i++;

            flags = F_BASE;
        }

        else if(flags == (F_BASE | F_LOAD))
        {
            expect(
                token.type == STRING,
                "Expected string after 'load'.",
                token
            );

            expect(
                stream[i + 1].type == TERMINATOR,
                "Expected ; after load \"" ~ token.contents ~ `".`,
                stream[i + 1]
            );

            ValueNode str = eatValue(stream, i, [TERMINATOR]);

            cn.addChild(
                (new LoadNode).addChildren(str.children)
            );

            flags = F_BASE;
        }

        else if(flags == (F_BASE | F_IDENT))
            enforce(0);

        else if(flags == STRUCT_DEFN)
        {
            expect(token.type == OBRACKET, "Expected { after struct definition.", token);

            IdentNode ident = new IdentNode(stream[i-2].contents);

            i++;

            BaseNode structBody = new BaseNode;
            processBase(stream, i, structBody, CBRACKET);

            if(exportStatement)
            {
                endDelim = CBRACKET;
                i--;
            }

            // NOTE: This is probably not the most efficient way to validate
            //       the contents of the struct body.

            foreach(child; structBody.children)
            {
                if(typeid(child) != typeid(FuncDefNode) && typeid(child) != typeid(VarDefNode))
                    expect(false,
                        "Structs can only have function and variable definitions in their bodies.",
                        child.stream[0]
                    );
            }

            cn.addChild(
                (new StructNode().setAttributes(exporting, privating, staticing))
                    .addChild(ident)
                    .addChild(structBody)
            );

            flags = F_BASE;
        }

        else if(flags == (F_BASE | F_WHILE))
        {
            condition = eatValue(stream, i, [OBRACKET]);

            i++;

            BaseNode bodyNode = new BaseNode;
            processBase(stream, i, bodyNode, CBRACKET);

            cn.addChild(
                (new WhileNode)
                    .addChild(condition)
                    .addChild(bodyNode)
                    .setStream(stream[storedIndex .. i + 1])
            );

            condition = null;

            flags = F_BASE;
        }

        else if(flags == (F_BASE | F_RETURN))
        {
            ValueNode  value      = eatValue(stream, i, [TERMINATOR]);
            ReturnNode returnNode = new ReturnNode(stream[storedIndex .. i + 1]);

            if(value.children.length > 0)
                returnNode.addChild(value);

            cn.addChild(returnNode);

            flags = F_BASE;
        }

        else if(flags == ASSIGN)
        {
            Token     ident = stream[i-2];
            TT        type  = stream[i-1].type;
            ValueNode value = eatValue(stream, i, [TERMINATOR]);

            cn.addChild(
                new VarAssignNode(stream[storedIndex .. i+1])
                    .setType(type)
                    .addChild(new IdentNode(ident.contents))
                    .addChild(value)
            );

            flags = F_BASE;
        }

        else if(flags == DEFN)
        {
            argList    = null;
            fDefnIdent = stream[i-2];
            argList    = eatArgList(stream, ++i);

            if(argList !is null)
            {
                flags |= F_ARG_LIST;
            }
            else
            {
                i--;

                Token     ident = stream[i-2];
                ValueNode value = eatValue(stream, i, [TERMINATOR]);

                cn.addChild(
                    (cast(VarDefNode) (
                        new VarDefNode(stream[storedIndex .. i+1])
                            .addChild(new IdentNode(ident.contents))
                            .addChild(value)
                        )
                    ).setAttributes(exporting, privating, staticing)
                );

                if(endDelim == TERMINATOR) i--;

                flags = F_BASE;
            }                
        }

        else if(flags == (F_BASE | F_FOR))
        {
            expect(token.type == IDENT, "Expected an identifier in for loop.", token);
            forIdent = token;
            flags |= F_IDENT;
        }

        else if(flags == FOR_IDENT)
        {
            expect(token.type == TERMINATOR, "Expected a ; in for loop.", token);
            flags |= F_TERM;
        }

        else if(flags == FOR_TERM)
        {
            forValue = eatValue(stream, i, [OBRACKET]);
            expect(forValue.children.length > 0, "Expected an expression in for loop.", token);
            flags |= F_BRACKET;
        }

        else if(flags == FOR_LOOP)
        {
            enforce(forValue !is null, "forValue was null");

            BaseNode bodyNode = new BaseNode;
            processBase(stream, i, bodyNode, CBRACKET);

            cn.addChild(
                (new ForNode)
                    .addChild(new IdentNode(forIdent.contents))
                    .addChild(forValue)
                    .addChild(bodyNode)
                    .setStream(stream[storedIndex .. i + 1])
            );

            forValue = null;
            forIdent = new Token;

            flags = F_BASE;
        }

        else if(flags == (F_BASE | F_IF))
        {
            condition = eatValue(stream, i, [OBRACKET]);
            flags |= F_BRACKET;
        }

        else if(flags == IF_STMT)
        {
            enforce(condition !is null, "condition was null on if");

            BaseNode bodyNode = new BaseNode;
            processBase(stream, i, bodyNode, CBRACKET);

            cn.addChild(
                (new IfNode)
                    .addChild(condition)
                    .addChild(bodyNode)
                    .setStream(stream[storedIndex .. i + 1])
            );

            if(stream[i+1].type == ELSE)
            {
                flags |= F_ELSE;
                i++;
            }
            else flags = F_BASE;

            condition = null;            
        }

        else if(flags == ELSE_STMT)
        {
            // I don't think this can actually get triggered ever...
            expect(
                cn.children.length > 0 && typeid(cn.children[$ - 1]) == typeid(IfNode),
                "Unexpected else block.",
                stream[i - 1]
            );

            enforce(condition is null, "Condition was not null in else");

            if(token.type == IF)
            {
                i++;
                condition = eatValue(stream, i, [OBRACKET]);
            }

            if(stream[i].type != OBRACKET)
                expect(false, "Expected { or `if` after `else`.", stream[i]);

            i++;

            BaseNode bodyNode = new BaseNode;
            processBase(stream, i, bodyNode, CBRACKET);

            ElseNode elseNode = new ElseNode;

            if(condition !is null)
                elseNode.addChild(condition);

            elseNode.addChild(bodyNode);

            cn.children[$ - 1].addChild(elseNode);

            condition = null;

            if(stream[i + 1].type != ELSE)
                flags = F_BASE;
            else i++;
        }

        else if(flags == ARG_LIST)
        {
            if(token.type == OBRACKET)
                flags |= F_BRACKET;
            else expect(false, "Expected a { after function parameter list.", token);
        }

        else if(flags == FDEFN)
        {
            enforce(argList !is null, "argList was null");
            BaseNode bodyNode = new BaseNode;

            processBase(stream, i, bodyNode, CBRACKET);

            cn.addChild(
                (cast(FuncDefNode) (
                    (new FuncDefNode)
                        .addChild(new IdentNode(fDefnIdent.contents))
                        .addChild(argList)
                        .addChild(bodyNode)
                        .setStream(stream[storedIndex .. i + 1]))
                    ).setAttributes(exporting, privating, staticing)
            );

            if(exportStatement)
            {
                endDelim = CBRACKET;
                i--;
            }

            fDefnIdent = new Token;
            argList = null;

            flags = F_BASE;
        }
    }

    cn.setStream(stream[start .. i]);
}

private ArgListNode eatArgList(Token[] stream, ref uint i)
{
    ArgListNode result = new ArgListNode;

    uint start = i;
    int flags = F_BASE;

    with(TokenType)
    for(; i < stream.length; i++)
    {
        Token token = stream[i];

        if(token.type == CPAREN)
        {
            break;
        }

        expect(
            flags != F_SPREAD,
            "... must be the last part of a function's parameter list.",
            stream[i-1]
        );

        if(flags == F_BASE)
        {
            if(token.type == AT)
                token = stream[++i];

            if(token.type == IDENT)
            {
                flags = F_IDENT;

                result.addChild(
                    new IdentNode(token.contents, stream[i - 1].type == AT)
                );
            }
            else if(token.type == SPREAD)
            {
                result.any = true;
                flags = F_SPREAD;
            }
            else
            {
                i = start;
                return null;
            }
        }
        else if(flags == F_IDENT)
        {
            if(token.type == COMMA)
            {
                flags = F_BASE;
            }
            else
            {
                i = start;
                return null;
            }
        }
    }

    result.setStream(stream[start .. i]);

    return result;
}

private FuncCallNode eatFuncCall(Token[] stream, ref uint i)
{
    FuncCallNode result = new FuncCallNode;

    result.addChild(
        new IdentNode(stream[i-2].contents)
    );

    uint start = i;
    int flags = F_BASE;

    with(TokenType)
    while(i == start || stream[i].type == COMMA)
    {
        if(stream[i].type == COMMA) i++;

        result.addChildren(
            eatValue(stream, i, [COMMA, CPAREN]).children
        );

        if(stream[i].type == CPAREN) break;
    }

    result.setStream(stream[start - 2 .. i+1]);

    return result;
}

private ArrayNode eatArrayDefn(Token[] stream, ref uint i)
{
    ArrayNode result = new ArrayNode;

    uint start = i;
    int flags = F_BASE;

    with(TokenType)
    while(i == start || stream[i].type == COMMA)
    {
        if(stream[i].type == COMMA) i++;

        result.addChildren(
            eatValue(stream, i, [COMMA, CSQUARE]).children
        );

        if(stream[i].type == CSQUARE) break;
    }

    result.setStream(stream[start .. i+1]);

    return result;
}

private enum 
{
    VAL_LITERAL  = F_BASE | F_LITERAL,
    VAL_LIT_MATH = F_BASE | F_LITERAL | F_MATH_OP,
    VAL_LIT_COMP = F_BASE | F_LITERAL | F_COMP_OP,
    VAL_LIT_LOG  = F_BASE | F_LITERAL | F_LOGICAL_OP,
    VAL_STR_CAT  = F_BASE | F_LITERAL | F_STR_CAT,
    VAL_IDENT    = F_BASE | F_IDENT,
    VAL_PAREN    = F_BASE | F_PAREN,
    VAL_MATH     = F_BASE | F_MATH_OP,
    VAL_COMP     = F_BASE | F_COMP_OP,
    VAL_LOGICAL  = F_BASE | F_LOGICAL_OP,
    VAL_SQUARE   = F_BASE | F_SQUARE,
    VAL_INDEX    = F_BASE | F_INDEX,
    VAL_NOT      = F_BASE | F_NOT,
}

private ValueNode eatValue(Token[] stream, ref uint i, TokenType[] endDelims, bool startCannotBeEnd = false)
{
    ValueNode result = new ValueNode;

    int flags = F_BASE;
    uint start = i;
    uint storedIndex;

    MathNode     mathNode    = null;
    CompNode     compNode    = null;
    StrCatNode   strCatNode  = null;
    FuncCallNode fCallNode   = null;
    LogicalNode  logicalNode = null;
    IndexNode    indexNode   = null;

    with(TokenType)
    for(; i < stream.length; i++)
    {
        Token token = stream[i];

        if(flags == F_BASE)
        {
            // TODO: Make this optionally show a message?
            // NOTE: What is going on here and why did I want to show a message for this?
            if(!startCannotBeEnd || i != start)
                if(endDelims.canFind(token.type)) break;

            if(isLiteral(token))
                flags |= F_LITERAL;

            else if(token.type == SPREAD)
                flags |= F_SPREAD;

            else if(token.type == IDENT)
                flags |= F_IDENT;

            else if(token.type == OPAREN)
                flags |= F_PAREN;

            else if(token.type == OP_NOT)
                flags |= F_NOT;

            else if(token.type == OSQUARE)
            {
                if(result.children.length == 0)
                    flags |= F_SQUARE;
                else
                {
                    enforce(indexNode is null);

                    indexNode = new IndexNode;
                    indexNode.addChild(result.children[$-1]);

                    flags |= F_INDEX;
                }
            }

            else if(token.type == TYPE)
            {
                flags |= F_TYPE;
            }

            else if(token.type == DOT)
            {
                expect(result.children.length > 0, "Unexpected dot.", token);

                DotNode dotNode = new DotNode;
                dotNode.addChild(result.children[$-1]);

                i++;

                ValueNode dotValue = eatValue(stream, i, endDelims ~ _operators);

                dotNode.addChildren(
                    dotValue.children
                );

                i--;

                result.setChildren([]);
                result.addChild(dotNode);
            }

            else if(token.type == OP_AND || token.type == OP_OR)
            {
                expect(result.children.length > 0, "Unexpected operator.", token);
                enforce(logicalNode is null);

                if(typeid(result.children[$ - 1]) == typeid(LogicalNode))
                    logicalNode = cast(LogicalNode) result.children[$ - 1];
                else
                {
                    logicalNode = new LogicalNode;
                    logicalNode.addChild(result.children[$ - 1]);
                }

                logicalNode.addChild(
                    new LogicalOpNode(token.type)
                );

                flags |= F_LOGICAL_OP;
            }

            else if(_mathOperators.canFind(token.type))
            {
                if(result.children.length == 0)
                {
                    if(token.type == OP_PLUS || token.type == OP_MINUS)
                    {

                        i++;

                        result.addChild(
                            (new SignedNode)
                                .addChild(new MathOpNode(token.type))
                                .addChildren(eatValue(stream, i, endDelims ~ _operators).children)
                        );

                        i--;

                        continue;

                    }
                }

                expect(result.children.length > 0, "Unexpected operator.", token);
                enforce(mathNode is null);

                if(typeid(result.children[$ - 1]) == typeid(MathNode))
                    mathNode = cast(MathNode) result.children[$ - 1];
                else
                {
                    mathNode = new MathNode;
                    mathNode.addChild(result.children[$ - 1]);
                }

                mathNode.addChild(
                    new MathOpNode(token.type)
                );

                flags |= F_MATH_OP;
            }

            else if(_comparisonOperators.canFind(token.type))
            {
                expect(result.children.length > 0, "Unexpected comparison operator.", token);
                enforce(compNode is null);

                if(typeid(result.children[$ - 1]) == typeid(CompNode))
                    compNode = cast(CompNode) result.children[$ - 1];
                else
                {
                    compNode = new CompNode;
                    compNode.addChild(result.children[$ - 1]);
                }

                compNode.addChild(
                    new CompOpNode(token.type)
                );

                flags |= F_COMP_OP;
            }

            else expect(0, "Unexpected token", token);
        }
        
        else if(flags == (F_BASE | F_SPREAD))
        {
            result.addChild(
                (new SpreadNode).addChildren(
                    eatValue(stream, i, endDelims ~ _operators).children
                )
            );

            i--;

            flags = F_BASE;
        }

        else if(flags == VAL_INDEX)
        {
            indexNode.addChildren(
                eatArrayIndex(stream, i, null).children
            );

            result.setChildren([]);
            result.addChild(indexNode);

            flags = F_BASE;
        }

        else if(flags == VAL_SQUARE)
        {
            result.addChild(eatArrayDefn(stream, i));
            flags = F_BASE;
        }

        else if(flags == VAL_LOGICAL)
        {
            logicalNode.addChildren(
                eatValue(stream, i, endDelims ~ OP_AND ~ OP_OR).children
            );

            logicalNode.setStream(stream[storedIndex .. i]);

            result.setChildren([]);
            result.addChild(logicalNode);

            logicalNode = null;
            flags = F_BASE;
            i--;
        }

        else if(flags == VAL_MATH)
        {
            mathNode.addChildren(
                eatValue(stream, i, _operators ~ endDelims).children
            );

            mathNode.setStream(stream[storedIndex .. i]);

            result.setChildren([]);
            result.addChild(mathNode);

            mathNode = null;
            flags = F_BASE;
            i--;
        }

        else if(flags == VAL_NOT)
        {
            result.addChild(
                (new NotNode).addChildren(
                    eatValue(stream, i, endDelims ~ _operators).children
                )
            );

            i--;

            flags = F_BASE;
        }

        else if (flags == VAL_COMP)
        {
            compNode.addChildren(
                eatValue(stream, i, _comparisonOperators ~ endDelims ~ OP_AND ~ OP_OR).children
            );

            compNode.setStream(stream[storedIndex .. i]);

            result.setChildren([]);
            result.addChild(compNode);

            compNode = null;
            flags = F_BASE;
            i--;
        }

        else if(flags == VAL_LITERAL)
        {
            if(endDelims.canFind(token.type))
            {
                result.addChild(new LiteralNode(stream[i-1].toVariant));
                break;
            }

            // Comparisons
            if(_comparisonOperators.canFind(token.type))
            {
                flags |= F_COMP_OP;

                storedIndex = i-1;

                enforce(compNode is null, "compNode was not null");

                compNode = new CompNode;

                compNode.addChild(
                    new LiteralNode(stream[i-1].toVariant)
                );

                compNode.addChild(
                    new CompOpNode(token.type)
                );
            }

            else if(token.type == OSQUARE)
            {
                LiteralNode literal =  new LiteralNode(stream[i-1].toVariant);

                i++;

                result.addChild(
                    eatArrayIndex(stream, i, cast(ValueNode) ((new ValueNode).addChild(literal)))
                );

                flags = F_BASE;
            }

            else if(token.type == DOT)
            {
                DotNode dotNode = new DotNode;
                dotNode.addChild(new LiteralNode(stream[i-1].toVariant));

                i++;

                ValueNode dotValue = eatValue(stream, i, endDelims ~ _operators);

                dotNode.addChildren(
                    dotValue.children
                );

                i--;

                result.addChild(dotNode);

                flags = F_BASE;
            }

            // Logical
            else if(token.type == OP_AND || token.type == OP_OR)
            {
                flags |= F_LOGICAL_OP;

                storedIndex = i-1;

                enforce(logicalNode is null, "logicalNode was not null");

                logicalNode = new LogicalNode;

                logicalNode.addChild(
                    new LiteralNode(stream[i-1].toVariant)
                );

                logicalNode.addChild(
                    new LogicalOpNode(token.type)
                );
            }

            // Math 
            else if(stream[i-1].type == NUMBER && _mathOperators.canFind(token.type))
            {
                flags |= F_MATH_OP;

                storedIndex = i-1;

                enforce(mathNode is null, "mathNode was not null");

                mathNode = new MathNode;

                mathNode.addChild(
                    new LiteralNode(stream[i-1].toVariant)
                );

                mathNode.addChild(
                    new MathOpNode(token.type)
                );
            }
            //
            // String concat
            // TODO: Replace this so it just uses a MathNode.
            //
            else if(stream[i-1].type == STRING && token.type == OP_PLUS)
            {
                flags |= F_STR_CAT;

                enforce(strCatNode is null, "strCatNode was not null");

                strCatNode = new StrCatNode;

                strCatNode.addChild(
                    new LiteralNode(stream[i-1].toVariant)
                );
            }
            else if(_mathOperators.canFind(token.type))
                expect(false, "trying to operate on an invalid type.", stream[i - 1]);
        }

        else if(flags == (F_BASE | F_TYPE))
        {
            expect(token.type == OPAREN, "Expected ( after 'type'.", token);
            
            i++;

            ValueNode of = eatValue(stream, i, [CPAREN]);

            result.addChild(
                (new TypeNode).addChildren(of.children)
            );

            flags = F_BASE;
        }

        else if(flags == VAL_LIT_COMP)
        {
            if(endDelims.canFind(token.type))
            {
                compNode.setStream(stream[storedIndex .. i]);
                result.addChild(compNode);
                break;
            }
            else if(_comparisonOperators.canFind(token.type))
            {
                compNode.addChild(
                    new CompOpNode(token.type)
                );
            }
            else if(_mathOperators.canFind(token.type))
            {
                uint lastChildI = cast(uint) compNode.children.length - 1;

                if(compNode.children[lastChildI].stream.length == 0)
                    i--;
                else i -= compNode.children[lastChildI].stream.length;

                ValueNode math =
                    eatValue(stream, i, endDelims ~ _comparisonOperators);

                compNode.replaceNode(lastChildI, math.children);

                i--;
            }
            else if(token.type == OP_AND || token.type == OP_OR) 
            {
                enforce(logicalNode is null, "logicalNode was not null in comp expr");
                logicalNode = new LogicalNode;
                logicalNode.addChild(compNode.setStream(stream[storedIndex .. i]));
                logicalNode.addChild(new LogicalOpNode(token.type));

                flags = VAL_LIT_LOG;
            }
            else if(token.type == OPAREN)
            {
                i++;
                compNode.addChild(
                    (new ParenNode).addChildren(eatValue(stream, i, [CPAREN]).children).setStream(stream[storedIndex .. i])
                );
            }
            else if(!endDelims.canFind(token.type))
            {
                // NOTE: Changed _operators to OP_AND ~ OP_OR, don't know if 
                //       that broke something.

                compNode.addChildren(
                    eatValue(stream, i, endDelims ~ _comparisonOperators ~ OP_AND ~ OP_OR).children
                );

                i--;
            }
        }

        else if(flags == VAL_LIT_LOG)
        {
            if(endDelims.canFind(stream[i].type))
            {
                logicalNode.setStream(stream[storedIndex .. i]);
                result.addChild(logicalNode);
                break;
            }
            else if(token.type == OP_AND || token.type == OP_OR)
            {
                logicalNode.addChild(
                    new LogicalOpNode(token.type)
                );
            }
            else if(_comparisonOperators.canFind(token.type))
            {
                uint lastChildI = cast(uint) logicalNode.children.length - 1;

                if(compNode.children[lastChildI].stream.length == 0)
                    i--;
                else i -= compNode.children[lastChildI].stream.length;

                ValueNode comp =
                    eatValue(stream, i, endDelims ~ OP_AND ~ OP_OR);

                logicalNode.replaceNode(lastChildI, comp.children);

                i--;
            }
            else if(_mathOperators.canFind(token.type))
            {
                enforce(mathNode is null, "mathNode was not null in log expr");
                mathNode = new MathNode;
                mathNode.addChild(logicalNode.setStream(stream[storedIndex .. i]));
                mathNode.addChild(new MathOpNode(token.type));
                flags = VAL_LIT_MATH;
            }
            else if(token.type == OPAREN)
            {
                storedIndex = i;
                i++;
                logicalNode.addChild(
                    (new ParenNode).addChildren(eatValue(stream, i, [CPAREN]).children).setStream(stream[storedIndex .. i+1])
                );
            }
            else if(!endDelims.canFind(token.type))
            {
                logicalNode.addChildren(
                    eatValue(stream, i, endDelims ~ OP_AND ~ OP_OR).children
                );
                i--;
            }
        }

        else if(flags == VAL_LIT_MATH)
        {
            // TODO: handle stuff like 1 + / 2
            //       and stuff like (1 + 2 + )

            enforce(mathNode.children.length > 1);

            if(typeid(mathNode.children[$ - 1]) == typeid(MathOpNode))
            {
                // The coming thing is a signed node
                if(token.type == OP_PLUS || token.type == OP_MINUS)
                {
                    mathNode.addChildren(
                        eatValue(stream, i, endDelims ~ _operators, true).children
                    );
                }
                else 
                {
                    mathNode.addChildren(
                        eatValue(stream, i, endDelims ~ _operators).children
                    );
                }

                i--;

                continue;
            }

            if(endDelims.canFind(stream[i].type))
            {
                mathNode.setStream(stream[storedIndex .. i]);
                result.addChild(mathNode);

                break;
            }

            else if(_mathOperators.canFind(token.type))
            {
                if(typeid(mathNode.children[$ - 1]) == typeid(MathOpNode))
                    expect(false, "Unexpected operator", token);

                mathNode.addChild(
                    new MathOpNode(token.type)
                );
            }
            else if(_comparisonOperators.canFind(token.type))
            {
                enforce(compNode is null, "compNode was not null in math expr");
                compNode = new CompNode;
                compNode.addChild(mathNode.setStream(stream[storedIndex .. i]));
                compNode.addChild(new CompOpNode(token.type));
                flags = VAL_LIT_COMP;
            }
            else if(token.type == OP_AND || token.type == OP_OR) 
            {
                enforce(logicalNode is null, "logicalNode was not null in math expr");
                logicalNode = new LogicalNode;
                logicalNode.addChild(mathNode.setStream(stream[storedIndex .. i]));
                logicalNode.addChild(new LogicalOpNode(token.type));
                flags = VAL_LIT_LOG;
            }
            else if(token.type == OPAREN)
            {
                storedIndex = i;
                i++;

                mathNode.addChild(
                    (new ParenNode).addChildren(eatValue(stream, i, [CPAREN]).children).setStream(stream[storedIndex .. i+1])
                );
            }
            else if(!endDelims.canFind(token.type))
            {
                enforce(0); // NOTE: I don't think we need this check anymore so I'm just 
                           //       crashing if we reach it for now

                /*mathNode.addChildren(
                    eatValue(stream, i, _operators ~ endDelims).children
                );
                i--;*/
            }
        }

        else if(flags == VAL_STR_CAT)
        {
            if(/*stream[i-1].type == STRING &&*/ token.type == OP_PLUS)
            {
                // do nothing?
            }
            else if(stream[i-1].type == OP_PLUS && token.type == STRING)
            {
                strCatNode.addChild(
                    new LiteralNode(token.toVariant)
                );
            }
            else if(stream[i-1].type == OP_PLUS)
            {
                strCatNode.addChild(
                    eatValue(stream, i, endDelims ~ OP_PLUS)
                );

                // TODO: This probably broke something...
                i--;
            }
            else if(endDelims.canFind(token.type))
            {
                result.addChild(strCatNode);
                break;
            }
            else expect(false, "Unexpected token in string concatenation expression.", token);
        }

        else if(flags == VAL_IDENT)
        {
            if(endDelims.canFind(token.type))
            {
                result.addChild(new IdentNode(stream[i-1].contents));
                break;
            }

            if(token.type == OPAREN)
            {
                i++;
                result.addChild(eatFuncCall(stream, i));
                flags = F_BASE;
            }

            if(token.type == OSQUARE)
            {
                IdentNode ident   =  new IdentNode(stream[i - 1].contents);
                Node      operand = (new ValueNode).addChild(ident);

                i++;

                result.addChild(
                    eatArrayIndex(stream, i, cast(ValueNode) operand)
                );

                flags = F_BASE;
            }

            if(token.type == DOT)
            {
                DotNode dotNode = new DotNode;
                dotNode.addChild(new IdentNode(stream[i - 1].contents));

                i++;

                ValueNode dotValue = eatValue(stream, i, endDelims ~ _operators);

                dotNode.addChildren(
                    dotValue.children
                );

                i--;

                result.addChild(dotNode);

                flags = F_BASE;
            }

            if(_mathOperators.canFind(token.type))
            {
                enforce(mathNode is null, "mathNode wasn't null in ident math");
                mathNode = new MathNode;
                mathNode.addChild(new IdentNode(stream[i-1].contents)).addChild(new MathOpNode(token.type));
                flags = VAL_LIT_MATH;
            }

            if(_comparisonOperators.canFind(token.type))
            {
                enforce(compNode is null, "compNode wasn't null in ident math");
                compNode = new CompNode;
                compNode.addChild(new IdentNode(stream[i-1].contents)).addChild(new CompOpNode(token.type));
                flags = VAL_LIT_COMP;
            }

            if(token.type == OP_AND || token.type == OP_OR)
            {
                enforce(logicalNode is null, "mathNode wasn't null in ident math");
                logicalNode = new LogicalNode;
                logicalNode.addChild(new IdentNode(stream[i-1].contents)).addChild(new LogicalOpNode(token.type));
                flags = VAL_LIT_LOG;
            }
        }

        else if(flags == VAL_PAREN)
        {
            storedIndex = i-1;

            result.addChild(
                (new ParenNode)
                    .addChildren(eatValue(stream, i, [CPAREN]).children)
                    .setStream(stream[storedIndex .. i+1])
            );

            flags = F_BASE;
        }
    }

    if(result.children.length > 1)
    {
        result.printTree;
        stream[i].indicate;
        enforce(0, "ValueNode must have exactly one child.");
    }

    result.setStream(stream[start .. i]);

    return result;
}

IndexNode eatArrayIndex(Token[] stream, ref uint i, ValueNode operand)
{
    IndexNode result = new IndexNode;

    if(operand !is null)
        result.addChildren(operand.children);

    with(TokenType)
    for(; i < stream.length; i++)
    {
        result.addChild(eatValue(stream, i, [COMMA, CSQUARE]));

        if(stream[i].type == CSQUARE) break;

        expect(result.children.length < 5, "Invalid indexing syntax.", stream[i]);

        if(stream[i].type != COMMA)
            expect(false, "Unexpected token in array index.", stream[i]);
    }

    return result;
}
