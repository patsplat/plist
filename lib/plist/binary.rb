require "date"
require "nkf"
require "set"
require "stringio"

module Plist
  module Binary
    # Encodes +obj+ as a binary property list. If +obj+ is an Array, Hash, or
    # Set, the property list includes its contents.
    def self.binary_plist(obj)
      encoded_objs = flatten_collection(obj)
      ref_byte_size = min_byte_size(encoded_objs.length - 1)
      # Write header
      header = "bplist00"
      plist = StringIO.new
      plist << header
      # Write offset table.
      offset = 8
      offset_table = []
      offset_string = ""
      encoded_length = 0
      encoded_objs.each do |o|
        obj = binary_plist_obj(o, ref_byte_size)
        plist << obj
        encoded_length += obj.length
        offset_table << offset
        offset += obj.length
      end
      offset_table_addr = header.size + encoded_length
      offset_byte_size = min_byte_size(offset)
      offset_table.each do |offset|
        plist << pack_int(offset, offset_byte_size)
      end
      # Write trailer.
      plist << "\0\0\0\0\0\0" # Six unused bytes
      plist << [
        offset_byte_size,
        ref_byte_size,
        encoded_objs.length >> 32, encoded_objs.length & 0xffffffff,
        0, 0, # Index of root object
        offset_table_addr >> 32, offset_table_addr & 0xffffffff
      ].pack("CCNNNNNN")
      plist.string
    end
    
  private
    
    # These marker bytes are prefixed to objects in a binary property list to
    # indicate the type of the object.
    CFBinaryPlistMarkerNull = 0x00 # :nodoc:
    CFBinaryPlistMarkerFalse = 0x08 # :nodoc:
    CFBinaryPlistMarkerTrue = 0x09 # :nodoc:
    CFBinaryPlistMarkerFill = 0x0F # :nodoc:
    CFBinaryPlistMarkerInt = 0x10 # :nodoc:
    CFBinaryPlistMarkerReal = 0x20 # :nodoc:
    CFBinaryPlistMarkerDate = 0x33 # :nodoc:
    CFBinaryPlistMarkerData = 0x40 # :nodoc:
    CFBinaryPlistMarkerASCIIString = 0x50 # :nodoc:
    CFBinaryPlistMarkerUnicode16String = 0x60 # :nodoc:
    CFBinaryPlistMarkerUID = 0x80 # :nodoc:
    CFBinaryPlistMarkerArray = 0xA0 # :nodoc:
    CFBinaryPlistMarkerSet = 0xC0 # :nodoc:
    CFBinaryPlistMarkerDict = 0xD0 # :nodoc:
    
    # POSIX uses a reference time of 1970-01-01T00:00:00Z; Cocoa's reference
    # time is in 2001. This interval is for converting between the two.
    NSTimeIntervalSince1970 = 978307200.0 # :nodoc:
    
    # Takes an object (nominally a collection, like an Array, Set, or Hash, but
    # any object is acceptable) and flattens it into a one-dimensional array.
    # Non-collection objects appear in the array as-is, but the contents of
    # Arrays, Sets, and Hashes are modified like so: (1) The contents of the
    # collection are added, one-by-one, to the one-dimensional array. (2) The
    # collection itself is modified so that it contains indexes pointing to the
    # objects in the one-dimensional array. Here's an example with an Array:
    #
    #   ary = [:a, :b, :c]
    #   flatten_collection(ary) # => [[1, 2, 3], :a, :b, :c]
    #
    # In the case of a Hash, keys and values are both appended to the one-
    # dimensional array and then replaced with indexes.
    #
    #   hsh = {:a => "blue", :b => "purple", :c => "green"}
    #   flatten_collection(hsh)
    #   # => [{1 => 2, 3 => 4, 5 => 6}, :a, "blue", :b, "purple", :c, "green"]
    #
    # An object will never be added to the one-dimensional array twice. If a
    # collection refers to an object more than once, the object will be added
    # to the one-dimensional array only once.
    #
    #   ary = [:a, :a, :a]
    #   flatten_collection(ary) # => [[1, 1, 1], :a]
    #
    # The +obj_list+ and +id_refs+ parameters are private; they're used for
    # descending into sub-collections recursively.
    def self.flatten_collection(collection, obj_list = [], id_refs = {})
      case collection
      when Array, Set
        if id_refs[collection.object_id]
          return obj_list[id_refs[collection.object_id]]
        end
        obj_refs = collection.class.new
        id_refs[collection.object_id] = obj_list.length
        obj_list << obj_refs
        collection.each do |obj|
          flatten_collection(obj, obj_list, id_refs)
          obj_refs << id_refs[obj.object_id]
        end
        return obj_list
      when Hash
        if id_refs[collection.object_id]
          return obj_list[id_refs[collection.object_id]]
        end
        obj_refs = {}
        id_refs[collection.object_id] = obj_list.length
        obj_list << obj_refs
        collection.each do |key, value|
          key = key.to_s if key.is_a?(Symbol)
          flatten_collection(key, obj_list, id_refs)
          flatten_collection(value, obj_list, id_refs)
          obj_refs[id_refs[key.object_id]] = id_refs[value.object_id]
        end
        return obj_list
      else
        unless id_refs[collection.object_id]
          id_refs[collection.object_id] = obj_list.length
          obj_list << collection
        end
        return obj_list
      end
    end
    
    # Returns a binary property list fragment that represents +obj+. The
    # returned string is not a complete property list, just a fragment that
    # describes +obj+, and is not useful without a header, offset table, and
    # trailer.
    #
    # The following classes are recognized: String, Float, Integer, the Boolean
    # classes, Time, IO, StringIO, Array, Set, and Hash. IO and StringIO
    # objects are rewound, read, and the contents stored as data (i.e., Cocoa
    # applications will decode them as NSData). All other classes are dumped
    # with Marshal and stored as data.
    #
    # Note that subclasses of the supported classes will be encoded as though
    # they were the supported superclass. Thus, a subclass of (for example)
    # String will be encoded and decoded as a String, not as the subclass:
    #
    #   class ExampleString < String
    #     ...
    #   end
    #
    #   s = ExampleString.new("disquieting plantlike mystery")
    #   encoded_s = binary_plist_obj(s)
    #   decoded_s = decode_binary_plist_obj(encoded_s)
    #   puts decoded_s.class # => String
    #
    # +ref_byte_size+ is the number of bytes to use for storing references to
    # other objects.
    def self.binary_plist_obj(obj, ref_byte_size = 4)
      case obj
      when String
        obj = obj.to_s if obj.is_a?(Symbol)
        # This doesn't really work. NKF's guess method is really, really bad
        # at discovering UTF8 when only a handful of characters are multi-byte.
        encoding = NKF.guess2(obj)
        if encoding == NKF::ASCII && obj =~ /[\x80-\xff]/
          encoding = NKF::UTF8
        end
        if [NKF::ASCII, NKF::BINARY, NKF::UNKNOWN].include?(encoding)
          result = (CFBinaryPlistMarkerASCIIString |
            (obj.length < 15 ? obj.length : 0xf)).chr
          result += binary_plist_obj(obj.length) if obj.length >= 15
          result += obj
          return result
        else
          # Convert to UTF8.
          if encoding == NKF::UTF8
            utf8 = obj
          else
            utf8 = NKF.nkf("-m0 -w", obj)
          end
          # Decode each character's UCS codepoint.
          codepoints = []
          i = 0
          while i < utf8.length
            byte = utf8[i]
            if byte & 0xe0 == 0xc0
              codepoints << ((byte & 0x1f) << 6) + (utf8[i+1] & 0x3f)
              i += 1
            elsif byte & 0xf0 == 0xe0
              codepoints << ((byte & 0xf) << 12) + ((utf8[i+1] & 0x3f) << 6) +
                (utf8[i+2] & 0x3f)
              i += 2
            elsif byte & 0xf8 == 0xf0
              codepoints << ((byte & 0xe) << 18) + ((utf8[i+1] & 0x3f) << 12) +
                ((utf8[i+2] & 0x3f) << 6) + (utf8[i+3] & 0x3f)
              i += 3
            else
              codepoints << byte
            end
            if codepoints.last > 0xffff
              raise(ArgumentError, "codepoint too high - only the Basic Multilingual Plane can be encoded")
            end
            i += 1
          end
          # Return string of 16-bit codepoints.
          data = codepoints.pack("n*")
          result = (CFBinaryPlistMarkerUnicode16String |
            (codepoints.length < 15 ? codepoints.length : 0xf)).chr
          result += binary_plist_obj(codepoints.length) if codepoints.length >= 15
          result += data
          return result
        end
      when Float
        return (CFBinaryPlistMarkerReal | 3).chr + [obj].pack("G")
      when Integer
        nbytes = min_byte_size(obj)
        size_bits = { 1 => 0, 2 => 1, 4 => 2, 8 => 3, 16 => 4 }[nbytes]
        return (CFBinaryPlistMarkerInt | size_bits).chr + pack_int(obj, nbytes)
      when TrueClass
        return CFBinaryPlistMarkerTrue.chr
      when FalseClass
        return CFBinaryPlistMarkerFalse.chr
      when Time
        return CFBinaryPlistMarkerDate.chr +
          [obj.to_f - NSTimeIntervalSince1970].pack("G")
      when IO, StringIO
        obj.rewind
        return binary_plist_data(obj.read)
      when Array
        # Must be an array of object references as returned by flatten_collection.
        result = StringIO.new        
        result << (CFBinaryPlistMarkerArray | (obj.length < 15 ? obj.length : 0xf)).chr
        result << binary_plist_obj(obj.length) if obj.length >= 15
        obj.each do |i|
          result << pack_int(i, ref_byte_size)
        end
        result.string
      when Set
        # Must be a set of object references as returned by flatten_collection.
        result = StringIO.new
        result << (CFBinaryPlistMarkerSet | (obj.length < 15 ? obj.length : 0xf)).chr
        result << binary_plist_obj(obj.length) if obj.length >= 15
        obj.to_a.each do |i|
          result << pack_int(i, ref_byte_size)
        end
        result.string
      when Hash
        # Must be a table of object references as returned by flatten_collection.
        result = StringIO.new
        result << (CFBinaryPlistMarkerDict | (obj.length < 15 ? obj.length : 0xf)).chr
        result << binary_plist_obj(obj.length) if obj.length >= 15
        res_keys = StringIO.new
        res_values = StringIO.new
        obj.each do |k, v|
          res_keys << pack_int(k, ref_byte_size)
          res_values << pack_int(v, ref_byte_size)
        end
        result << res_keys.string
        result << res_values.string
        result.string
      else
        return binary_plist_data(Marshal.dump(obj))
      end
    end
    
    # Returns a binary property list fragment that represents a data object
    # with the contents of the string +data+. A Cocoa application would decode
    # this fragment as NSData. Like binary_plist_obj, the value returned by
    # this method is not usable by itself; it is only useful as part of a
    # complete binary property list with a header, offset table, and trailer.
    def self.binary_plist_data(data)
      result = (CFBinaryPlistMarkerData |
        (data.length < 15 ? data.length : 0xf)).chr
      result += binary_plist_obj(data.length) if data.length > 15
      result += data
      return result
    end
    
    # Determines the minimum number of bytes that is a power of two and can
    # represent the integer +i+. Raises a RangeError if the number of bytes
    # exceeds 16. Note that the property list format considers integers of 1,
    # 2, and 4 bytes to be unsigned, while 8- and 16-byte integers are signed;
    # thus negative integers will always require at least 8 bytes of storage.
    def self.min_byte_size(i)
      if i < 0
        i = i.abs - 1
      else
        if i <= 0xff
          return 1
        elsif i <= 0xffff
          return 2
        elsif i <= 0xffffffff
          return 4
        end
      end      
      if i <= 0x7fffffffffffffff
        return 8
      elsif i <= 0x7fffffffffffffffffffffffffffffff
        return 16
      end
      raise(RangeError, "integer too big - exceeds 128 bits")
    end
    
    # Packs an integer +i+ into its binary representation in the specified
    # number of bytes. Byte order is big-endian. Negative integers cannot be
    # stored in 1, 2, or 4 bytes.
    def self.pack_int(i, num_bytes)
      if i < 0 && num_bytes < 8
        raise(ArgumentError, "negative integers require 8 or 16 bytes of storage")
      end
      case num_bytes
      when 1:
        [i].pack("c")
      when 2:
        [i].pack("n")
      when 4:
        [i].pack("N")
      when 8:
        [(i >> 32) & 0xffffffff, i & 0xffffffff].pack("NN")
      when 16:
        [i >> 96, (i >> 64) & 0xffffffff, (i >> 32) & 0xffffffff,
          i & 0xffffffff].pack("NNNN")
      else
        raise(ArgumentError, "num_bytes must be 1, 2, 4, 8, or 16")
      end
    end
  end
end
