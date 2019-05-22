module moose.tokenizer.token;

public import std.variant: Variant;

import property;

import std.algorithm: canFind;
import std.conv: to;

import moose.tokenizer.parsers;

static const enum TokenType
{
    NONE=-1,

    IDENT,
    STRING,
    NUMBER,
    BOOLEAN,
    NULL,

    TERMINATOR,
    COMMENT,

    FOR,
    FOREACH,
    WHILE,
    IF,
    ELSE,
    RETURN,
    LOAD,
    MODULE,
    BREAK,
    TYPE,
    EXPORT,
    PRIVATE,
    STATIC,

    OPAREN,
    CPAREN,
    OBRACKET,
    CBRACKET,
    OSQUARE,
    CSQUARE,

    COMMA,
    DOT,
    SPREAD,
    AT,


    OP_DEFINE,        //
    OP_STRUCT_DEFINE,
    OP_ASSIGN, 
    
    OP_INCREMENT,
    OP_DECREMENT,
    OP_NOT,

    OP_PLUS,          //
    OP_MINUS,         // 
    OP_DIVIDE,        //
    OP_MULTIPLY,      //
    OP_MODULO,        //

    OP_EQUAL,         //
    OP_NOT_EQUAL,     //
    OP_GREATER,       //
    OP_LESS,          //
    OP_GREATER_EQUAL, //
    OP_LESS_EQUAL,    //

    OP_MULTIPLY_EQUAL,
    OP_DIVIDE_EQUAL,
    OP_PLUS_EQUAL,
    OP_MINUS_EQUAL,

    OP_AND,           //
    OP_OR,            //



    END_OF_INPUT
}

private static const TokenType[] _convertibleTypes = [
    TokenType.STRING,
    TokenType.NUMBER,
    TokenType.BOOLEAN,
    TokenType.NULL
];

class Token
{
private:
    TokenType m_type;
    string m_contents;

    uint m_column;
    uint m_lineNumber;

    string m_line;
    string m_file;

public:
    this(TokenType type = TokenType.NONE, string contents = null)
    {
        import std.stdio: writeln, write;

        m_type = type;
        m_contents = contents;

        m_lineNumber = LINE_NUMBER;
        m_column = COLUMN;
    }

    mixin Property!(string, "contents");
    mixin Property!(TokenType, "type");

    void setupDebug(string fileName, string[] lines)
    {
        m_file = fileName;

        uint i = m_lineNumber - 1;

        if(i >= 0 && i < lines.length)
            m_line = lines[i];
    }

    void indicate(bool slim = false)
    {
        import std.stdio:  writeln;
        import std.format: format;
        import std.string: strip;

        if(m_type == TokenType.END_OF_INPUT)
        {
            m_column = 1;
            m_line = "-> EOI";
        }

        ulong stripDiff = m_line.length - m_line.strip.length ;

        if(!slim)
            format("\n%s line %d col %d:\n    %s", m_file, m_lineNumber, m_column, m_line.strip).writeln;
        else writeln("\n", m_line);

        string spacing = "";

        for(uint i = 0; i < m_column + (slim ? -1 : 3) - stripDiff; i++)
            spacing ~= ' ';

        writeln(spacing, "^\n");
    }

    Variant toVariant(string file = __FILE__, int line = __LINE__)
    {
        if(!isVariant)
        {
            import std.stdio:  writeln;
            import std.format: format;

            format(
                "\nToken type %s is not convertible to Variant. Called from %s line %d.",
                m_type.to!string, file, line
            ).writeln;

            indicate;

            assert(0);
        }

        assert(
            isVariant, 
            "\nCannot convert type " ~ m_type.to!string ~ " to Variant. Called from " ~ file ~ " line " ~ line.to!string ~ "."
        );

        with(TokenType) switch(m_type)
        {
            case STRING:
                return Variant(m_contents);

            case NUMBER:
                return Variant(to!float(m_contents));

            case BOOLEAN:
                return Variant(m_contents == "true");

            case NULL:
                return Variant(null);

            default: assert(0, "Token type is convertible but conversion was not handled.");
        }
    }

    bool isVariant()
    {
        return _convertibleTypes.canFind(m_type);
    }

    override string toString()
    {
        import std.conv: to;

        if(m_type == TokenType.COMMENT)
            return "#";

        return to!string(m_type) ~ (m_contents !is null ? ": " ~ m_contents : "");
    }
}