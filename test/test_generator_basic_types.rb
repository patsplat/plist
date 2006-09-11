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
    return "<#{tag}>#{content}</#{tag}>"
  end

  def test_strings
    expected = wrap('string', 'testdata')

    assert_equal expected, Plist::Emit.dump('testdata', false)
    assert_equal expected, Plist::Emit.dump(:testdata, false)
  end

  def test_integers
    [42, 2376239847623987623, -8192].each do |i|
      assert_equal wrap('integer', i), Plist::Emit.dump(i, false)
    end
  end

  def test_floats
    [3.14159, -38.3897, 2398476293847.9823749872349980].each do |i|
      assert_equal wrap('real', i), Plist::Emit.dump(i, false)
    end
  end

  def test_booleans
    assert_equal "<true/>",  Plist::Emit.dump(true, false)
    assert_equal "<false/>", Plist::Emit.dump(false, false)
  end

  def test_time
    test_time = Time.now
    assert_equal wrap('date', test_time.utc.strftime('%Y-%m-%dT%H:%M:%SZ')), Plist::Emit.dump(test_time, false)
  end

  def test_dates
    test_date = Date.today
    test_datetime = DateTime.now

    assert_equal wrap('date', test_date.strftime('%Y-%m-%dT%H:%M:%SZ')), Plist::Emit.dump(test_date, false)
    assert_equal wrap('date', test_datetime.strftime('%Y-%m-%dT%H:%M:%SZ')), Plist::Emit.dump(test_datetime, false)
  end

  # generator tests from patrick's plist.rb code
  def test_to_plist
    source = File.open("test/assets/AlbumData.xml") { |f| f.read }

    result = Plist::parse_xml(source)

    assert_equal( result, Plist::parse_xml(result.to_plist) )

    #File.delete('hello.plist') if File.exists?('hello.plist')
    #"Hello, World".save_plist('hello.plist')
    #assert_equal( Plist::_xml("<string>Hello, World</string>"),
    #              File.open('hello.plist') {|f| f.read }        )
    #File.delete('hello.plist') if File.exists?('hello.plist')
  end

  def test_escape_string_values
    assert_equal( "<string>&lt;plist&gt;</string>",    Plist::Emit.dump("<plist>",      false) )
    assert_equal( "<string>Fish &amp; Chips</string>", Plist::Emit.dump("Fish & Chips", false) )
  end

end
