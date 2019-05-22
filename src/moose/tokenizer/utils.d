module moose.tokenizer.utils;

import std.regex: StaticRegex, matchFirst;

import moose.tokenizer.token;

/// Check if the given character matches the regex.
package bool matches(string)(string character, StaticRegex!char regex)
{
    return matchFirst(character, regex).length > 0;
}

/// Return the character at the index, as a string.
package string at(string)(string container, uint index)
{
    return container[index] ~ "";
}

// Get the proper token type for a string representation of the operator.
package TokenType operatorToTokenType(string operator)
{
    with(TokenType) switch(operator)
    {
        case "=": return OP_ASSIGN;
        case "!": return OP_NOT;
        case ":": return OP_DEFINE;
        case "+": return OP_PLUS;
        case "-": return OP_MINUS;
        case "/": return OP_DIVIDE;
        case "*": return OP_MULTIPLY;
        case "%": return OP_MODULO;
        case "<": return OP_LESS;
        case ">": return OP_GREATER;

        case "==": return OP_EQUAL;
        case "!=": return OP_NOT_EQUAL;
        case "<=": return OP_LESS_EQUAL;
        case ">=": return OP_GREATER_EQUAL;
        case "+=": return OP_PLUS_EQUAL;
        case "-=": return OP_MINUS_EQUAL;
        case "/=": return OP_DIVIDE_EQUAL;
        case "*=": return OP_MULTIPLY_EQUAL;
        case "++": return OP_INCREMENT;
        case "--": return OP_DECREMENT;

        case "=>": return OP_STRUCT_DEFINE;

        case "&&": return OP_AND;
        case "||": return OP_OR;

        default: 
            assert(0, "Invalid operator: " ~ operator);
    }
}

package void expectString(string a, string b, string f = __FILE__, int l = __LINE__)
{
    import std.conv: to;

    // TODO: Add line numbers.
    assert(a == b, "Parse error: Expected '" ~ b  ~ "' but got '" ~ a ~ "'. From " ~ f ~ " line " ~ l.to!string);
}

