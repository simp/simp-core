gem "minitest"
require "minitest/autorun"
require "simp/rake/helpers"

module TestSimp; end
module TestSimp::TestRake; end

class TestSimp::TestRake::TestHelpers < Minitest::Test
  def test_sanity
    flunk "write tests or I will kneecap you"
  end
end
