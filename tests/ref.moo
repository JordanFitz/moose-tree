load "basic.moo";

test: (hell, @test) {
    hell = 123;
    test = null;
}

change_me: 0;
lol: "hello";

print(change_me);
print(lol);
test(change_me, lol);
print("");
print(change_me);
print(lol);
