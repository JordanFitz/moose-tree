printf: (fmt, arg1) {
    # lol
    __internal(print, fmt);
}

print: (m) {
    __internal(print, m);
}

hello: (a, b, c) {
    print(a);
    print(b);
    print(c);
}


printf("hello, %", "world");
hello(1 + 2 / (34.5/4), "hey", true);
