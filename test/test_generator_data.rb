##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
#                 Patrick May <patrick@hexane.org>           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################

require 'test/unit'
require 'plist'
require 'stringio'

class MarshableObject
  attr_accessor :foo

  def initialize(str)
    @foo = str
  end
end

class TestGeneratorData < Test::Unit::TestCase
  @@marshal_expected = <<END
<!-- The <data> element below contains a Ruby object which has been serialized with Marshal.dump. --><data>BAhvOhRNYXJzaGFibGVPYmplY3QGOglAZm9vIh50aGlzIG9iamVjdCB3YXMg
bWFyc2hhbGVk
</data>
END
  
  @@io_expected = <<END
<data>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAA==
</data>
END

  @@sio_expected = <<END
<data>dGhpcyBpcyBhIHN0cmluZ2lvIG9iamVjdA==
</data>
END

  # must chomp because heredocs won't let you not have a trailing newline.
  # this won't be a problem once nice indent code goes into this branch.
  [@@marshal_expected, @@io_expected, @@sio_expected].each {|a| a.chomp! }

  def test_marshaling_object
    mo = MarshableObject.new('this object was marshaled')

    assert_equal @@marshal_expected, Plist::Emit.dump(mo, false)
  end
  
  def test_io
    fd = IO.sysopen('test/assets/example_data.bin')
    io = IO.open(fd, 'r')
    
    assert_equal @@io_expected, Plist::Emit.dump(io, false)
    
    io.close
  end
  
  # File is a subclass of IO, so catching IO in the dispatcher should work for File as well...
  def test_file
    f = File.open('test/assets/example_data.bin')
    
    assert_equal @@io_expected, Plist::Emit.dump(f, false)
    
    f.close
  end
  
  def test_string_io
    sio = StringIO.new('this is a stringio object')
    
    assert_equal @@sio_expected, Plist::Emit.dump(sio, false)
  end
end