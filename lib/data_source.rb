# encoding: utf-8
require 'net/http'
require 'em-synchrony/em-http'
require 'nokogiri'
require 'cgi'
require './lib/business_logger.rb'

class DataSource
  SITE = "http://www.hzbus.cn"
  ZXCCLICK_PARAMS = %W{dutyStatus provideService name address serviceTime phone idx tCount cCount lon lat roundBuilding isClear bigimage smallimage stopstatus roadposition}
  
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
      nodes = []
      doc.css('#dvInit li.bt').each do |e|
        v = e.attributes['onclick'].value.match(/ZXCClick\((.+?)\);/).try(:[], 1)
        if v
          data  = unescape_unicode(v).split(',').map do |e| 
            e.gsub!(/^' ?|'$/, "")
            e if e.length>0 && e!='-'
          end
          hdata = {}
          ZXCCLICK_PARAMS.each_with_index do |p,i|
            hdata[p] = (data[i].present? && data[i]!='-') ? data[i] : nil
          end
          name_splited = hdata['name'].sub('№', '').split(' ')
          if name_splited[0].present? && name_splited[1]!='-'
            s = BicycleStation.new(
              :code            => name_splited[0],
              :name            => name_splited[1],
              :address         => hdata['address'],
              :road_position   => hdata['roadposition'] && hdata['roadposition'].gsub(/[\(\)]/,''),
              :rent_num        => hdata['tCount'].to_i,
              :idle_num        => hdata['cCount'].to_i,
              :service_time    => hdata['serviceTime'],
              :provide_service => hdata['provideService'] && hdata['provideService'].split("&nbsp;"),
              :phone           => hdata['phone'],
              :duty_status     => hdata['dutyStatus'],
              :stop_status     => hdata['stopstatus'] && hdata['stopstatus'].to_i,
              :round_building  => hdata['roundBuilding']
            )
            s.location = [hdata['lon'].to_f, hdata['lat'].to_f]  if hdata['lon']=='0' && hdata['lat']=='0'
            begin
              s.image  = URI.parse("#{SITE}/#{hdata['bigimage']}")  if hdata['bigimage']
            rescue OpenURI::HTTPError => ex
              @logger.error(ex.exception.inspect+"\n\t"+ex.backtrace.join("\n\t"))
            end
            nodes << s
          end
        end
      end
      nodes
    }
    
    block_given? ? em_request(uri, params, {:parser => parser}, &block) : get(uri, params, {:parser => parser})
  end
  
  def parse_ZXCClick_func_parameters
    uri = URI.parse "#{SITE}/map/cTJs.js"
    res = get(uri, {}, {:parse_response => false})
    str = res.match(/function ZXCClick\((.*)\)/).try(:[], 1)
    str.strip.split(",")  if str
  end
  
  def get(uri, params, opts={})
    opts.reverse_merge!(:parse_response => true)
    uri.query = URI.encode_www_form(params)
    puts uri.to_s
    @logger.info(uri.to_s)
    request  = Net::HTTP::Get.new(uri.request_uri)
    response = _send_request(uri, request, :body => opts[:body])
    if response
      if opts[:parse_response] && opts[:parser]
        opts[:parser].call(response.body)
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
      if opts[:parse_response] && opts[:parser]
        yield opts[:parser].call(rsp)
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