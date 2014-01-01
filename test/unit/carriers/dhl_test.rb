require 'test_helper'
require 'pry-nav'

class DHLTest < Test::Unit::TestCase
  def setup
    @carrier = DHL.new(site_id: 'CustomerTest', password: 'alkd89nBV', test: true)
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @chocolate = @packages[:chocolate_stuff]
  end

  def test_find_rates
    mock_response = xml_fixture('dhl/rates')
    @carrier.expects(:ssl_post).returns(mock_response)
    resp = @carrier.find_rates(@locations[:beverly_hills], @locations[:ottawa], [@chocolate])
    binding.pry
    assert resp.success?
    assert resp.test
    assert resp.is_a?(RateResponse)
  end

  def test_find_rates
    resp = @carrier.find_rates(@locations[:beverly_hills], @locations[:auckland], [@chocolate])
    binding.pry
    assert resp.success?
    assert resp.test
    assert resp.is_a?(RateResponse)
  end
end