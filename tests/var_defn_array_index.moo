test1: "hey"[0];
test2: [1, 2, 3, 4][1];
test3: [1, 2, 3, 4];
test4: test3[0];

__internal(print, test1); # 'h'
__internal(print, test2); #  2
__internal(print, test3); # [1, 2, 3, 4]
__internal(print, test4); #  1
