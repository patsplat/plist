##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
#                 Patrick May <patrick@hexane.org>           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################

require 'test/unit'
require 'plist'

class TestBasicTypes < Test::Unit::TestCase
  def wrap(tag, content)
    return "<array>\n\t<#{tag}>#{content}</#{tag}>\n</array>"
  end

  def test_strings
    expected = wrap('string', 'testdata')

    assert_equal expected, ['testdata'].to_plist(false)
    assert_equal expected, [:testdata].to_plist(false)
  end

  def test_integers
    [42, 2376239847623987623, -8192].each do |i|
      assert_equal wrap('integer', i), [i].to_plist(false)
    end
  end

  def test_floats
    [3.14159, -38.3897, 2398476293847.9823749872349980].each do |i|
      assert_equal wrap('real', i), [i].to_plist(false)
    end
  end

  def test_booleans
    assert_equal "<array>\n\t<true/>\n</array>",  [true].to_plist(false)
    assert_equal "<array>\n\t<false/>\n</array>", [false].to_plist(false)
  end

  def test_time
    test_time = Time.now
    assert_equal wrap('date', test_time.utc.strftime('%Y-%m-%dT%H:%M:%SZ')), [test_time].to_plist(false)
  end

  def test_dates
    test_date = Date.today
    test_datetime = DateTime.now

    assert_equal wrap('date', test_date.strftime('%Y-%m-%dT%H:%M:%SZ')), [test_date].to_plist(false)
    assert_equal wrap('date', test_datetime.strftime('%Y-%m-%dT%H:%M:%SZ')), [test_datetime].to_plist(false)
  end

  # generater tests from patrick's plist.rb code
  def test_to_plist
    assert_equal( Plist::_xml("<string>Hello, World</string>"),     "Hello, World".to_plist )
    assert_equal( Plist::_xml("<real>151936595.697543</real>"),     151936595.697543.to_plist )
    assert_equal( Plist::_xml("<date>2006-04-21T16:47:58Z</date>"), DateTime.parse("2006-04-21T16:47:58Z").to_plist )
    assert_equal( Plist::_xml("<integer>999000</integer>"),         999000.to_plist )
    assert_equal( Plist::_xml("<false/>"),                          false.to_plist )
    assert_equal( Plist::_xml("<true/>"),                           true.to_plist )

    assert_equal( Plist::_xml("<array>\n\t<true/>\n\t<false/>\n</array>"),
                  [ true, false ].to_plist )

    assert_equal( Plist::_xml("<dict>\n\t<key>False</key>\n\t<false/>\n\t<key>True</key>\n\t<true/>\n</dict>"),
                  { 'True' => true, 'False' => false }.to_plist )

    source = File.open("test/assets/AlbumData.xml") { |f| f.read }

    result = Plist::parse_xml(source)

    assert_equal( result, Plist::parse_xml(result.to_plist) )

    File.delete('hello.plist') if File.exists?('hello.plist')
    "Hello, World".save_plist('hello.plist')
    assert_equal( Plist::_xml("<string>Hello, World</string>"),
                  File.open('hello.plist') {|f| f.read }        )
    File.delete('hello.plist') if File.exists?('hello.plist')
  end

  def test_escape_string_values
    assert_equal( Plist::_xml("<string>&lt;plist&gt;</string>"),    "<plist>".to_plist )
    assert_equal( Plist::_xml("<string>Fish &amp; Chips</string>"), "Fish & Chips".to_plist )
  end

end
