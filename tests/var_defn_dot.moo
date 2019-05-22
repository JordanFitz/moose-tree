rinse: (thing) {
    __internal(print, thing, " has been rinsed.");
}

sort: (thing, order) {
    __internal(print, thing, " is being sorted in ", order, " order.");
}

see: (thing) {
    __internal(print, "i see ", thing);
}

print: (msg) {
    __internal(print, msg);
    return 0;
}

hello: "jordan d fitz";
hey:   "hey";

my_var1: hello.rinse();
my_var2: [1, 2, 3].sort("desc");
my_var3: "hello".see();
my_var4: hey.print() + 2;

print("");

print(my_var1); # null
print(my_var2); # null
print(my_var3); # null 
print(my_var4); # 2