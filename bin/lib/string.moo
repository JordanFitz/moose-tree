mod string;

export {
    # Splits the given string into an array
    split: (string, delimiter) {
        result: [];
        temp: "";

        for char; string {
            if char == delimiter {
                result = __internal(array_append, result, temp);
                temp = "";
            } else {
                temp += char;
            }
        }

        load "basic.moo";

        if temp.len() > 0 {
            result = __internal(array_append, result, temp);
        }

        return result;
    }

    # A simple string formatting function
    format: (format_string, ...) {
        load "basic.moo";
        load "conv.moo";

        result: "";
        index: 1;

        for char; format_string {
            if char == "%" {
                if index < args.len() {

                    result = result + args[index].to_string();
                    index += 1;

                } else {
                    __internal(exit, "Error: Incorrect number of arguments in format.");
                }
            } else {
                result += char;
            }
        }

        return result;
    }

    # Inclusive substring functionality
    sub_string: (string, start, end) {
        load "basic.moo";

        if type_of(string) != "string" {
            __internal(exit, "Error: sub_string cannot be used on non-string types.");
        }

        if end < start {
            __internal(exit, "Error: sub_string end index must be greater than start index.");
        }

        if start < 0 || end > string.len() - 1 {
            __internal(exit, "Error: sub_string start and end indices must be within the bounds of the string.");
        }

        result: "";
        i: start;

        while i <= end {
            result += string[i];
            i = i + 1;
        }

        return result;
    }

    # Returns true if the given string starts with the given "what"
    starts_with: (string, what) {
        load "basic.moo";

        if type_of(string) != "string" || type_of(what) != "string" {
            __internal(exit, "Error: starts_with cannot be used on non-string types.");
        }

        what_length: what.len();

        if what_length > string.len() {
            return false;
        }

        if string.sub_string(0, what_length - 1) == what {
            return true;
        }

        return false;
    }

    # Returns true if the given string ends with the given "what"
    ends_with: (string, what) {
        load "basic.moo";

        if type_of(string) != "string" || type_of(what) != "string" {
            __internal(exit, "Error: ends_with cannot be used on non-string types.");
        }

        string_length: string.len();
        what_length: what.len();

        if what_length > string_length {
            return false;
        }

        if string.sub_string(string_length - what_length, string_length - 1) == what {
            return true;
        }

        return false;
    }

    # Converts the given string to uppercase.
    to_upper: (string) {
        result: "";

        for char; string {
            code: __internal(get_char_code, char);

            if code > 96 && code < 123 {
                result += __internal(convert_char_code, code - 32);
            } else {
                result += char;
            }
        }

        return result;
    }

    # Converts the given string to lowercase.
    to_lower: (string) {
        result: "";

        for char; string {
            code: __internal(get_char_code, char);

            if code > 64 && code < 91 {
                result += __internal(convert_char_code, code + 32);
            } else {
                result += char;
            }
        }

        return result;
    }

    # Removes spaces from start and end of string
    trim_spaces: (string) {
        load "basic.moo";

        i: 0;
        string_length: string.len();

        while i < string_length {
            if string[i] != " " {
                break;
            }
            i+=1;
        }

        string = string.sub_string(i, string_length - 1);
        string_length = string.len();

        i = string_length - 1;

        while i >= 0 {
            if string[i] != " " {
                break;
            }
            i-=1;
        }

        return string.sub_string(0, i);
    }
}