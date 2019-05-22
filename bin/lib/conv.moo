mod conv;

export {
    to_string: (input) {
        return __internal(convert_to_string, input);
    }

    to_number: (input) {
        if input == true  { return 1; }
        if input == false { return 0; }

        return __internal(convert_to_number, input);
    }
}