##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
#                 Patrick May <patrick@hexane.org>           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################

require 'test/unit'
require 'plist'

class SerializableObject
  attr_accessor :foo
  
  def initialize(str)
    @foo = str
  end
  
  def to_plist_node
    return "<string>#{CGI::escapeHTML @foo}</string>"
  end
end

class TestGenerator < Test::Unit::TestCase
  def test_to_plist_vs_plist_emit_dump_no_envelope
    source   = [1, :b, true]

    to_plist = source.to_plist(false)
    plist_emit_dump = Plist::Emit.dump(source, false)

    assert_equal to_plist, plist_emit_dump
  end

  def test_to_plist_vs_plist_emit_dump_with_envelope
    source   = [1, :b, true]

    to_plist = source.to_plist
    plist_emit_dump = Plist::Emit.dump(source)

    assert_equal to_plist, plist_emit_dump
  end
  
  def test_dumping_serializable_object
    str = 'this object implements #to_plist_node'
    so = SerializableObject.new(str)
    
    assert_equal "<string>#{str}</string>", Plist::Emit.dump(so, false)
  end
  
  def test_write_plist
    data = [1, :two, {:c => 'dee'}]
    
    data.save_plist('test.plist')
    file = File.open('test.plist') {|f| f.read}
    
    assert_equal file, data.to_plist
    
    File.unlink('test.plist')
  end

  # this functionality is credited to Mat Schaffer,
  # who discovered the plist with the data tag
  # supplied the test data, and provided the parsing code.
  def test_data
    data = Plist::parse_xml("test/assets/example_data.plist");
    assert_equal( File.open("test/assets/example_data.jpg"){|f| f.read }, data['image'].read )

#    these do not test the parser, they test the generator.  Commenting for now; test coverage
#    for this functionality will be in the new generator code.

    assert_equal( File.open("test/assets/example_data.plist"){|f| f.read }, data.to_plist )

    data['image'] = StringIO.new( File.open("test/assets/example_data.jpg"){ |f| f.read } )
    File.open('temp.plist', 'w'){|f| f.write data.to_plist }
    assert_equal( File.open("test/assets/example_data.plist"){|f| f.read }, data.to_plist )

    File.delete('temp.plist') if File.exists?('temp.plist')

  end
  
end
