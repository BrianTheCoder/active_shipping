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
    resp = @carrier.find_rates(@locations[:beverly_hills], @locations[:auckland], [@chocolate])
    assert resp.success?
    assert resp.test
    assert resp.is_a?(RateResponse)

    resp.rates.each do |rate|
      assert rate.is_a?(ActiveMerchant::Shipping::RateEstimate)
    end
  end

end
