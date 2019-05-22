
load "basic.moo";
load "string.moo";

s: 1;
e: 3;

str: "hello";

print(str.sub_string(s, e));

# r: start < 0 || end > len(string) - 1;
# r: start < 0 || end > t - 1;
