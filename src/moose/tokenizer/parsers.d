module moose.tokenizer.parsers;

import std.algorithm: canFind;
import std.regex: ctRegex, StaticRegex;

import moose.tokenizer.main;
import moose.tokenizer.token;
import moose.tokenizer.utils;

import property;

package int   LINE_NUMBER = 1;
package int   COLUMN      = 1;
package int   LAST_I      = 0;

private static void LN(uint i)
{
    LINE_NUMBER++;
    LAST_I = i + 1;
}

private
{   
    auto R_IDENT_START = ctRegex!(`[A-Za-z_]`);
    auto R_WHITESPACE  = ctRegex!(`\s`);
    auto R_OPERATOR    = ctRegex!(`[!%=><*+:&|\/\-]`);
    auto R_NUMBER      = ctRegex!(`[0-9]`);
    auto R_IDENT       = ctRegex!(`[A-Za-z0-9_]`);
}

alias tokenizer = Tokenizer.instance;

package static struct Parsers
{
package static:
    void main(string code, uint location)
    {
        for(uint i = location; i < code.length; i++)
        {
            string character = code.at(i);

            if(character == "\n") LN(i);

            // Ignore whitespace
            if(character.matches(R_WHITESPACE))
                continue;

            if(character.matches(R_IDENT_START))
                return tokenizer.addParser(&parseIdentifier, i);

            if(character.matches(R_OPERATOR))
                return tokenizer.addParser(&parseOperator, i);

            if(character.matches(R_NUMBER))
                return tokenizer.addParser(&parseNumber, i);

            COLUMN = i - LAST_I + 1;

            with(TokenType) switch(character)
            {
                case `"`:
                    return tokenizer.addParser(&parseString, i);

                case "#":
                    return tokenizer.addParser(&parseComment, i);

                case ".":
                    return tokenizer.addParser(&parseDot, i);

                case ";":
                {
                    tokenizer.addToken(new Token(TERMINATOR));
                    continue;
                }

                case "@":
                {
                    tokenizer.addToken(new Token(AT));
                    continue;
                }

                case ",":
                {
                    tokenizer.addToken(new Token(COMMA));
                    continue;
                }

                // Parens
                case "(":
                {
                    tokenizer.addToken(new Token(OPAREN));
                    return tokenizer.addParser(&parseParenthetical, i);
                }

                case ")": // TODO: Fix unmatched
                    return tokenizer.popParser(i);

                // Brackets
                case "{":
                {
                    tokenizer.addToken(new Token(OBRACKET));
                    return tokenizer.addParser(&parseBrackets, i);
                }
                
                case "}":
                    return tokenizer.popParser(i);

                // Square brackets
                case "[":
                {
                    tokenizer.addToken(new Token(OSQUARE));
                    return tokenizer.addParser(&parseSquareBrackets, i);
                }
                
                case "]":
                    return tokenizer.popParser(i);

                case "\0": 
                {
                    tokenizer.addToken(new Token(END_OF_INPUT));
                    return;
                }

                default: break;
            }

            assert(0, "Unexpected '" ~ character ~ '\'');
        }
    }

    void parseDot(string code, uint location)
    {
        assert(code.at(location) == ".");

        uint dotCount = 1;

        COLUMN = location - LAST_I + 1;

        for(uint i = location; i < code.length; i++)
        {
            string character = code.at(i);

            if(i == location)     continue;            
            if(character == "\n") LN(i);
            if(character == ".")  dotCount++;

            assert(dotCount < 4, "Too many dots");

            if(character != ".")
            {
                if(dotCount == 1)
                {
                    tokenizer.addToken(new Token(TokenType.DOT));
                    return tokenizer.popParser(i);
                }
                else if(dotCount == 3)
                {
                    tokenizer.addToken(new Token(TokenType.SPREAD));
                    return tokenizer.popParser(i);
                }
                else
                {
                    assert(0, "Not the right number of dots");
                }
            }            
        }
    }

    void parseIdentifier(string code, uint location)
    {
        assert(code.at(location).matches(R_IDENT_START));

        string identifier = "";

        COLUMN = location - LAST_I + 1;

        for(uint i = location; i < code.length; i++)
        {
            string character = code.at(i);

            if(character == "\n") LN(i);

            if(character.matches(R_IDENT))
            {
                identifier ~= character;
            }
            else 
            {
                switch(identifier)
                {
                    case "true":
                        goto case;

                    case "false":
                        tokenizer.addToken(new Token(TokenType.BOOLEAN, identifier)); break;

                    case "null":
                        tokenizer.addToken(new Token(TokenType.NULL)); break;

                    case "if":
                        tokenizer.addToken(new Token(TokenType.IF)); break;

                    case "else":
                        tokenizer.addToken(new Token(TokenType.ELSE)); break;

                    case "for":
                        tokenizer.addToken(new Token(TokenType.FOR)); break;

                    case "foreach":
                        tokenizer.addToken(new Token(TokenType.FOREACH)); break;

                    case "while":
                        tokenizer.addToken(new Token(TokenType.WHILE)); break;

                    case "return":
                        tokenizer.addToken(new Token(TokenType.RETURN)); break;

                    case "load":
                        tokenizer.addToken(new Token(TokenType.LOAD)); break;

                    case "mod":
                        tokenizer.addToken(new Token(TokenType.MODULE)); break;

                    case "break":
                        tokenizer.addToken(new Token(TokenType.BREAK)); break;

                    case "type_of":
                        tokenizer.addToken(new Token(TokenType.TYPE)); break;

                    case "export":
                        tokenizer.addToken(new Token(TokenType.EXPORT)); break;

                    case "private":
                        tokenizer.addToken(new Token(TokenType.PRIVATE)); break;

                    case "static": 
                        tokenizer.addToken(new Token(TokenType.STATIC)); break;

                    default:
                        tokenizer.addToken(new Token(TokenType.IDENT, identifier));
                }

                return tokenizer.popParser(i);
            }
        }
    }

    /// Parses an operator or series of operators.
    void parseOperator(string code, uint location)
    {
        assert(code.at(location).matches(R_OPERATOR));

        const string[] validOperators = [
            "=", "!", ":", "+","-",
            "/", "*", "%", "<", ">",

            "==", "!=", "<=",">=",
            "+=", "-=", "/=", "*=",
            "++", "--",

            "=>",

            "&&", "||",
        ];

        string operator = "";

        COLUMN = location - LAST_I + 1;

        for(uint i = location; i < code.length; i++)
        {
            string character = code.at(i);

            if(character == "\n") LN(i);

            // NOTE: This will call canFind an extra time because
            //       it is called regardless if the character matches
            //       the operator regex. Also, it will be called even if
            //       this is the first character of the operator.
            //
            // TODO: Consider changing this. 

            const bool valid = validOperators.canFind(operator ~ character);

            if(character.matches(R_OPERATOR) && (operator.length == 0 || valid))
            {
                operator ~= character;
            }
            else 
            {
                tokenizer.addToken(new Token(operatorToTokenType(operator)));
                return tokenizer.popParser(i);
            }
        }
    }

    /// Parses a string starting with the first character of the string.
    void parseString(string code, uint location)
    {
        assert(code.at(location) == `"`);

        string result = "";
        bool   escape = false;

        COLUMN = location - LAST_I + 1;

        for(uint i = location; i < code.length; i++)
        {
            string character = code[i] ~ "";

            if(character == "\n") LN(i);
            if(i == location) continue;

            if(!escape && character == `\`)
            {
                escape = true;
                continue;
            }

            if(!escape && character == `"`)
            {
                tokenizer.addToken(new Token(TokenType.STRING, result));
                return tokenizer.popParser(++i);
            }

            if(escape)
            {
                switch(character)
                {
                    // TODO: Add escape sequences

                    case "n": result ~= '\n'; break;
                    case "0": result ~= "\0"; break;
                    case `"`: result ~= `"`;  break;
                    case `\`: result ~= `\`;  break;

                    default: assert(0, `Unhandled escape sequence \` ~ character);
                }

                escape = false;
            } else result ~= character;
        }
    }

    /// Parse a number. Can be integer or decimal.
    void parseNumber(string code, uint location)
    {
        assert(code.at(location).matches(R_NUMBER));

        string number = "";

        COLUMN = location - LAST_I + 1;

        for(uint i = location; i < code.length; i++)
        {
            string character = code.at(i);

            if(character == "\n") LN(i);

            if(character.matches(R_NUMBER))
            {
                number ~= character;
            }
            else if (character == ".")
            {
                assert(!number.canFind("."), "Unexpected '.' in number.");

                number ~= ".";
            }
            else 
            {
                // Test the validity of the number.
                // TODO: Do this in a better way.

                import std.conv: to;
                to!float(number);

                tokenizer.addToken(new Token(TokenType.NUMBER, number));
                return tokenizer.popParser(i);
            }
        }
    }

    /// Parse a comment starting with a # and ending at a new line.
    void parseComment(string code, uint location)
    {
        assert(code.at(location) == "#");

        string comment = "";

        for(uint i = location; i < code.length; i++)
        {
            string character = code.at(i);

            //if(character == "\n") LN(i);

            if(character == "\n" || character == "\r")
            {
                LN(i);
                tokenizer.addToken(new Token(TokenType.COMMENT, comment));
                return tokenizer.popParser(++i);
            }
            else 
            {
                comment ~= character;
            }
        }
    }

    /// Things with boundaries such as {}, (), and []
    void parseBoundary(string type, string code, uint location)
    {
        assert(type.length == 2);

        string opening = type.at(0);
        string closing = type.at(1);

        if(code.at(location) != opening)
        {
            if(code.at(location) != closing)
            {
                expectString(code.at(location), closing);
            }
        }

        for(uint i = location; i < code.length; i++)
        {
            string character = code.at(i);

            if(i == location && character == opening)
                continue;

            if(character == closing)
            {
                TokenType tokenType;

                with(TokenType)
                final switch(closing)
                {
                    case ")": tokenType = CPAREN;   break;
                    case "}": tokenType = CBRACKET; break;
                    case "]": tokenType = CSQUARE;  break;
                }

                COLUMN = i - LAST_I + 1;

                tokenizer.addToken(new Token(tokenType));
                return tokenizer.popParser(++i);
            }
            else 
            {
                // If we haven't reached the end of this section,
                // we go back to parsing normally, by adding a "main" layer.
                return tokenizer.addParser(&main, i);
            }
        }
    }

    /// Parse something within parentheses.
    void parseParenthetical(string code, uint location)
    {
        parseBoundary("()", code, location);
    }

    /// Parse something within parentheses.
    void parseBrackets(string code, uint location)
    {
        parseBoundary("{}", code, location);
    }

    /// Parse something within square brackets.
    void parseSquareBrackets(string code, uint location)
    {
        parseBoundary("[]", code, location);
    }
}
