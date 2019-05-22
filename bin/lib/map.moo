mod map;

load "basic.moo";

export {

    Map => {

        private {
            _keys:   [];
            _values: [];
        }

        new: (...) {
            args_length: args.len();

            if args_length % 2 != 0 {
                __internal(exit, "Error: Map constructor expects pairs but received an odd number of arguments.\n");
                return;
            }

            i: 0;
            while i < args_length {
                key: args[i];
                val: args[i+1];

                set(key, val);

                i += 2;
            }
        }

        # The index parameter will be set to the index where
        # the key was found.
        has_key: (search_key, @index) {
            old_index: index;
            index = 0;

            for key; _keys {
                if search_key == key {
                    return true;
                }

                index += 1;
            }

            # Resetting 'index' to its original value.
            index = old_index;

            return false;
        }

        # Same as the other has_key but ignores the index.
        has_key: (search_key) {
            index: -1;
            return has_key(search_key, index);
        }

        set: (key, value) {
            i: 0;

            if !has_key(key, i) {
                _keys   = __internal(array_append, _keys,   key  );
                _values = __internal(array_append, _values, value);
            } else {
                _keys[i]   = key;
                _values[i] = value;
            }
        }

        get: (search_key) {
            i: 0;

            if has_key(search_key, i) {
                return _values[i];
            }

            return null;
        }
    }
}
