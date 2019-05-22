
#test2: is_valid() || can_has(123 + 2);

test1: true && ((1 + 2) > 4); # false
test2: true && false;         # false
test3: "str" || false;        # true because a string evalutes to true
