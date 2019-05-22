load "basic.moo";

fizzbuzz: (num) {
    buzzer: "";

    if num % 3 == 0 {
        buzzer = buzzer + "Fizz";
    }

    if num % 5 == 0 {
        buzzer = buzzer + "Buzz";
    }

    if buzzer == "" {
        return num;
    } else {
        return buzzer;
    }
}

count: 1;

while count < 100 {
    print(fizzbuzz(count));
    count = count + 1;
}