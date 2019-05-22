module moose.interpreter.rpn;

import std.string: isNumeric;
import std.algorithm: canFind;
import std.conv: to;
import std.array: join;
import std.math: round;

/// A struct representing a data stack with pop and push methods
struct Stack(Type)
{
    /// The list of items
    private Type[] _items = [];

    /// Add an item to the stack
    void push(Type item)
    {
        _items ~= item;
    }

    /// Remove the last item from the stack and return it
    Type pop()
    {
        Type item = _items[$ - 1];
        _items = _items[0 .. $ - 1];
        
        return item;
    }

    /// Override the [] operators
    ref Type opIndex(int i)
    {
        return _items[i];
    }

    /// Handle foreach
    int opApply(scope int delegate(ref Type) dg)
    {
        for(int i = 0; i < _items.length; i++)
        {
            int result = dg(_items[i]);
            if(result != 0)
            {
                return result;
            }
        }
        
        return 0;
    }

    /// The number of items
    @property uint length()
    {
        return cast(uint) _items.length;
    }
}

/// A class that parses infix and RPN expressions
static class MathParser
{
private static:
    char[] _operators = ['+', '-', '*', '/', '%'];

    float _evaluate(char op, float a, float b)
    {
        switch(op)
        {
            case '+': return a + b;
            case '-': return b - a;
            case '*': return a * b;
            case '/': return b / a;
            case '%': return b % a;

            default: assert(0);
        }
    }

public static:
    /// Parse an array representing a Reverse Polish Notation expression
    float parseRPN(Stack!string tokens)
    {
        Stack!float stack;

        foreach(token; tokens)
        {
            if(token.isNumeric())
            {
                stack.push(token.to!float);
            }
            else if (_operators.canFind(token[0]))
            {
                stack.push(_evaluate(token[0], stack.pop(), stack.pop()));
            }
        }

        return stack.pop;
    }

    /// Parse an array representing an infix expression 
    float parseInfix(string[] tokens)
    {
        uint[char] precedences = [
            '*': 3,
            '/': 3,
            '%': 3,
            '+': 2,
            '-': 2
        ];

        Stack!string queue;
        Stack!char   stack;

        foreach(token; tokens)
        {
            if(token.isNumeric())
            {
                queue.push(token);
            }
            else if (_operators.canFind(token[0]))
            {
                const char op = token[0];
                int i = stack.length - 1;

                while(
                    stack.length > 0 && _operators.canFind(stack[i]) &&
                    precedences[stack[i]] >= precedences[op]
                )
                {
                    queue.push("" ~ stack.pop());
                    i = stack.length - 1;
                }

                stack.push(op);
            }
            else assert(0, token);
            /*else if (token[0] == '(')
            {
                stack.push('(');
            }
            else if (token[0] == ')')
            {
                for(int i = stack.length - 1; i >= 0; i--)
                {
                    const char item = stack[i];

                    if(item != '(')
                    {
                        queue.push("" ~ stack.pop());
                    }
                    else 
                    {
                        stack.pop();
                    }
                }
            }*/
        }

        for(int i = stack.length - 1; i >= 0; i--)
        {
            queue.push("" ~ stack.pop());
        }

        return parseRPN(queue);
    }
}
