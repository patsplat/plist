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

    assert_equal "<string>#{str}</string>", Plist::Emit.dump(so, false)
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
    output = Plist::Emit.plist_node(hsh)
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
end
