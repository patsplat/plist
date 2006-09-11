#--###########################################################
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

    # Only the expected classes can be emitted as a plist:
    #   String, Float, DateTime, Integer, TrueClass, FalseClass, Array, Hash
    #
    # Write me if you think another class can be coerced safely into one of the
    # expected plist classes (plist@hexane.org)
    def to_plist( header = true )
      if (header)
        Plist::_xml(self.to_plist_node)
      else
        self.to_plist_node
      end
    end
  end
end

class String
  include Plist::Emit
  def to_plist_node
    "<string>#{CGI::escapeHTML(self)}</string>"
  end
end

class Symbol
  include Plist::Emit
  def to_plist_node
    "<string>#{CGI::escapeHTML(self.to_s)}</string>"
  end
end

class Float
  include Plist::Emit
  def to_plist_node
    "<real>#{self}</real>"
  end
end

class Time
  include Plist::Emit
  def to_plist_node
    "<date>#{self.utc.strftime('%Y-%m-%dT%H:%M:%SZ')}</date>"
  end
end

class Date
  include Plist::Emit
  def to_plist_node
    "<date>#{self.strftime('%Y-%m-%dT%H:%M:%SZ')}</date>"
  end
end

class Integer
  include Plist::Emit
  def to_plist_node
    "<integer>#{self}</integer>"
  end
end

class FalseClass
  include Plist::Emit
  def to_plist_node
    "<false/>"
  end
end

class TrueClass
  include Plist::Emit
  def to_plist_node
    "<true/>"
  end
end

class Array
  include Plist::Emit
  def to_plist_node
    fragment = "<array>\n"
    self.each do |e|
      element_plist = e.to_plist_node
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
  def to_plist_node
    fragment = "<dict>\n"
    self.keys.sort.each do |k|
      fragment += "\t<key>#{CGI::escapeHTML(k)}</key>\n"
      element_plist = self[k].to_plist_node
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
    def to_plist_node
      self.rewind
      data = self.read

      output = "<data>\n"
      Base64::encode64(data).gsub(/\s+/, '').scan(/.{1,68}/o) { output << $& << "\n" }
      output << "</data>"

      output
    end
  end
end
