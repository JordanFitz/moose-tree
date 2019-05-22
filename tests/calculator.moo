load "basic.moo";
load "string.moo";
load "array.moo";
load "conv.moo";
load "map.moo";

is_numeric: (in) {
    for char; in {
        code: __internal(get_char_code, char);
        if code < 48 || code > 57 { return false; }
    }

    return true;
}

is_op: (in) {
    return in == "+" || in == "-" || in == "/" || in == "*";
}

validate_parts: (parts) {
    last_type: null;
    paren_count: 0;

    for part; parts {
        if last_type == null || last_type == "op" {
            if type_of(part) != "number" && part != "(" {
                print_line("Expected a number but got this instead: ", part, "\n");
                return false;
            } else if type_of(part) == "number" {
                last_type = "num";
            } else if part == "(" {
                paren_count += 1;
                last_type = null;
            }
        } else if last_type == "num" {
            if !part.is_op() && part != ")" {
                print_line("Expected an operator but got this instead: ", part, "\n");
                return false;
            } else if part.is_op() {
                last_type = "op";
            } else if part == ")" {
                if paren_count <= 0 {
                    print_line("Mismatched parens!\n");
                    return false;
                }

                paren_count -= 1;
                last_type = "num";
            }
        }
    }

    if paren_count != 0 {
        print_line("Mismatched parens!\n");
        return false;
    }

    return true;
}

get_parts: (input) {
    result: [];

    last_was_op: false;
    cur_num: "";

    for char; input {
        if char.is_numeric() {
            cur_num += char;
            last_was_op = false;
        } else if char != " " {
            if cur_num.len() > 0 {
                result.append(cur_num.to_number());
                cur_num = "";
            }

            if char == "(" || char == ")" {
                result.append(char);
                last_was_op = false;
            } else if char.is_op() {
                result.append(char);
                last_was_op = true;
            } else {
                print_line("Unexpected character: ", char, "\n");
                return [];
            }
        }
    }

    if cur_num.len() > 0 {
        result.append(cur_num.to_number());
        cur_num = "";
    }

    return result;
}

operate: (op, a, b) {
    if op == "+" { return a + b; }
    if op == "-" { return a - b; }
    if op == "/" { return a / b; }
    if op == "*" { return a * b; }

    assert(0, "Invalid operator: " + op);
}

infix: (parts) {
    precedences: Map();
    precedences.set("*", 3);
    precedences.set("/", 3);
    precedences.set("+", 2);
    precedences.set("-", 2);

    queue: [];
    stack: [];

    for part; parts {
        if type_of(part) == "number" {
            queue.append(part);
        } else if part.is_op() {
            i: stack.len() - 1;

            while stack.len() > 0 && stack[i].is_op() && precedences.get(stack[i]) >= precedences.get(part) {
                queue.append(stack.pop());
                i = stack.len() - 1;
            }

            stack.append(part);
        } else if part == "(" {
            stack.append(part);
        } else if part == ")" {
            while stack[stack.len() - 1] != "(" {
                queue.append(stack.pop());
            }

            stack.pop();
        }
    }

    while stack.len() > 0 {
        queue.append(stack.pop());
    }

    return queue;
}

postfix: (parts) {
    stack: [];

    for item; parts {
        if type_of(item) == "number" {
            stack.append(item);
        } else if item.is_op() {
            b: stack.pop();
            a: stack.pop();

            stack.append(operate(item, a, b));
        }
    }

    return stack.pop();
}

main: () {
    print_line("calculator.moo: Enter math expressions for evaluation.");
    print_line();

    while true {
        print("> ");
        input: read_line().trim_spaces();

        if input == "q" {
            print_line("\nQuitting.");
            break;
        } else {
            parts: get_parts(input);

            if parts.len() > 0 {
                if validate_parts(parts) {
                    result: postfix(infix(parts));
                    print_line("= ", result, "\n");
                }
            }
        }
    }
}

main();
