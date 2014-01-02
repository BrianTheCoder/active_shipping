module ActiveMerchant
  module Shipping
    class DHL < Carrier
      cattr_reader :name
      @@name = "DHL"

      TEST_URL = "http://xmlpitest-ea.dhl.com/XMLShippingServlet"

      def requirements
        [:site_id, :password]
      end

      def find_rates(origin, destination, packages, options = {})
        quote = build_rate_request(origin, destination, packages)
        response = ssl_post((test_mode? ? TEST_URL : LIVE_URL), quote.to_s)
        result = Hash.from_xml(response)['DCTResponse']['GetQuoteResponse']

        if result.key?('Note')
          condition = result['Note']['Condition']
          RateResponse.new(false, condition['ConditionData'], result, {
            test: test_mode?,
            status: :error,
            carrier: @@name,
            status_description: condition['ConditionData'],
            error_code: condition['ConditionCode']
          })
        else
          rate_details = result['BkgDetails']['QtdShp']
          rates = rate_details.map do |details|
            next if details['ShippingCharge'].to_f == 0.0
            options = {
              :shipping_date => Date.parse(details['PickupDate']),
              :service_code => details['LocalProductCode'],
              :service_charge => details['WeightCharge'].to_f,
              :total_price => details['ShippingCharge'].to_f,
              :transit_days => details['TotalTransitDays'].to_i
            }
            if details.key?('QtdShpExChrg')
              options.merge!(:fuel_charge => details['QtdShpExChrg']['ChargeValue'].to_f)
            end
            RateEstimate.new(origin, destination, @@name, details['LocalProductName'], options)
          end
          RateResponse.new(true, 'Successfully Retrieved rate', {}, {
            :rates => rates,
            :test => test_mode?,
            :carrier_name => @@name
          })
        end
      end

      protected

      def build_rate_request(from, to, packages)
        root = XmlNode.new('p:DCTRequest', 'xmlns:p' => 'http://www.dhl.com', 'xmlns:p1' => 'http://www.dhl.com/datatypes', 'xmlns:p2' => 'http://www.dhl.com/DCTRequestdatatypes', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.dhl.com DCT-req.xsd') do |xml|
          xml << XmlNode.new('GetQuote') do |quote|
            quote << generate_request_header
            quote << generate_from(from)
            quote << generate_shipment(packages)
            quote << generate_to(to)
          end
        end
      end

      # generate request header
      def generate_request_header
        XmlNode.new('Request') do |request|
          request << XmlNode.new('ServiceHeader') do |header|
            header << XmlNode.new('SiteID', @options[:site_id])
            header << XmlNode.new('Password', @options[:password])
          end
        end
      end

      # generate shipping origin info
      def generate_from(address)
        XmlNode.new('From') do |shipper|
          shipper << XmlNode.new('CountryCode', address.country_code)
          shipper << XmlNode.new('Postalcode', address.postal_code)
          shipper << XmlNode.new('City', address.city)
        end
      end

      # generate shipping destination info
      def generate_to(address)
        XmlNode.new('To') do |to|
          to << XmlNode.new('CountryCode', address.country_code)
          to << XmlNode.new('Postalcode', address.postal_code)
          to << XmlNode.new('City', address.city)
        end
      end

      # generate shipment details, packages info
      def generate_shipment(packages)
        XmlNode.new('BkgDetails') do |details|
          details << XmlNode.new('PaymentCountryCode', 'US')
          details << XmlNode.new('Date', ready_date)
          details << XmlNode.new('ReadyTime', ready_time)
          details << XmlNode.new('ReadyTimeGMTOffset', '+00:00')
          details << XmlNode.new('DimensionUnit', 'CM')
          details << XmlNode.new('WeightUnit', 'KG')
          details << XmlNode.new('ShipmentWeight', packages.sum(&:kilograms).round(2))
          unless packages.empty?
            details << XmlNode.new('Pieces') do |pieces|
              packages.each do |package|
                pieces << XmlNode.new('Piece') do |piece|
                  piece << XmlNode.new('PieceID', rand(999999))
                  piece << XmlNode.new('Height', package.centimetres(:height))
                  piece << XmlNode.new('Depth', package.centimetres(:depth))
                  piece << XmlNode.new('Width', package.centimetres(:width))
                  piece << XmlNode.new('Weight', package.kilograms.round(2))
                end
              end
            end
          end
        end
      end

      # ready times are only 8a-5p(17h)
      def ready_time(time = Time.now)
        if time.hour >= 17 || time.hour < 8
          time.strftime("PT08H00M")
        else
          time.strftime("PT%HH%MM")
        end
      end

      # ready dates are only mon-fri
      def ready_date(time = Time.now)
        date = Date.parse(time.to_s)
        date = if (date.cwday >= 6) || (date.cwday >= 5 && time.hour >= 17)
          date.send(:next_day, 8-date.cwday)
        else
          date
        end
        date.strftime("%Y-%m-%d")
      end
    end
  end
end