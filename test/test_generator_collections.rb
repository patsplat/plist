##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
#                 Patrick May <patrick@hexane.org>           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################

require 'test/unit'
require 'plist'

class TestGeneratorCollections < Test::Unit::TestCase
  def test_array
    assert_equal "<array><integer>1</integer><integer>2</integer><integer>3</integer></array>", [1,2,3].to_plist(false)
  end

  def test_hash
    # only one element because we can't predict what order the keys will come out in.  Sigh.
    assert_equal "<dict><key>foo</key><string>bar</string></dict>", {:foo => :bar}.to_plist(false)
  end

  def test_hash_with_array_element
    assert_equal "<dict><key>ary</key><array><integer>1</integer><string>b</string><string>3</string></array></dict>",
                 {:ary => [1,:b,'3']}.to_plist(false)
  end

  def test_array_with_hash_element
    assert_equal "<array><dict><key>foo</key><string>bar</string></dict><string>b</string><integer>3</integer></array>",
                 [{:foo => 'bar'}, :b, 3].to_plist(false)
  end
end
