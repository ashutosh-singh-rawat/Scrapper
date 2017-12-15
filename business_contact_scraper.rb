require 'pry'
require 'uri'
module FraraccioKnife
  module EanUpc
    class Item < Struct.new(:code, :name, :country_of_registration, :brand,
                            :model, :weight, :asin, :product_dimension,
                            :last_scanned)
      ProductNameError = Class.new(StandardError)

      NAME_REGEXP = /- ([^|]+) /
      XPATH = '//dl[@class="detail-list"]/dt[text()="%s:"]/following-sibling::dd[1]'.freeze
      TITLES = {
        country_of_registration: 'Country of Registration',
        brand: 'Brand',
        model: 'Model #',
        weight: 'Weight',
        asin: 'Amazon ASIN',
        product_dimension: 'Product Dimension',
        last_scanned: 'Last Scanned'
      }.freeze

      def self.build(code, page)
        name_match = page.title.match(NAME_REGEXP)
        unless name_match
          raise ProductNameError, 'Unable to identify product name'
        end
        item = new(code, name_match[1])
        TITLES.each do |member, title|
          value = page.xpath(format(XPATH, title)).text
          value.strip!
          item[member] = value
        end
        item
      end
    end
  end
end

class Browser
  URL = 'http://www.upcitemdb.com/upc/%s'.freeze
  URL = 'https://www.paginegialle.it/eng/%s'.freeze
  IMAGE_XPATH = '//img[contains(@class,"product")]'
  NOT_FOUND_RESPONSE_TEXT =
      'you were looking for currently has no record in our database'.freeze
  INVALID_IMAGE_URL = '/static/img/resize.jpg'.freeze
  SLEEP_DURATION = 10

  def initialize(proxies_path, output_path)
    @proxies = ProxyList.load(proxies_path)
    @output_path = output_path
    @sleep_time = 0
  end

  def get(code)
    html = load(URI.parse(format(URL, code)))
    return if html.nil?

    page = Nokogiri::HTML(html)

    if page.to_s.include?(NOT_FOUND_RESPONSE_TEXT)
      puts "#{code} - not found!"
      return
    end

    puts code
    item = Item.build(code, page)

    load_image(code, page)

    item
  end

  private

    attr_reader :output_path
    attr_accessor :sleep_time

    def wait
      self.sleep_time += 1
      duration = sleep_time * rand(SLEEP_DURATION)
      puts "Waiting #{duration} seconds."
      sleep duration
    end

    def load_image(code, page)
      image_path = File.join(output_path, code)
      if Dir.glob("#{image_path}*").empty?
        image = page.xpath(IMAGE_XPATH).first
        if image && image['src'] != INVALID_IMAGE_URL
          image_url = image['src']
          uri = URI.parse(image_url)
          tmp_file = load(uri)
          return unless tmp_file
          File.write("#{image_path}#{File.extname(uri.path)}", tmp_file)
          puts "Loaded image for #{code}"
        end
      end
    end

    def load(uri)
      response = @proxies.proxy.get(uri)
      result = nil

      if response.code == '200'
        result = response.body
      elsif response.code == '429'
        @proxies.switch!
      end

      result
    rescue Errno::ECONNRESET => e
      puts 'Connection reset by peer'
      @proxies.switch!
      retry
    end
end
