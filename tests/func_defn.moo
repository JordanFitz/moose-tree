print: (msg) {
    __internal(print, msg);
}

hello: (arg1, arg2, arg3) {
    my_var: 1;
    
    inner_func: () {
        print("inner");
    }

    my_var2: 1 + 2;

    inner_func();
}

hello(1, 2, 3);
