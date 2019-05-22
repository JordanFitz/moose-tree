load "basic.moo";
load "string.moo";
load "array.moo";

DATA_SIZE: 255;

valid_chars: "<>+-.,[]";
ptr: 0;
data: [];

_i: 0;
while _i < 255 {
    data.append("\0");
    _i += 1;
}

jump_pos: (code, pos, dir) {
    jump_target_found: false;
    bracket_counter: 0;

    code_len: code.len();

    while !jump_target_found {
        if pos >= code_len || pos < 0 {
            print_line("Error: [ without ].");
            return -1;
        }

        pos += dir;

        if code[pos] == "]" {
            bracket_counter -= 1;
        } else if code[pos] == "[" {
            bracket_counter += 1; 
        }

        if bracket_counter == dir * -1 { jump_target_found = true; }
    }

    return pos;
}

process_char: (char, pos) {
    if char == ">" {
        ptr += 1;
    } else if char == "<" {
        ptr -= 1;
    } else if char == "+" {
        c: __internal(get_char_code, data[ptr]) + 1;
        data[ptr] = __internal(convert_char_code, c);
    } else if char == "-" {
        c: __internal(get_char_code, data[ptr]) - 1;
        data[ptr] = __internal(convert_char_code, c);
    } else if char == "." {
        print(data[ptr]);
    } else if char == "," {
        data[ptr] == __internal(read_char);
    } else {
        print_line("Illegal character at ", pos+1, ": ", char);
    }
}

process_code: (code) {
    pos: 0;
    code_len: code.len();
    while pos < code_len {
        char: code[pos];

        if valid_chars.contains(char) {

            if char == "[" {

                bracket_pos: jump_pos(code, pos, 1);
                loop_code: code.sub_string(pos + 1, bracket_pos - 1);

                while data[ptr] != "\0" {
                    process_code(loop_code);
                }

                pos = bracket_pos;

            } else {
                process_char(char, pos);
            }
        }

        pos += 1;
    }
}

# hello world
process_code("++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.");

# 99 bottles of beer
# process_code(".>+++++++>++++++++++[<+++++>-]+++++++>++++++++++[<+++++>-]++++++++++>+++++++++>>++++++++[<++++>-]>++++++++++++++[<+++++++>-]+>+++++++++++[<++++++++++>-]++>+++++++++++++++++++[<++++++>-]++>+++++++++++++++++++[<++++++>-]>++++++++++++[<+++++++++>-]+>++++++++++[<++++++++++>-]+>+++++++++++++++++++[<++++++>-]>++++++++[<++++>-]+>+++++++++++[<++++++++++>-]++>++++++++++[<++++++++++>-]>++++++++[<++++>-]>++++++++++++++[<+++++++>-]+>++++++++++[<++++++++++>-]+>++++++++++[<++++++++++>-]>+++++++++++++++++++[<++++++>-]>++++++++[<++++>-]+>+++++++++++[<++++++++++>-]>+++++++++++[<++++++++++>-]>++++++++[<++++>-]++>+++++++++++++++++++[<++++++>-]++++>++++++++++[<++++++++++>-]+>++++++++++[<++++++++++>-]>++++++++[<++++>-]++>+++++++++++++[<+++++++++>-]+>++++++++++++[<++++++++>-]>++++++++++++[<+++++++++>-]>++++++++++++[<+++++++++>-]>+++++[<++>-]++>+++++++++++++++++++[<++++++>-]+>++++++++++++[<++++++++>-]+++>+++++++++++++[<++++++++>-]+>++++++++++[<++++++++++>-]>++++++++[<++++>-]+>+++++++++++[<++++++++++>-]>+++++++++++[<++++++++++>-]+>++++++++++[<++++++++++>-]>++++++++[<++++>-]>++++++++++[<++++++++++>-]+>+++++++++++[<++++++++++>-]++>+++++++++++++[<+++++++++>-]>+++++++++++[<++++++++++>-]>++++++++[<++++>-]+>++++++++++++[<++++++++>-]>+++++++++++[<++++++++++>-]>++++++++++[<++++++++++>-]>++++++++[<++++>-]++>+++++++++++[<++++++++++>-]+>++++++++++++[<++++++++>-]+>+++++++++++++++++++[<++++++>-]+>+++++++++++++++++++[<++++++>-]>++++++++[<++++>-]+>+++++++++++++[<++++++++>-]++>+++++++++++++++++++[<++++++>-]>++++++++[<++++>-]+>++++++++++++[<++++++++>-]>+++++++++++++++++++[<++++++>-]+>+++++++++++[<++++++++++>-]>+++++++++++++[<+++++++++>-]>+++++++++++[<++++++++++>-]>++++++++++[<++++++++++>-]>+++++[<++>-]+++++++++++++[<]>>>>[<[[>]<<..[<]>.>.>>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.[<]>.>.>>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>>>>>>>>>>>>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.[<]>>-<.>.>>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.[<]>>>-]++++++++++<++++++++++<-[>]<.[<]>.>.>>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.[<]>>>>-]+<--[[>]<<..[<]>>.>>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.[<]>>.>>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>>>>>>>>>>>>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.[<]>>-.>>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.[<]>>>-]+[>]<.[<]>>.>>>.>.>.>.>.>.>.>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.<<<<.[>]<<..[<]>>.>>>.>.>.>.>.>.>.>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.[<]>>.>>>.>.>.>.>.>.>.>>.>.>.>.>.>.>.>.>>>>>>>>>>>>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.[>]<<<<.<<.<<<.[<]>>>>>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.>.");

# squares
# process_code("++++[>+++++<-]>[<+++++>-]+<+[>[>+>+<<-]++>>[<<+>>-]>>>[-]++>[-]+>>>+[[-]++++++>>>]<<<[[<++++++++<++>>-]+<.<[>----<-]<]<<[>>>>>[>>>[-]+++++++++<[>-<-]+++++++++>[-[<->-]+[<<<]]<[>+<-]>]<<-]<<-]");