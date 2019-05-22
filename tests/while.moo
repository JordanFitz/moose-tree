print: (msg) { __internal(print, msg); }

i: 0;
while i < 10 {
    print(i);
    i = i + 1;
}