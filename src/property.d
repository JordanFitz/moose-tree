module property;

/**
 * This file creates mixins for properties to reduce the number of times
 * I type "@property"
 */

public mixin template Property(Type, string name, string prefix = "m_")
{
    mixin(
        "@property " ~ Type.stringof ~ " " ~ name ~ "() { return " ~ prefix ~ name ~ "; }"
    );

    mixin(
        "@property void " ~ name ~ "(" ~ Type.stringof ~ " value) { " ~ prefix ~ name ~ " = value; }"
    );
}

public mixin template Getter(Type, string name, string prefix = "m_")
{
    mixin(
        "@property " ~ Type.stringof ~ " " ~ name ~ "() { return " ~ prefix ~ name ~ "; }"
    );
}

public mixin template Setter(Type, string name, string prefix = "m_")
{
    mixin(
        "@property void " ~ name ~ "(" ~ Type.stringof ~ " value) { " ~ prefix ~ name ~ " = value; }"
    );
}
