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
end