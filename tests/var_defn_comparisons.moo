# hey: 1 >= 3 + (1 / 2 + 3.14);
# hey2: 1 + 2 < 3;

one_greater_than_3: 1 > 3;
one_less_than_3   : 1 < 3;

# TODO: Fix
# test: "rinse" > "lol"; 
# Silently fails and creates a var `test` with the string value "rinse"

# Crashes as a result of comparing incompatible variant types 
# test: 3 > "test";

hello1: 1 > 3 ; # false
hello2: 1 == 3; # false
hello3: 1 == 1; # true
