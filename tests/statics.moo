load "basic.moo";

I: 0;

Struct => {
    static instance: null;
    private i: 0;

    static method: () {
        return "HELLO FROM STATIC METHOD";
    }

    new: () {
        i = I;

        if instance == null {
            instance = self;
        }

        I += 1;
    }

    to_string: () {
        load "conv.moo";
        return i.to_string();
    }
}



s: Struct();

s = Struct();
s = Struct();
s = Struct();
s = Struct();

print_line("current s is ", s);
print_line("Struct instance = ", Struct.instance);
print_line(Struct.method());
