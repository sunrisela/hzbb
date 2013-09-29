# encoding: utf-8
require 'net/http'
require 'em-synchrony/em-http'
require 'nokogiri'
require 'cgi'
require './lib/business_logger.rb'

class DataSource
  SITE = $config[:hzbus_host]
  ZXCCLICK_PARAMS = %W{dutyStatus provideService name address serviceTime phone idx tCount cCount lon lat roundBuilding isClear bigimage smallimage stopstatus roadposition}
  
  def initialize(opts={})
    @opts    = opts.reverse_merge({
      :retries => 2,
      :timeout => 60
    })
    @logger = BusinessLogger.new('log/data_source.log')
  end
  
  def bicycle_stations_query(opts={}, &block)
    opts.reverse_merge!(:area => -1, :rnd => 5, :page => 1)
    uri = URI.parse "#{SITE}/Page/BicyleSquare.aspx"
    params = opts.slice(:area, :rnd)
    
    # page大于1时，需要__VIEWSTATE参数
    if opts[:page]>1
      params[:AspNetPager1_input] = opts[:page]  
      params[:__VIEWSTATE] = get_viewstatus(opts[:page]-1)
      params[:__EVENTTARGET] = "AspNetPager1"
    end
    
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
          nodes << hdata  if hdata.present?
        end
      end
      { :nodes => nodes, :viewstatus => record_viewstatus(doc, opts[:page]), :page_count => get_page_count(doc) }
    }
    
    block_given? ? em_request(uri, params, {:parser => parser}, &block) : post(uri, params, {:parser => parser})
  end
  
  def parse_ZXCClick_func_parameters
    uri = URI.parse "#{SITE}/map/cTJs.js"
    res = get(uri, {}, {:parse_response => false})
    str = res.match(/function ZXCClick\((.*)\)/).try(:[], 1)
    str.strip.gsub(',', '')  if str
  end
  
  def get(uri, params, opts={})
    opts.reverse_merge!(:parse_response => true)
    uri.query = URI.encode_www_form(params)  if params.present?
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
  
  def post(uri, params, opts={})
    opts.reverse_merge!(:parse_response => true)
    uri.query = URI.encode_www_form(params)  if params.present?
    
    puts uri.to_s
    @logger.info(uri.to_s)
    
    request  = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data(params)
    
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
    ).apost(:body => params)
    
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
  
  def get_page_count(doc)
    el = doc.css("#AspNetPager1 div")[1]
    debugger unless el
    if el
      c = el.content.scan(/[0-9]+/).first
      c.to_i if c
    end
  end
  
  def get_viewstatus(page)
    file_path = "tmp/files/__VIEWSTATE_#{page}.txt"
    if File.exist?(file_path)
      File.new(file_path).read
    else
      file_path = Dir["tmp/files/__VIEWSTATE_*"].first
      File.new(file_path).read  if file_path
    end
  end
  
  def record_viewstatus(doc, page)
    el = doc.css("#__VIEWSTATE").first
    if el && el['value']
      file_dir  = "tmp/files"
      file_path = "#{file_dir}/__VIEWSTATE_#{page}.txt"
      FileUtils.mkdir_p file_dir
      File.open(file_path, "w") do |f|
        f << el['value']
      end
      el['value']
    end
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