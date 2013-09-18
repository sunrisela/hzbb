# encoding: utf-8
require 'net/http'
require 'em-synchrony/em-http'
require 'nokogiri'
require 'cgi'

class DataSource
  SITE = "http://www.hzbus.cn"
  
  def initialize(opts={})
    @opts    = opts.reverse_merge({
      :retries => 2,
      :timeout => 60
    })
    @logger = BusinessLogger.new('log/data_source.log','weekly')
  end
  
  def bicycle_stations_query(opts={})
    opts.reverse_merge!(:area => -1, :rnd => 5)
    uri = URI.parse "#{SITE}/Page/BicyleSquare.aspx"
    params = opts
    
    parser = Proc.new{|res_body|
      doc = Nokogiri::HTML(res_body)
      doc.css('#dvInit li.bt').each do |e|
        v = e.attributes['onclick'].value
        unescape_unicode( v.match(/ZXCClick\('.*'\)/)[0].match(/'.*'/)[0] )
      end
    }
    
    block_given? ? em_request(uri, params, :parser => parser, &block) : get(uri, params, :parser => parser)
  end
  
  
  def get(uri, params, opts={})
    opts.reverse_merge!(:parse_response => true)
    uri.query = URI.encode_www_form(params)
    puts uri.to_s
    @logger.info(uri.to_s)
    request  = Net::HTTP::Get.new(uri.request_uri)
    response = _send_request(uri, request, :body => opts[:body])
    if response
      if opts[:parse_response]
        JSON.parse response.body
      else
        response.body
      end
    end
  end
  
  # 返回值说：nil，表示结果为空(无错误); false，表示请求失败或数据返回格式错误。
  def em_request(uri, params, opts={}, &block)
    opts.reverse_merge!(:retry => 0, :parse_response => true)
    url = uri.to_s
    url += "?#{URI.encode_www_form(params)}" if params.present?
    @logger.info(url)
    
    http = EM::HttpRequest.new(uri, 
      :connect_timeout => @opts[:timeout], 
      :inactivity_timeout => 2*@opts[:timeout]
    ).aget(:query => params)
    
    # success
    http.callback do
      rsp = http.response
      if opts[:parse_response]
        yield 
      else
        yield rsp
      end
    end
    
    # failed
    http.errback do
      if opts[:retry] >= @opts[:retries]
        @logger.error("#{uri.to_s} -- " + http.error.inspect)
        yield false
      else
        opts[:retry] += 1
        em_request(uri, params, opts, &block)
      end
    end
    
    http
  end
  
  private
  
  def unescape_unicode(str)
    str.gsub(/(%u\w+)/){|e| [e[2..-1].hex].pack("U")}
  end
  
  def _send_request(url, request, opts={})
    request.body = opts[:body] if opts[:body].present?
    retries = @opts[:retries]
    begin
      timeout(@opts[:timeout]) do
        response = Net::HTTP.start(url.host, url.port) {|http| 
          http.request(request)
        }
      end
    rescue EOFError, Timeout::Error => ex
      if retries > 0
        retries -= 1; retry
      else
        # handle the timeout
        @logger.error "#{url.to_s} request failed. #{ex.message}"
      end
    end
  end
  
end