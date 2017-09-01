# encoding: utf-8

# = plist
#
# Copyright 2006-2010 Ben Bleything and Patrick May
# Distributed under the MIT License
#

module Plist

  class Generator #:nodoc:
    def initialize opts
      @indent_unit = opts[:indent]
      @indent_level = 0
      @initial_indent = opts[:initial_indent]
      @indent = @initial_indent + @indent_unit * @indent_level
      @base64_bytes_per_line = (opts[:base64_width] * 6) / 8
      @xml_version = opts[:xml_version]
      @base64_indent = opts[:base64_indent]
      @output = []
    end
    attr_reader :output

    def envelope
      @output << %|<?xml version="#{@xml_version}" encoding="UTF-8"?>\n|
      @output << %|<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n|
      @output << %|<plist version="1.0">\n|

      yield

      @output << %|</plist>\n|
    end

    def generate element
      if element.respond_to? :to_plist_node
        @output << element.to_plist_node
        return
      end

      case element
      when Array
        if element.empty?
          empty_tag 'array'
        else
          tag 'array' do
            element.each {|e| generate e }
          end
        end
      when Hash
        if element.empty?
          empty_tag 'dict'
        else
          tag 'dict' do
            element.keys.sort_by(&:to_s).each do |k|
              v = element[k]
              tag 'key', escape_string(k.to_s)
              generate v
            end
          end
        end
      when true, false
        empty_tag element
      when Time
        tag 'date', element.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      when Date # also catches DateTime
        tag 'date', element.strftime('%Y-%m-%dT%H:%M:%SZ')
      when String
        tag 'string', escape_string(element)
      when Symbol
        tag 'string', escape_string(element.to_s)
      when Float
        if element.to_i == element
          tag 'real', element.to_i
        else
          tag 'real', element
        end
      when Integer
        tag 'integer', element
      when IO, StringIO
        element.rewind
        contents = element.read
        data_tag contents
      else
        contents = Marshal.dump element
        comment_tag 'The <data> element below contains a Ruby object which has been serialized with Marshal.dump.'
        data_tag contents
      end
    end

    private

    def empty_tag name
      @output << "#@indent<#{name}/>\n"
    end

    def data_tag contents
      # m51 means: 51 bytes for each base64 encode run length, which is (51 * 8 / 6 = 68) chars per line after base64
      base64 = [contents].pack "m#@base64_bytes_per_line"
      if @base64_indent
        base64.gsub! /^/, @indent
      end
      @output << "#@indent<data>\n#{base64}#@indent</data>\n"
    end

    def comment_tag content
      @output << "#@indent<!-- #{content} -->\n"
    end

    def tag name, contents=nil
      if block_given?
        @output << "#@indent<#{name}>\n"
        @indent = @initial_indent + @indent_unit * (@indent_level += 1)
        yield
        @indent = @initial_indent + @indent_unit * (@indent_level -= 1)
        @output << "#@indent</#{name}>\n"
      else
        @output << "#@indent<#{name}>#{contents}</#{name}>\n"
      end
    end

    TABLE_FOR_ESCAPE = {"&" => "&amp;", "<" => "&lt;", ">" => "&gt;"}.freeze
    def escape_string s
      # Likes CGI.escapeHTML but leaves `'` or `"` as mac plist does
      s.gsub /[&<>]/ do |c|
        TABLE_FOR_ESCAPE[c]
      end
    end
  end

  # === Create a plist
  # You can dump an object to a plist in one of two ways:
  #
  # * <tt>Plist::Emit.dump(obj)</tt>
  # * <tt>obj.to_plist</tt>
  #   * This requires that you mixin the <tt>Plist::Emit</tt> module, which is already done for +Array+ and +Hash+.
  #
  # The following Ruby classes are converted into native plist types:
  #   Array, Bignum, Date, DateTime, Fixnum, Float, Hash, Integer, String, Symbol, Time, true, false
  # * +Array+ and +Hash+ are both recursive; their elements will be converted into plist nodes inside the <array> and <dict> containers (respectively).
  # * +IO+ (and its descendants) and +StringIO+ objects are read from and their contents placed in a <data> element.
  # * User classes may implement +to_plist_node+ to dictate how they should be serialized; otherwise the object will be passed to <tt>Marshal.dump</tt> and the result placed in a <data> element.
  #
  # For detailed usage instructions, refer to USAGE[link:files/docs/USAGE.html] and the methods documented below.
  module Emit
    DEFAULT_INDENT = "\t"

    # Helper method for injecting into classes.  Calls <tt>Plist::Emit.dump</tt> with +self+.
    def to_plist(envelope = true, options = {})
      Plist::Emit.dump(self, envelope, options)
    end

    # Helper method for injecting into classes.  Calls <tt>Plist::Emit.save_plist</tt> with +self+.
    def save_plist(filename, options = {})
      Plist::Emit.save_plist(self, filename, options)
    end

    # The following Ruby classes are converted into native plist types:
    #   Array, Bignum, Date, DateTime, Fixnum, Float, Hash, Integer, String, Symbol, Time
    #
    # Write us (via RubyForge) if you think another class can be coerced safely into one of the expected plist classes.
    #
    # +IO+ and +StringIO+ objects are encoded and placed in <data> elements; other objects are <tt>Marshal.dump</tt>'ed unless they implement +to_plist_node+.
    #
    # The +envelope+ parameters dictates whether or not the resultant plist fragment is wrapped in the normal XML/plist header and footer.  Set it to false if you only want the fragment.
    #
    # Options can be:
    #
    # [:xml_version] you can also specify <code>"1.1"</code> for https://www.w3.org/TR/xml11/, default is <code>"1.0"</code>, no effect if <code>:envelope</code> is set to <code>false</code>
    #
    # [:base64_width] the width of characters per line when serializing data with Base64, default value is <code>68</code>, must be multiple of <code>4</code>
    #
    # [:base64_indent] whether indent the Base64 encoded data, you can use <code>false</code> for compatibility to generate same output for other frameworks, default value is <code>true</code>
    #
    # [:indent] the indent unit, default value is <code>"\t"</code>, set to <code>nil</code> or <code>''</code> if you don't need indent
    #
    # [:initial_indent] initial indent space, default is <code>''</code>, the indentation per line equals to <code>initial_indent + indent * current_indent_level</code>
    #
    def self.dump(obj, envelope=true, options={})
      options = {
        :xml_version => '1.0',
        :base64_width => 68,
        :base64_indent => true,
        :indent => DEFAULT_INDENT,
        :initial_indent => ''
      }.merge options
      options[:indent] ||= ''
      if !options[:base64_width].is_a?(Integer) or options[:base64_width] <= 0 or options[:base64_width] % 4 != 0
        raise ArgumentError, "option :base64_width must be a positive integer and a multiple of 4"
      end
      generator = Generator.new options
      if envelope
        generator.envelope do
          generator.generate obj
        end
      else
        generator.generate obj
      end

      generator.output.join
    end

    # Writes the serialized object's plist to the specified filename.
    def self.save_plist(obj, filename, options = {})
      File.open(filename, 'wb') do |f|
        f.write(obj.to_plist(true, options))
      end
    end
  end
end

class Array #:nodoc:
  include Plist::Emit
end

class Hash #:nodoc:
  include Plist::Emit
end
