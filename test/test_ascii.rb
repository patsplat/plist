# encoding: utf-8

require "test/unit"
require "date"
require "plist/ascii"

class TestAscii < Test::Unit::TestCase
  def test_should_parse_a_simple_dictionary
    assert_equal({'a' => 'b'}, parse("{ a = b; }"))
  end

  def test_should_parse_a_simple_array
    assert_equal(%w[1 2 3], parse("(1, 2, 3)"))
    assert_equal(%w[foo], parse("(foo, )"))
  end

  def test_should_assume_dictionary_keys_are_strings_when_they_start_with_a_number
    assert_equal({ '1' => 'foo' }, parse("{ 1 = foo; }"))
  end

  def test_should_correctly_parse_escaped_unicode_points
    assert_equal({'foo' => "æ"}, parse('{ foo = "\u00e6"; }'))
  end

  def test_should_always_return_string_keys
    assert_equal({'1234' => 'boo'}, parse_with_numbers('{ 1234 = boo; }'))
  end

  def test_should_correctly_parse_control_chars
    assert_equal({'foo' => "\a\v\r\t\n\b\f"}, parse('{ foo = "\a\v\r\t\n\b\f"; }'))
  end

  def test_should_correctly_parse_octal_escapes
    expected = "\303\246"
    expected.force_encoding("BINARY") if expected.respond_to?(:force_encoding)
    assert_equal({'foo' => expected}, parse('{ foo = "\303\246"; }'))
  end

  def test_should_correctly_parse_escaped_strings
    assert_equal({'foo' => '"hello world"'}, parse('{ foo = "\"hello world\""; }'))
  end

  def test_should_correctly_parse_NSDate_strings
    assert_equal({'time' => DateTime.parse("2008-11-22 14:17:04 +0100")}, parse('{ time = 2008-11-22 14:17:04 +0100;}'))
  end

  def test_should_parse_floats
    assert_equal({ 'hello' => 1.2 }, parse_with_numbers("{ hello = 1.2; }"))
  end

  def test_should_parse_ints
    assert_equal([1,2,3], parse_with_numbers("(1, 2, 3)"))
    assert_equal({ 'hello' => "12abc" }, parse_with_numbers('{ hello = 12abc; }'))
  end

  def test_should_parse_booleans
    assert_equal({'foo' => true}, parse_with_bools("{foo = true;}"))
    assert_equal({'foo' => "1"}, parse("{foo = true;}"))
  end

  def test_should_parse_data
    assert_equal({'data' => "foo\n"}, parse("{data = <666f6f0a>;}"))
    assert_equal(asset("example_data.jpg"), parse(asset("example_data_ascii.plist"))['image'])
  end

  #
  #  errors
  #

  def test_should_raise_error_if_given_a_non_string_key
    assert_raises Plist::AsciiParser::ParseError do
      parse_with_numbers "{ 1.2 = foo; }"
    end
  end

  def test_should_raise_error_on_missing_semicolons
    assert_raises Plist::AsciiParser::ParseError do
      parse "{ foo = bar }"
    end
  end

  def test_should_raise_error_on_missing_closing_parenthesis
    assert_raises Plist::AsciiParser::ParseError do
      parse "( foo, bar "
    end
  end

  def test_should_raise_error_on_missing_end_quote
    assert_raises Plist::AsciiParser::ParseError do
      parse '{ foo = "bar; }'
    end
  end

  def test_wshould_raise_error_on_empty_string
    assert_raises Plist::AsciiParser::ParseError do
      parse ''
    end
  end

  #
  #  other
  #

  def test_should_parse_textmate_ruby_grammar_without_errors
    assert_nothing_raised do
      parse asset("ruby.plist")
    end
  end

  def test_should_handle_a_stringio_as_input
    io = StringIO.new("(a,b,c)")
    assert_equal(%w[a b c], parse(io))
  end

  def test_should_handle_an_io_as_input
    File.open(path = "test.txt", "w") { |file| file << "{baz=(1,2,3);}" }
    io = File.open(path, "r")
    assert_equal({'baz' => [1,2,3] }, parse_with_numbers(io))
  ensure
    io.close
    File.delete(io.path)
  end

  #
  #  helpers
  #

  def parse(str)
    Plist.parse_ascii(str)
  end

  def parse_with_numbers(str)
    Plist.parse_ascii(str, :parse_numbers => true)
  end

  def parse_with_bools(str)
    Plist.parse_ascii(str, :parse_booleans => true)
  end

  def asset(filename)
    File.read("#{File.dirname(__FILE__)}/assets/#{filename}")
  end
end
