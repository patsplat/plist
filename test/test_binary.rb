# encoding: binary
require "test/unit"
require "plist"

class TestBinary < Test::Unit::TestCase
  def test_binary_min_byte_size
    # 1-, 2-, and 4-byte integers are unsigned.
    assert_equal(1, Plist::Binary.send(:min_byte_size, 0))
    assert_equal(1, Plist::Binary.send(:min_byte_size, 0xff))
    assert_equal(2, Plist::Binary.send(:min_byte_size, 0x100))
    assert_equal(2, Plist::Binary.send(:min_byte_size, 0xffff))
    assert_equal(4, Plist::Binary.send(:min_byte_size, 0x10000))
    assert_equal(4, Plist::Binary.send(:min_byte_size, 0xffffffff))
    # 8- and 16-byte integers are signed.
    assert_equal(8, Plist::Binary.send(:min_byte_size, 0x100000000))
    assert_equal(8, Plist::Binary.send(:min_byte_size, 0x7fffffffffffffff))
    assert_equal(16, Plist::Binary.send(:min_byte_size, 0x8000000000000000))
    assert_equal(16, Plist::Binary.send(:min_byte_size, 0x7fffffffffffffffffffffffffffffff))
    assert_raises(RangeError) { Plist::Binary.send(:min_byte_size, 0x80000000000000000000000000000000) }
    assert_equal(8, Plist::Binary.send(:min_byte_size, -1))
    assert_equal(8, Plist::Binary.send(:min_byte_size, -0x8000000000000000))
    assert_equal(16, Plist::Binary.send(:min_byte_size, -0x8000000000000001))
    assert_equal(16, Plist::Binary.send(:min_byte_size, -0x80000000000000000000000000000000))
    assert_raises(RangeError) { Plist::Binary.send(:min_byte_size, -0x80000000000000000000000000000001) }
  end
  
  def test_binary_pack_int
    assert_equal("\x0", Plist::Binary.send(:pack_int, 0, 1))
    assert_equal("\x0\x34", Plist::Binary.send(:pack_int, 0x34, 2))
    assert_equal("\x0\xde\xdb\xef", Plist::Binary.send(:pack_int, 0xdedbef, 4))
    assert_equal("\x0\xca\xfe\x0\x0\xde\xdb\xef", Plist::Binary.send(:pack_int, 0xcafe0000dedbef, 8))
    assert_equal("\x0\x7f\xf7\x0\x0\x12\x34\x0\x0\xca\xfe\x0\x0\xde\xdb\xef", Plist::Binary.send(:pack_int, 0x7ff7000012340000cafe0000dedbef, 16))
    assert_raises(ArgumentError) { Plist::Binary.send(:pack_int, -1, 1) }
    assert_raises(ArgumentError) { Plist::Binary.send(:pack_int, -1, 2) }
    assert_raises(ArgumentError) { Plist::Binary.send(:pack_int, -1, 4) }
    assert_equal("\xff\xff\xff\xff\xff\xff\xff\xff", Plist::Binary.send(:pack_int, -1, 8))
    assert_equal("\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff", Plist::Binary.send(:pack_int, -1, 16))
    [-2,0,3,5,6,7,9,10,11,12,13,14,15,17,18,19,20,32].each do |i|
      assert_raises(ArgumentError) { Plist::Binary.send(:pack_int, 0, i) }
    end
  end
  
  def test_binary_plist_data
    assert_equal("\x4ahelloworld",
      Plist::Binary.send(:binary_plist_data, "helloworld"))
    data = "x" * 32000
    assert_equal("\x4f\x11\x7d\x00#{data}",
      Plist::Binary.send(:binary_plist_data, data))
  end
  
  def test_flatten_collection
    assert_equal([[1, 2, 3], :a, :b, :c],
      Plist::Binary.send(:flatten_collection, [:a, :b, :c]))
    assert_equal([[1, 2, 3, 4], :a, :b, :c, [1, 1]],
      Plist::Binary.send(:flatten_collection, [:a, :b, :c, [:a, :a]]))
    assert_equal(["booger"],
      Plist::Binary.send(:flatten_collection, "booger"))
    assert_equal([[1, 2], "hello", { 3 => 4 }, "key", [5, 6, 7], 1, 2, 3],
      Plist::Binary.send(:flatten_collection, ["hello", { :key => [1, 2, 3] }]))
    ary = [:a, :b, :c]
    assert_equal([[1, 5], [2, 3, 4], :a, :b, :c, { 1 => 6 }, "whee"],
      Plist::Binary.send(:flatten_collection, [ary, { ary => "whee" }]))
    hsh = { :a => :b }
    assert_equal([[1, 4], { 2 => 3 }, "a", :b, [5, 6, 1], 1, 2],
      Plist::Binary.send(:flatten_collection, [hsh, [1, 2, hsh]]))
  end
  
  def test_binary_plist_obj
    assert_equal("\x5bHello World",
      Plist::Binary.send(:binary_plist_obj, "Hello World"))
    assert_equal("\x5f\x10\x1bDomo-kun's Angry Smash Fest",
      Plist::Binary.send(:binary_plist_obj, "Domo-kun's Angry Smash Fest"))
    assert_equal("\x63\x59\x7d\x30\x4d\x30\x60",
      Plist::Binary.send(:binary_plist_obj, "好きだ"))
    assert_raises(ArgumentError) { Plist::Binary.send(:binary_plist_obj, "𝄢") }
    assert_equal("\x63\x59\x7d\x30\x4d\x30\x60",
      Plist::Binary.send(:binary_plist_obj, "好きだ"))
    assert_equal("\x66\000s\000e\0\361\000o\000r\000a",
      Plist::Binary.send(:binary_plist_obj, "señora"))
    assert_equal("\x23#{[3.14159].pack('G')}",
      Plist::Binary.send(:binary_plist_obj, 3.14159))
    assert_equal("\x9", Plist::Binary.send(:binary_plist_obj, true))
    assert_equal("\x8", Plist::Binary.send(:binary_plist_obj, false))
    assert_equal("\x33\xc1\xcd\x27\xe4\x2\x80\x0\x0",
      Plist::Binary.send(:binary_plist_obj, Time.at(123)))
    sio = StringIO.new("Hello World")
    assert_equal("\x4bHello World", Plist::Binary.send(:binary_plist_obj, sio))
    assert_equal("\xa3\x1\x2\x3",
      Plist::Binary.send(:binary_plist_obj, [1, 2, 3], 1))
    assert_equal("\xaf\x10\x10\x1\x2\x3\x4\x5\x6\x7\x8\x9\xa\xb\xc\xd\xe\xf\x10",
      Plist::Binary.send(:binary_plist_obj, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], 1))
    assert_equal("\xa3\x0\x1\x0\x2\x0\x3",
      Plist::Binary.send(:binary_plist_obj, [1, 2, 3], 2))
    assert_equal("\xd2\x1\x3\x2\x4",
      Plist::Binary.send(:binary_plist_obj, {1=>2, 3=>4}, 1))
    assert_equal("\xdf\x10\x10\x5\x0\xb\x6\x1\xc\x7\x2\xd\x8\x3\xe\x9\x4\xf\xa\x15\x10\x1b\x16\x11\x1c\x17\x12\x1d\x18\x13\x1e\x19\x14\x1f\x1a",
      Plist::Binary.send(:binary_plist_obj, {5=>21, 11=>27, 0=>16, 6=>22, 12=>28, 1=>17, 7=>23, 13=>29, 2=>18, 8=>24, 14=>30, 3=>19, 9=>25, 15=>31, 4=>20, 10=>26}, 1))
    assert_equal("\xd2\x0\x1\x0\x3\x0\x2\x0\x4",
      Plist::Binary.send(:binary_plist_obj, {1=>2, 3=>4}, 2))
    assert_equal("\xc3\x1\x2\x3",
      Plist::Binary.send(:binary_plist_obj, Set.new([1, 2, 3]), 1))
    assert_equal("\xcf\x10\x10\x10\x5\xb\x6\xc\x1\x7\xd\x2\x8\xe\x3\x9\xf\x4\xa",
      Plist::Binary.send(:binary_plist_obj, Set.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]), 1))
    assert_equal("\xc3\x0\x1\x0\x2\x0\x3",
      Plist::Binary.send(:binary_plist_obj, Set.new([1, 2, 3]), 2))
    assert_equal("\x49\x4\x8/\x9narf\0",
      Plist::Binary.send(:binary_plist_obj, /narf/))
  end
  
  def test_binary_plist
    assert_equal("bplist00\x55hello\x8\x0\x0\x0\x0\x0\x0\x1\x1\x0\x0\x0\x0\x0\x0\x0\x1\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\xe",
      Plist::Binary.binary_plist("hello"))
    assert_equal("bplist00\xa4\x1\x2\x3\x6\x45\x4\x8\x3a\x6\x61\x45\x4\x8\x3a\x6\x62\xd1\x4\x5\x55\x73\x74\x75\x66\x66\x58\x77\x68\x61\x74\x65\x76\x65\x72\x10\x7b\x8\xd\x13\x19\x1c\x22\x2b\x0\x0\x0\x0\x0\x0\x1\x1\x0\x0\x0\x0\x0\x0\x0\x7\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x2d",
      Plist::Binary.binary_plist([:a, :b, { :stuff => "whatever" }, 123]))
  end
end
