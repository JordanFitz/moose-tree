mod structs;

load "basic.moo";
load "conv.moo";

Dog => {
    name:  "";
    color: "";

    new: (name, color) {
        self.name  = name;
        self.color = color;
    }

    output: () {
        print_line("My name is ", name, " and I am ", color);
    }

    equals: (what) {
        return what.name == name && what.color == color;
    }

    to_string: () {
        return "{ name='" + name + "', color='" + color + "' }";
    }
}

Person => {
    name: "";
    age: 0;
    dog: null;

    new: (name, age) {
        self.name = name;
        self.age  = age;

        dog = Dog(name + "'s dog", "brown");
    }

    output: () {
        print_line("My name is ", name, ", I am ", age, " years old, and here's my dog:");
        dog.output();
    }

    to_string: () {
        return "{ name='" + name + "', age=" + age.to_string() + ", Dog=" + dog.to_string() + " }";
    }
}

jordan: Person("Jordan", 19);
jordan.output();
