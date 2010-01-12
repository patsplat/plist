#--###########################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
# Patrick May <patrick@hexane.org>                           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################
#++

require "plist/binary"

# See Plist::Emit.
module Plist
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
    # Helper method for injecting into classes.  Calls <tt>Plist::Emit.dump</tt> with +self+.
    def to_plist(envelope = true, format = :xml)
      return Plist::Emit.dump(self, envelope, format)
    end

    # Helper method for injecting into classes.  Calls <tt>Plist::Emit.save_plist</tt> with +self+.
    def save_plist(filename, format = :xml)
      Plist::Emit.save_plist(self, filename, format)
    end

    # The following Ruby classes are converted into native plist types:
    #   Array, Bignum, Date, DateTime, Fixnum, Float, Hash, Integer, String, Symbol, Time
    #
    # Write us (via RubyForge) if you think another class can be coerced safely into one of the expected plist classes.
    #
    # +IO+ and +StringIO+ objects are encoded and placed in <data> elements; other objects are <tt>Marshal.dump</tt>'ed unless they implement +to_plist_node+.
    #
    # The +envelope+ parameters dictates whether or not the resultant plist fragment is wrapped in the normal XML/plist header and footer.  Set it to false if you only want the fragment.
    def self.dump(obj, envelope = true, format = :xml)
      case format
      when :xml
        output = plist_node(obj)  
        output = wrap(output) if envelope
      when :binary
        raise(ArgumentError, "binary plists must have an envelope") unless envelope
        output = Plist::Binary.binary_plist(obj)
      else
        raise(ArgumentError, "unknown plist format `#{format}'")
      end
      return output
    end

    # Writes the serialized object's plist to the specified filename.
    def self.save_plist(obj, filename, format = :xml)
      File.open(filename, 'wb') do |f|
        case format
        when :xml
          f.write(obj.to_plist(true, format))
        when :binary
          f.write(Plist::Binary.binary_plist(obj))
        else
          raise(ArgumentError, "unknown plist format `#{format}'")
        end
      end
    end

    private

    HTML_ESCAPE_HASH = {
      "&" => "&amp;",
      "\"" => "&quot;",
      ">" => "&gt;",
      "<" => "&lt;"
    }
    
    def self.escape_html(string)
      string.gsub(/(&|\"|>|<)/) do |mtch|
        HTML_ESCAPE_HASH[mtch]
      end
    end
    
    def self.plist_node(element)
      output = StringIO.new

      if element.respond_to? :to_plist_node
        output << element.to_plist_node
      else
        case element
        when Array
          if element.empty?
            output << "<array/>\n"
          else
            output << tag('array') {
              element.collect { |e| plist_node(e) }
            }
          end
        when Hash
          if element.empty?
            output << "<dict/>\n"
          else
            output << tag("dict") {
              s = []
              element.each { |k, v|
                s << tag('key', Emit.escape_html(k.to_s))
                s << plist_node(v)
              }
              s
            }
          end
        when true, false
          output << "<#{element}/>\n"
        when Time
          output << tag('date', element.utc.strftime('%Y-%m-%dT%H:%M:%SZ'))
        when Date # also catches DateTime
          output << tag('date', element.strftime('%Y-%m-%dT%H:%M:%SZ'))
        when String, Symbol, Fixnum, Bignum, Integer, Float
          output << tag(element_type(element), Emit.escape_html(element.to_s))
        when IO, StringIO
          element.rewind
          contents = element.read
          # note that apple plists are wrapped at a different length then
          # what ruby's base64 wraps by default.
          # I used #encode64 instead of #b64encode (which allows a length arg)
          # because b64encode is b0rked and ignores the length arg.
          data = "\n"
          Base64::encode64(contents).gsub(/\s+/, '').scan(/.{1,68}/o) { data << $& << "\n" }
          output << tag('data', data)
        else
          output << comment( 'The <data> element below contains a Ruby object which has been serialized with Marshal.dump.' )
          data = "\n"
          Base64::encode64(Marshal.dump(element)).gsub(/\s+/, '').scan(/.{1,68}/o) { data << $& << "\n" }
          output << tag('data', data )
        end
      end
      return output.string
    end

    def self.comment(content)
      return "<!-- #{content} -->\n"
    end

    def self.indent_level
      @indent_level ||= 0
    end

    def self.raise_indent_level
      @indent_level = indent_level + 1
    end

    def self.lower_indent_level
      if (ind = indent_level) > 0
        @indent_level = ind - 1
      end
    end

    def self.append_indented_to_io(io_object, obj)
      if obj.is_a?(Array)
        obj.each do |o|
          append_indented_to_io(io_object, o)
        end
      else
        unless obj.index("\t") == 0
          indent = "\t" * indent_level
          io_object << "#{indent}#{obj}"
        else
          io_object << obj
        end
        last = obj.length - 1
        io_object << "\n" unless obj[last .. last] == "\n"
      end
    end

    def self.tag(type, contents = '', &block)
      out = nil
      if block_given?

        sio = StringIO.new
        append_indented_to_io(sio, "<#{type}>")
        raise_indent_level

        append_indented_to_io(sio, block.call)
        
        lower_indent_level
        append_indented_to_io(sio, "</#{type}>")
        out = sio.string

      else
        out = "<#{type}>#{contents.to_s}</#{type}>\n"
      end
      return out.to_s
    end

    def self.wrap(contents)
      output = StringIO.new

      output << '<?xml version="1.0" encoding="UTF-8"?>' + "\n"
      output << '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' + "\n"
      output << '<plist version="1.0">' + "\n"

      output << contents

      output << '</plist>' + "\n"
      
      output.string
    end

    def self.element_type(item)
      return case item
        when String, Symbol:          'string'
        when Fixnum, Bignum, Integer: 'integer'
        when Float:                   'real'
        else
          raise "Don't know about this data type... something must be wrong!"
      end
    end

  end
end

# we need to add this so sorting hash keys works properly
class Symbol #:nodoc:
  def <=> (other)
    self.to_s <=> other.to_s
  end
end

class Array #:nodoc:
  include Plist::Emit
end

class Hash #:nodoc:
  include Plist::Emit
end
