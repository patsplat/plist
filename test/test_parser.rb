require 'test/unit'
require 'plist'

class TestParser < Test::Unit::TestCase
  def test_parse_xml
    result = Plist.parse_xml("test/assets/AlbumData.xml")

    # dict
    assert_kind_of(Hash, result)

    expected = [
      "List of Albums",
      "Minor Version",
      "Master Image List",
      "Major Version",
      "List of Keywords",
      "Archive Path",
      "List of Rolls",
      "Application Version"
    ]
    assert_equal(expected.sort, result.keys.sort)

    # array
    assert_kind_of(Array, result["List of Rolls"])
    assert_equal([ {"PhotoCount"=>1,
                     "KeyList"=>["7"],
                     "Parent"=>999000,
                     "Album Type"=>"Regular",
                     "AlbumName"=>"Roll 1",
                     "AlbumId"=>6}],
                  result["List of Rolls"])

    # string
    assert_kind_of(String, result["Application Version"])
    assert_equal("5.0.4 (263)", result["Application Version"])

    # integer
    assert_kind_of(Integer, result["Major Version"])
    assert_equal(2, result["Major Version"])

    # true
    assert_kind_of(TrueClass, result["List of Albums"][0]["Master"])
    assert(result["List of Albums"][0]["Master"])

    # false
    assert_kind_of(FalseClass, result["List of Albums"][1]["SlideShowUseTitles"])
    assert(!result["List of Albums"][1]["SlideShowUseTitles"])
  end

  # uncomment this test to work on speed optimization
  # def test_load_something_big
  #   plist = Plist.parse_xml("~/Pictures/iPhoto Library/AlbumData.xml")
  # end

  # date fields are credited to
  def test_date_fields
    result = Plist.parse_xml("test/assets/Cookies.plist")
    assert_kind_of(DateTime, result.first['Expires'])
    assert_equal DateTime.parse("2007-10-25T12:36:35Z"), result.first['Expires']
  end

  # bug fix for empty <key>
  # reported by Matthias Peick <matthias@peick.de>
  # reported and fixed by Frederik Seiffert <ego@frederikseiffert.de>
  def test_empty_dict_key
    data = Plist.parse_xml("test/assets/test_empty_key.plist");
    assert_equal("2", data['key']['subkey'])
  end

  def test_cdata
    data = Plist.parse_xml("<string><![CDATA[<unescaped/>]]></string>")
    assert_equal('<unescaped/>', data)
  end

  def test_mixed_text_and_cdata
    data = Plist.parse_xml('<string>text and <![CDATA[<string>unescaped</string>]]></string>')
    assert_equal('text and <string>unescaped</string>', data)
  end

  def test_unescaped_cdata_inside_cdata
    data = Plist.parse_xml('<string><![CDATA[<![CDATA[ ... ]]]]><![CDATA[>]]></string>')
    assert_equal('<![CDATA[ ... ]]>', data)
  end

  # bug fix for decoding entities
  #  reported by Matthias Peick <matthias@peick.de>
  def test_decode_entities
    data = Plist.parse_xml('<string>Fish &amp; Chips</string>')
    assert_equal('Fish & Chips', data)
  end

  def test_comment_handling_and_empty_plist
    assert_nothing_raised do
      assert_nil(Plist.parse_xml(File.read('test/assets/commented.plist')))
    end
  end

  def test_filename_or_xml_is_stringio
    require 'stringio'

    str = StringIO.new
    data = Plist.parse_xml(str)

    assert_nil data
  end

  def test_filename_or_xml_is_encoded_with_ascii_8bit
    # skip if Ruby version does not support String#force_encoding
    return unless String.method_defined?(:force_encoding)

    xml = File.read("test/assets/non-ascii-but-utf-8.plist")
    xml.force_encoding("ASCII-8BIT")

    assert_nothing_raised do
      data = Plist.parse_xml(xml)
      assert_equal("\u0099", data["non-ascii-but-utf8-character"])
    end
  end

  def test_unimplemented_element
    assert_raise Plist::UnimplementedElementError do
      Plist.parse_xml('<string>Fish &amp; Chips</tring>')
    end
  end

  def test_marshal_is_enabled_by_default_meaning_data_is_passed_to_marshal_load
    plist = <<-PLIST.strip
      <plist version="1.0">
      <dict>
        <key>Token</key>
        <data>
        BANUb2tlbg==
        </data>
      </dict>
      </plist>
    PLIST

    data = Plist.parse_xml(plist)
    # "BANUb2tlbg==" is interpreted as `true` when base64 decoded and passed to Marshal.load
    assert_equal(true, data["Token"])
  end

  def test_data_unrecognized_by_marshal_load_is_returned_as_raw_binary
    jpeg = File.read(File.expand_path("../assets/example_data.jpg", __FILE__))
    plist = <<-PLIST.strip
      <plist version="1.0">
      <dict>
        <key>Token</key>
        <data>
        #{Base64.encode64(jpeg)}
        </data>
      </dict>
      </plist>
    PLIST

    data = Plist.parse_xml(plist)
    assert_kind_of(StringIO, data["Token"])
    assert_equal(jpeg, data["Token"].read)
  end

  def test_marshal_can_be_disabled_so_that_data_is_always_returned_as_raw_binary
    plist = <<-PLIST.strip
      <plist version="1.0">
      <dict>
        <key>Token</key>
        <data>
        BANUb2tlbg==
        </data>
      </dict>
      </plist>
    PLIST

    data = Plist.parse_xml(plist, marshal: false)
    assert_kind_of(StringIO, data["Token"])
    assert_equal("\x04\x03Token", data["Token"].read)
  end
end
