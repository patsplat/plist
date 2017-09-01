require 'test/unit'
require 'plist'

class TestGenerateAndParse < Test::Unit::TestCase
  def test_generate_and_parse
    t = Time.now
    date = Date.new(t.year, t.month, t.day)
    hash = {
      "a key with \n new line inside" => "a value with \n new line inside",
      "foo" => [
        1.0,
        2,
        true,
        false,
        date
      ]
    }
    new_hash = Plist.parse_xml Plist::Emit.dump hash
    assert_equal hash, new_hash
  end
end
