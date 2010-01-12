require 'strscan'
require "time"
require "stringio"

module Plist

  #
  # string - the plist string to parse
  # opts   - options (see +AsciiParser.new+)
  #

  def self.parse_ascii(string, opts = {})
    AsciiParser.new(string, opts).parse
  end

  #
  # Plist::AsciiParser
  #
  # Parser for the old style ASCII/NextSTEP property lists.
  #
  # Created by Jari Bakken on 2008-08-13.
  #
  class AsciiParser < StringScanner

    class ParseError < StandardError; end

    SPACE_REGEXP =  %r{   ( /\*.*?\*/   |  # block comments
                            //.*?$\n?   |  # single-line comments
                            \s*         )+ # space
    }mx

    CONTROL_CHAR = {
      "a" => "\a",
      "b" => "\b",
      "n" => "\n",
      "f" => "\f",
      "t" => "\t",
      "r" => "\r",
      "v" => "\v",
    }

    BOOLS = {true => "1", false => "0"}

    #
    # string - the plist string to parse
    #
    # options hash:
    #
    #   :parse_numbers => true/false   :  Set this to true if you numeric values (float/ints) as the correct Ruby type
    #   :parse_booleans => true/false  :  Set this to true if you want "true" and "false" to return the boolean Ruby types
    #
    #  Note:  Apple's parsers return strings for all old-style plist types.
    #

    def initialize(string, opts = {})
      string = case string
               when StringIO
                 string.string
               when IO
                 string.read
               else
                 string
               end

      @parse_numbers = opts.delete(:parse_numbers)
      @parse_bools   = opts.delete(:parse_booleans)
      @debug         = $VERBOSE == true # ruby -W3

      raise ArgumentError, "unknown option #{opts.inspect}" unless opts.empty?

      super(string)
    end

    def parse
      res = object

      skip_space
      error "junk after plist" unless eos?

      res
    end

    private

    def object
      skip_space

      if    scan(/\{/) then dictionary
      elsif scan(/\(/) then array
      elsif scan(/</)  then data
      elsif scan(/"/)  then quoted_string
      else                  unquoted_string
      end
    end

    def quoted_string
      puts "creating quoted string #{inspect}" if @debug

      result = ''

      loop do
        if scan(/\\/)
          result << escaped
        elsif scan(/"/)
          break
        elsif eos?
          error("unterminated quoted string")
        else scan(/./)
          error("unterminated quoted string") unless matched
          result << matched
        end
      end

      result
    end

    def escaped
      if scan(/"|\\|\\\//)
        matched
      elsif scan(/a|b|f|n|v|r|t/)
        CONTROL_CHAR[matched]
      elsif scan(/u[0-9a-f]{4}/i)
        [ matched[1..-1].to_i(16) ].pack("U")
      elsif scan(/\d{1,3}/)
        [ matched.to_i(8) ].pack("C")
      end
    end

    def unquoted_string
      puts "creating unquoted string #{inspect}" if @debug

      if scan(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} ((\+|-)\d{4})?/)
        puts "returning time" if @debug
        require 'date'
        DateTime.parse(matched)
      elsif scan(/-?\d+?\.\d+\b/)
        puts "returning float" if @debug
        @parse_numbers ? matched.to_f : matched
      elsif scan(/-?\d+\b/)
        puts "returning int" if @debug
        @parse_numbers ? matched.to_i : matched
      elsif scan(/\b(true|false)\b/)
        val = matched == 'true'
        if @parse_bools
          val
        else
          @parse_numbers ? BOOLS[val].to_i : BOOLS[val]
        end
      elsif eos?
        error("unexpected end-of-string")
      else
        puts "returning string" if @debug
        scan(/\w+/)
      end
    end

    def data
      puts "creating data #{inspect}" if @debug

      scan(/(.+?)>/)

      hex = self[1].delete(" ")
      [hex].pack("H*")
    end

    def array
      puts "creating array #{inspect}" if @debug

      skip_space

      arr = []
      until scan(/\)/)
        val = object()

        return nil unless val
        skip_space

        unless skip(/,\s*/)
          skip_space
          if scan(/\)/)
            return arr << val
          else
            error "missing ',' or ')' for array"
          end
        end

        arr << val
        error "unexpected end-of-string when parsing array" if eos?
      end

      arr
    end

    def dictionary
      puts "creating dict #{inspect}" if @debug

      skip_space

      dict = {}
      until scan(/\}/)
        key = object()
        p :key => key if @debug

        error "expected terminating '}' for dictionary" unless key

        # dictionary keys must be strings, even if represented as 12345 in the plist
        if key.is_a?(Integer) && key >= 0
          key = key.to_s
        end
        error "dictionary key must be string (\"quoted\" or alphanumeric)" unless key.is_a? String

        skip_space
        error "missing '=' in dictionary" unless scan(/=/)
        skip_space

        val = object()
        p :val => val if @debug

        skip_space
        error "missing ';' in dictionary" unless skip(/;/)
        skip_space

        dict[key] = val
        error "unexpected end-of-string when parsing dictionary" if eos?
      end

      dict
    end

    def error(msg)
      line = 1
      string.split(//).each_with_index do |e, i|
        line += 1 if e == "\n"
        break if i == pos
      end

      context = (pos - 10) < 0 ? 0 : pos - 10
      err = "#{msg} at line #{line}\n"
      err << "#{string[context..pos+10]}".inspect << "\n"

      err << "\n#{inspect}" if @debug
      raise ParseError, err
    end

    def skip_space
      puts "skipping whitespace" if @debug
      skip SPACE_REGEXP
    end

  end
end