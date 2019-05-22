mod basic;

load "string.moo";

export {
    print_line: (...) {
        __internal(print, ...args, "\n");
    }

    print: (...) {
        __internal(print, ...args);
    }

    read_line: () {
        return __internal(read_line);
    }

    exit: (message) {
        __internal(exit, message);
    }

    assert: (condition, message) {
        if !condition {
            __internal(exit, "Assertion failure: " + message);
        }
    }

    # Quite possibly not the most efficient way to get the length of a thing
    len: (of) {
        if type_of(of) == "string" || type_of(of) == "array" {

            size: 0;
            for part; of { size += 1; }
            return size;

        } else {
            exit("len() can only be called on strings and arrays (got " + type_of(of) + ").");
        }
    }

    load_external_func: (library, func_name) {
        return __internal(load_external_func, library, func_name);
    }

    load_library: (library) {
        __internal(load_library, library);
    }

    evaluate: (code) {
        return __internal(evaluate, code);
    }
}