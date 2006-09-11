##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
#                 Patrick May <patrick@hexane.org>           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################

require 'test/unit'
require 'plist'

class MarshableObject
  attr_accessor :foo

  def initialize(str)
    @foo = str
  end
end

class TestGeneratorData < Test::Unit::TestCase
  def test_marshaling_object
    mo = MarshableObject.new('this object was marshaled')
    
    expected = <<-END
<!-- The <data> element below contains a Ruby object which has been serialized with Marshal.dump. --><data>BAhvOhRNYXJzaGFibGVPYmplY3QGOglAZm9vIh50aGlzIG9iamVjdCB3YXMg
bWFyc2hhbGVk
</data>
END
    
    # must #chomp because heredocs won't let you not have a trailing newline.
    # this won't be a problem once nice indent code goes into this branch.
    assert_equal expected.chomp, Plist::Emit.dump(mo, false)
  end
end