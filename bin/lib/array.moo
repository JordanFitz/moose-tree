mod array;

load "basic.moo";
load "conv.moo";

export {
    # Adds 'what' to the given array. 'to' is modified by 
    # this function.
    append: (@to, what) {
        to = __internal(array_append, to, what);
    }

    remove: (@from, index) {
        from = __internal(array_remove, from, index);
    }

    pop: (@from) {
        index: len(from) - 1;
        item: from[index];
        from = __internal(array_remove, from, index);
        return item;
    }

    # Inclusive number array generator
    range: (low, high) {
        result: [];
        i: low;

        while i <= high {
            result = __internal(array_append, result, i);
            i += 1;
        }

        return result;
    }

    # Returns true if the given array contains the given item.
    contains: (haystack, needle) {
        if type_of(haystack) != "array" && type_of(haystack) != "string" {
            __internal(exit, "Error: contains cannot be used on non-iterable types.");
        }

        return haystack.index_of(needle) != -1;
    }

    # Returns an inclusive subsection of the given array
    sub_array: (array, start, end) {
        if type_of(array) != "array" {
            __internal(exit, "Error: sub_array cannot be used on non-array types.");
        }

        if end <= start {
            __internal(exit, "Error: sub_array end index must be greater than start index.");
        }

        if start < 0 || end > __internal(length, array) - 1 {
            __internal(exit, "Error: sub_array start and end indices must be within the bounds of the array.");
        }

        result: [];
        i: start;

        while i <= end {
            result.append(array[i]);
            i += 1;
        }

        return result;
    }

    # Returns the index of the given item within the given array.
    # Returns -1 if the item isn't found.
    index_of: (haystack, needle) {
        if type_of(haystack) != "array" && type_of(haystack) != "string" {
            __internal(exit, "Error: index_of cannot be used on non-iterable types.");
        }

        index: 0;

        for item; haystack {
            if item == needle {
                return index;
            }

            index += 1;
        }

        return -1;
    }

    # Produces a string containing the array joined with the 'with' between
    # each item.
    join: (array, with) {
        result: "";
        array_length: array.len();
        i: 0;

        for item; array {
            result += item.to_string();

            if i < array_length - 1 {
                result += with;
            }

            i += 1;
        }
        return result;
    }
}
