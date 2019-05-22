module moose.tokenizer.main;

import std.string: splitLines;

import property;

import moose.tokenizer.token;
import moose.tokenizer.parsers;

alias Parser = void function(string, uint);

class Tokenizer
{
private:
    static Tokenizer _instance;

    Parser[] m_currentParsers;
    string m_code;
    string[] m_lines;
    string m_fileName;
    Token[] m_stream;

    void _parse(uint location)
    {
        m_currentParsers[$ - 1](m_code, location);
    }

public:
    static mixin Getter!(Tokenizer, "instance", "_");

    mixin Getter!(Token[], "stream");

    this(string code, string fileName)
    {
        m_fileName = fileName;

        LINE_NUMBER = 1;
        COLUMN      = 1;
        LAST_I      = 0;

        _instance = this;
        m_lines = code.splitLines;
        m_code = code ~ '\0';
        m_currentParsers = [&Parsers.main];
        _parse(0);
    }

    void popParser(uint location)
    {
        assert(m_currentParsers.length > 1);
        m_currentParsers = m_currentParsers[0 .. $ - 1];
        _parse(location);
    }

    void addParser(Parser parser, uint location)
    {
        m_currentParsers ~= parser;
        _parse(location);
    }

    void addToken(Token token)
    {
        // TODO: Add file names
        token.setupDebug(m_fileName, m_lines);
        m_stream ~= token;
    }
}