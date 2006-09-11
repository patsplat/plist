##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
#                 Patrick May <patrick@hexane.org>           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################

require 'test/unit'
require 'plist'

class TestGenerator < Test::Unit::TestCase
  def test_to_plist_vs_plist_emit_dump_no_envelope
    source   = [1, :b, true]

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
end