#--
##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
# Patrick May <patrick@hexane.org>                           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################
#++

# === Save a plist
# You can turn the variables back into a plist string:
#
#   r.to_plist
#
# There is a convenience method for saving a variable to a file:
#
#   r.save_plist(filename)
#
# Only these ruby types can be converted into a plist:
#
#   String
#   Float
#   DateTime
#   Integer
#   FalseClass
#   TrueClass
#   Array
#   Hash
#
# Notes:
#
# + Array and Hash are recursive -- the elements of an Array and the values of a Hash
# must convert to a plist.
# + The keys of the Hash must be strings.
# + The contents of data elements are returned as a Tempfile.
# + Data elements can be set with to an open IO or a StringIO
#
# If you have suggestions for mapping other Ruby types to the plist types, send a note to:
#
#   mailto:plist@hexane.org
#
# I'll take a look and probably add it, I'm just reticent to create too many
# "convenience" methods without at least agreeing with someone :-)
module Plist
  module Emit
    def save_plist(filename)
      File.open(filename, 'wb') do |f|
        f.write(self.to_plist)
      end
    end

    # Helper method for injecting into classes
    def to_plist(envelope = true)
      return Plist::Emit.dump(self, envelope)
    end
    
    # Only the expected classes can be emitted as a plist:
    #   String, Float, DateTime, Integer, TrueClass, FalseClass, Array, Hash
    #
    # Write us (via RubyForge) if you think another class can be coerced safely 
    # into one of the expected plist classes.
    def self.dump(obj, envelope = true)
      # This is really gross, but it allows Plist::Emit.dump(obj) to work.
      #
      # FIXME: I should find a better way.
      self.extend(self)

      output = plist_node(obj)
      
      output = wrap(output) if envelope
      
      return output
    end

    private
    def plist_node(element)
      output = ''
      case element
      when Array
        output << tag('array') {
          element.collect {|e| plist_node(e)}.join
        }
      when Hash
        inner_tags = []

        element.each do |k,v|
          inner_tags << tag('key', k.to_s)
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
        output << tag(element_type(element), element.to_s)
      else
        output << tag('data', Marshal.dump(element))
      end

      return output
    end

    def tag(type, contents = '', &block)
      contents << block.call if block_given?

      return "<#{type}>#{contents.to_s}</#{type}>"
    end
    
    def wrap(string)
      output = []
      
      output << '<?xml version="1.0" encoding="UTF-8"?>'
      output << '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
      output << '<plist version="1.0">'
      
      output << string
      
      output << '</plist>'
      
      return output.join
    end

    def element_type(item)
      return case item
        when Array:                   'array'
        when String, Symbol:          'string'
        when Fixnum, Bignum, Integer: 'integer'
        when Float:                   'real'
        when Array:                   'array'
        when Hash:                    'dict'
        else
          raise "Don't know about this data type... something must be wrong!"
      end
    end
  end
end

class Array
  include Plist::Emit
end

class Hash
  include Plist::Emit
end