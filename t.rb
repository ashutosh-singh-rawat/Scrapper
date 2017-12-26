
require 'net/http'
require 'uri'
require 'pry'
require 'resolv-replace'
class ProxyList
  extend Forwardable

  ProxyListFinishedError = Class.new(StandardError)

  def self.load(file_path)
    proxies = File.readlines(file_path).map do |line|
      Proxy.new(*line.strip.split(' '))
    end
    new proxies
  end

  def initialize(proxies = [], current = 0)
    @current = current
    @proxies = proxies
  end

  def proxy
    @proxies[@current]
  end

  def switch!
    @current += 1
    if proxy.nil?
      raise ProxyListFinishedError,
            'Proxy list is finished. Please refresh proxy list before restarting.'
    else
      puts "Switching to #{proxy} proxy"
    end
  end

  def_delegator :@proxies, :each
end


Proxy = Struct.new(:address, :port) do
  def to_s
    @to_s ||= "#{address}:#{port}"
  end

  alias inspect to_s

  def get(uri)
    Net::HTTP.new(uri.host, nil, address, port).start do |http|
      http.get(uri.path)
    end
  end

  protected

  attr_writer :address, :port
end


def retry!(uri)
  @proxies.switch!
  load_uri(uri)
end


def load_uri(uri)
  response = @proxies.proxy.get(uri)
  result = nil
  if response.code == '301'
    # puts (response.body)
    puts "Moved Temporarily"
    retry!(uri)
  elsif response.code == '200'
    puts("proxy: " + @proxies.proxy.to_s)
    result = response.body
  elsif response.code == '429'
    binding.pry
    retry!(uri)
  elsif response.code == '403'
    puts "403 Forbidden"
    retry!(uri)
  elsif response.code == '502'
    puts "Invalid proxy response"
    retry!(uri)
  elsif response.code == '503'
    puts "Maximum number of open connections reached"
    retry!(uri)
  end
  binding.pry
  result
rescue Errno::ECONNRESET => e
  puts 'Connection reset by peer'
  #@proxies.switch!
  #retry
  retry!(uri)
rescue Net::OpenTimeout => e
  puts 'Open Time out'
  retry!(uri)
rescue Net::ReadTimeout => e
  puts 'Read Time out'
  retry!(uri)
rescue Errno::ECONNREFUSED => e
  puts 'Connection Refused'
  retry!(uri)
rescue Errno::EHOSTUNREACH => e
  puts 'No route to host'
  retry!(uri)
end

proxies_path = '/home/ashutosh/Desktop/scrap/proxies.txt'
output_path  = '/home/ashutosh/Desktop/scrap/'

@proxies = ProxyList.load(proxies_path)
@output_path = output_path
@sleep_time = 0
URL = 'https://www.paginegialle.it/eng/ricerca/%s'.freeze
URL1 = "http://www.upcitemdb.com/upc/%s".freeze


u = URI.parse(format(URL, 'barber%20shop/Torino?'))
u1 = URI.parse(format(URL1, '4895182941618'))
binding.pry
html = load_uri(u)
