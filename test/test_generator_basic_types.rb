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
    return "<array><#{tag}>#{content}</#{tag}></array>"
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
    assert_equal "<array><true/></array>",  [true].to_plist(false)
    assert_equal "<array><false/></array>", [false].to_plist(false)
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
end