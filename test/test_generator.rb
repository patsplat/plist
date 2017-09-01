require 'test/unit'
require 'plist'

class SerializableObject
  attr_accessor :foo

  def initialize(str)
    @foo = str
  end

  def to_plist_node
    return "<string>#{CGI.escapeHTML(@foo)}</string>"
  end
end

class TestGenerator < Test::Unit::TestCase
  def test_to_plist_vs_plist_emit_dump_no_envelope
    source = [1, :b, true]

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

    assert_equal "<string>#{str}</string>\n", Plist::Emit.dump(so, false)
  end

  def test_dumping_serializable_object_with_indent
    str = 'this object implements #to_plist_node'
    so = SerializableObject.new(str)
    expected = <<-END
<array>
	<string>#{str}</string>
</array>
END

    assert_equal expected, Plist::Emit.dump([so], false)
  end

  def test_write_plist
    data = [1, :two, {:c => 'dee'}]

    data.save_plist('test.plist')
    file = File.open('test.plist') {|f| f.read}

    assert_equal file, data.to_plist

    File.unlink('test.plist')
  end

  # The hash in this test was failing with 'hsh.keys.sort',
  # we are making sure it works with 'hsh.keys.sort_by'.
  def test_sorting_keys
    hsh = {:key1 => 1, :key4 => 4, 'key2' => 2, :key3 => 3}
    output = Plist::Emit.dump(hsh, false)
    expected = <<-STR
<dict>
  <key>key1</key>
  <integer>1</integer>
  <key>key2</key>
  <integer>2</integer>
  <key>key3</key>
  <integer>3</integer>
  <key>key4</key>
  <integer>4</integer>
</dict>
    STR

    assert_equal expected, output.gsub(/[\t]/, "\s\s")
  end

  def test_custom_base64_format
    hash = {:key1 => StringIO.new('f' * 41)}
    actual = Plist::Emit.dump(hash, false, :base64_width => 16, :base64_indent => false)
    expected = <<-STR
<dict>
	<key>key1</key>
	<data>
ZmZmZmZmZmZmZmZm
ZmZmZmZmZmZmZmZm
ZmZmZmZmZmZmZmZm
ZmZmZmY=
	</data>
</dict>
STR
    assert_equal expected, actual

    actual = Plist::Emit.dump(hash, false, :base64_width => 12, :base64_indent => false)
    expected = <<-STR
<dict>
	<key>key1</key>
	<data>
ZmZmZmZmZmZm
ZmZmZmZmZmZm
ZmZmZmZmZmZm
ZmZmZmZmZmZm
ZmZmZmY=
	</data>
</dict>
STR
    assert_equal expected, actual

    assert_raises ArgumentError do
      Plist::Emit.dump(hash, false, :base64_width => 17, :base64_indent => true)
    end
  end

  def test_custom_indent
    hash = { :key1 => 1, 'key2' => [3] }

    actual = Plist::Emit.dump(hash, true, :indent => '   ')
    expected = <<-STR
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
   <key>key1</key>
   <integer>1</integer>
   <key>key2</key>
   <array>
      <integer>3</integer>
   </array>
</dict>
</plist>
STR
    assert_equal expected, actual

    actual = Plist::Emit.dump(hash, false, :indent => '   ', :initial_indent => "\t")
    expected = <<-STR
	<dict>
	   <key>key1</key>
	   <integer>1</integer>
	   <key>key2</key>
	   <array>
	      <integer>3</integer>
	   </array>
	</dict>
STR
    assert_equal expected, actual
  end

  def test_envelope
    hsh = { :key1 => 1, 'key2' => 2 }
    output_plist_dump_with_envelope = Plist::Emit.dump(hsh, true, :indent => nil)
    output_plist_dump_with_xml11_envelope = Plist::Emit.dump(hsh, true, :indent => nil, :xml_version => '1.1')
    output_plist_dump_no_envelope = Plist::Emit.dump(hsh, false, :indent => nil)

    expected_with_envelope = <<-STR
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>key1</key>
<integer>1</integer>
<key>key2</key>
<integer>2</integer>
</dict>
</plist>
STR

    expected_with_xml11_envelope = <<-STR
<?xml version="1.1" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>key1</key>
<integer>1</integer>
<key>key2</key>
<integer>2</integer>
</dict>
</plist>
STR

    expected_no_envelope = <<-STR
<dict>
<key>key1</key>
<integer>1</integer>
<key>key2</key>
<integer>2</integer>
</dict>
STR
    assert_equal expected_with_envelope, output_plist_dump_with_envelope
    assert_equal expected_with_xml11_envelope, output_plist_dump_with_xml11_envelope
    assert_equal expected_no_envelope, output_plist_dump_no_envelope

    hsh.save_plist('test.plist', :indent => nil)
    output_plist_file = File.read('test.plist')
    assert_equal expected_with_envelope, output_plist_file
    File.unlink('test.plist')
  end
end
