#--###########################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
# Patrick May <patrick@hexane.org>                           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################
#++
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
    def to_plist(envelope = true)
      return Plist::Emit.dump(self, envelope)
    end
    
    # Helper method for injecting into classes.  Calls <tt>Plist::Emit.save_plist</tt> with +self+.
    def save_plist(filename)
      Plist::Emit.save_plist(self, filename)
    end

    # The following Ruby classes are converted into native plist types:
    #   Array, Bignum, Date, DateTime, Fixnum, Float, Hash, Integer, String, Symbol, Time
    #
    # Write us (via RubyForge) if you think another class can be coerced safely into one of the expected plist classes.
    #
    # +IO+ and +StringIO+ objects are encoded and placed in <data> elements; other objects are <tt>Marshal.dump</tt>'ed unless they implement +to_plist_node+.
    #
    # The +envelope+ parameters dictates whether or not the resultant plist fragment is wrapped in the normal XML/plist header and footer.  Set it to false if you only want the fragment.
    def self.dump(obj, envelope = true)
      output = plist_node(obj)

      output = wrap(output) if envelope

      return output
    end
    
    # Writes the serialized object's plist to the specified filename.
    def self.save_plist(obj, filename)
      File.open(filename, 'wb') do |f|
        f.write(obj.to_plist)
      end
    end

    private
    def self.plist_node(element)
      output = ''
      
      if element.respond_to? :to_plist_node
        output << element.to_plist_node
      else
        case element
        when Array
          output << tag('array') {
            element.collect {|e| plist_node(e)}.join
          }
        when Hash
          inner_tags = []

          element.each do |k,v|
            inner_tags << tag('key', CGI::escapeHTML(k.to_s))
            inner_tags << plist_node(v)
          end

          output << tag('dict') {
            inner_tags.join
          }
        when true, false
          output << "<#{element}/>"
        when Time
          output << tag('date', element.utc.strftime('%Y-%m-%dT%H:%M:%SZ'))
        when Date # also catches DateTime
          output << tag('date', element.strftime('%Y-%m-%dT%H:%M:%SZ'))
        when String, Symbol, Fixnum, Bignum, Integer, Float
          output << tag(element_type(element), CGI::escapeHTML(element.to_s))
        when IO, StringIO
          contents = element.read
          output << tag('data', Base64.encode64(contents))
        else
          output << comment( 'The <data> element below contains a Ruby object which has been serialized with Marshal.dump.' )
          output << tag('data', Base64.encode64(Marshal.dump(element)))
        end
      end

      return output
    end
    
    def self.comment(content)
      return "<!-- #{content} -->"
    end

    def self.tag(type, contents = '', &block)
      contents << block.call if block_given?

      return "<#{type}>#{contents.to_s}</#{type}>"
    end

    def self.wrap(string)
      output = []

      output << '<?xml version="1.0" encoding="UTF-8"?>'
      output << '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
      output << '<plist version="1.0">'

      output << string

      output << '</plist>'

      return output.join
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

class Array #:nodoc:
  include Plist::Emit
end

class Hash #:nodoc:
  include Plist::Emit
end