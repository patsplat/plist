#--
##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
# Patrick May <patrick@hexane.org>                           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################
#++
#
# Plist parses Mac OS X xml property list files into ruby data structures.
#
# === Load a plist file
# This is the main point of the library:
#
#   r = Plist::parse_xml( filename_or_xml )
class Plist
  VERSION = '0.0.1'

  TEMPLATE = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
%plist%
</plist>
XML
  def Plist::_xml( xml )
    TEMPLATE.sub( /%plist%/, xml )
  end

  # Note that I don't use these two elements much:
  #
  #  + Date elements are returned as DateTime objects.
  #  + Data elements are implemented as Tempfiles
  #
  # Plist::parse_xml will blow up if it encounters a data element.
  # If you encounter such an error, or if you have a Date element which
  # can't be parsed into a Time object, please send your plist file to
  # plist@hexane.org so that I can implement the proper support.
  def Plist::parse_xml( filename_or_xml )
    listener = Listener.new
    #parser = REXML::Parsers::StreamParser.new(File.new(filename), listener)
    parser = StreamParser.new(filename_or_xml, listener)
    parser.parse
    listener.result
  end

  class Listener
    #include REXML::StreamListener

    attr_accessor :result, :open

    def initialize
      @result = nil
      @open   = Array.new
    end


    def tag_start(name, attributes)
      @open.push PTag::mappings[name].new
    end

    def text( contents )
      @open.last.text = contents if @open.last
    end

    def tag_end(name)
      last = @open.pop
      if @open.empty?
        @result = last.to_ruby
      else
        @open.last.children.push last
      end
    end
  end

  class StreamParser
    def initialize( filename_or_xml, listener )
      @filename_or_xml = filename_or_xml
      @listener = listener
    end

    TEXT       = /([^<]+)/
    XMLDECL_PATTERN = /<\?xml\s+(.*?)\?>*/um
    DOCTYPE_PATTERN = /\s*<!DOCTYPE\s+(.*?)(\[|>)/um


      def parse
        plist_tags = PTag::mappings.keys.join('|')
        start_tag  = /<(#{plist_tags})([^>]*)>/i
        end_tag    = /<\/(#{plist_tags})[^>]*>/i

        require 'strscan'
        @scanner = StringScanner.new( if (File.exists? @filename_or_xml)
        File.open(@filename_or_xml, "r") {|f| f.read}
      else
        @filename_or_xml
      end )
      until @scanner.eos?
        if @scanner.scan(XMLDECL_PATTERN)
        elsif @scanner.scan(DOCTYPE_PATTERN)
        elsif @scanner.scan(start_tag)
          @listener.tag_start(@scanner[1], nil)
          if (@scanner[2] =~ /\/$/)
            @listener.tag_end(@scanner[1])
          end
        elsif @scanner.scan(TEXT)
          @listener.text(@scanner[1]) 
        elsif @scanner.scan(end_tag)
          @listener.tag_end(@scanner[1])
        else
          raise "Unimplemented element"
        end
      end
    end
  end

  class PTag
    @@mappings = { }
    def PTag::mappings
      @@mappings
    end

    def PTag::inherited( sub_class )
      key = sub_class.to_s.downcase
      key.gsub!(/^plist::/, '' )
      key.gsub!(/^p/, '')  unless key == "plist"

      @@mappings[key] = sub_class
    end

    attr_accessor :text, :children
    def initialize
      @children = Array.new
    end

    def to_ruby
      raise "Unimplemented: " + self.class.to_s + "#to_ruby on #{self.inspect}"
    end
  end

  class PList < PTag
    def to_ruby
      children.first.to_ruby
    end
  end

  class PDict < PTag
    def to_ruby
      dict = Hash.new
      key = nil

      children.each do |c|
        if key.nil?
          key = c.to_ruby
        else
          dict[key] = c.to_ruby
          key = nil
        end
      end

      dict
    end
  end

  class PKey < PTag
    def to_ruby
      text
    end
  end

  class PString < PTag
    def to_ruby
      text || ''
    end
  end

  class PArray < PTag
    def to_ruby
      children.collect do |c|
        c.to_ruby
      end
    end
  end

  class PInteger < PTag
    def to_ruby
      text.to_i
    end
  end

  class PTrue < PTag
    def to_ruby
      true
    end
  end

  class PFalse < PTag
    def to_ruby
      false
    end
  end

  class PReal < PTag
    def to_ruby
      text.to_f
    end
  end

  require 'date'
  class PDate < PTag
    def to_ruby
      DateTime.parse(text)
    end
  end

  require 'base64'
  require 'tempfile'
  class PData < PTag
    def to_ruby
      tf = Tempfile.new("plist.tmp")
      tf.write Base64.decode64(text.gsub(/\s+/,''))
      tf.close
      # is this a good idea?
      tf.open
      tf
    end
  end
  module Emit
    def save_plist(filename)
      File.open(filename, 'wb') do |f|
        f.write(self.to_plist)
      end
    end

    # Only the expected classes can be emitted as a plist:
    #   String, Float, DateTime, Integer, TrueClass, FalseClass, Array, Hash
    #
    # Write me if you think another class can be coerced safely into one of the
    # expected plist classes (plist@hexane.org)
    def to_plist( header = true )
      if (header)
        Plist::_xml(self.to_plist_fragment)
      else
        self.to_plist_fragment
      end
    end
  end
end

class String
  include Plist::Emit
  def to_plist_fragment
    "<string>#{self}</string>"
  end
end

class Symbol
  include Plist::Emit
  def to_plist_fragment
    "<string>#{self}</string>"
  end
end

class Float
  include Plist::Emit
  def to_plist_fragment
    "<real>#{self}</real>"
  end
end

class Time
  include Plist::Emit
  def to_plist_fragment
    "<date>#{self.utc.strftime('%Y-%m-%dT%H:%M:%SZ')}</date>"
  end
end

class Date
  include Plist::Emit
  def to_plist_fragment
    "<date>#{self.strftime('%Y-%m-%dT%H:%M:%SZ')}</date>"
  end
end

class Integer
  include Plist::Emit
  def to_plist_fragment
    "<integer>#{self}</integer>"
  end
end

class FalseClass
  include Plist::Emit
  def to_plist_fragment
    "<false/>"
  end
end

class TrueClass
  include Plist::Emit
  def to_plist_fragment
    "<true/>"
  end
end

class Array
  include Plist::Emit
  def to_plist_fragment
    fragment = "<array>\n"
    self.each do |e|
      element_plist = e.to_plist_fragment
      element_plist.each do |l|
        fragment += "\t#{l.chomp}\n"
      end
    end
    fragment += "</array>"
    fragment
  end
end

class Hash
  include Plist::Emit
  def to_plist_fragment
    fragment = "<dict>\n"
    self.keys.sort.each do |k|
      fragment += "\t<key>#{k}</key>\n"
      element_plist = self[k].to_plist_fragment
      element_plist.each do |l|
        fragment += "\t#{l.chomp}\n"
      end
    end
    fragment += "</dict>"
    fragment
  end
end

require 'stringio'
[ IO, StringIO ].each do |io_class|
  io_class.module_eval do
    include Plist::Emit
    def to_plist_fragment
      self.rewind
      data = self.read

      output = "<data>\n"
      Base64::encode64(data).gsub(/\s+/, '').scan(/.{1,68}/o) { output << $& << "\n" }
      output << "</data>"

      output
    end
  end
end