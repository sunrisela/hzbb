require 'debugger'
require 'yajl/json_gem'
require 'sinatra'
require 'mongoid'
require 'mongoid_paperclip'
require 'erb'
require 'sass'


$config = {}
configure :development do
  $config[:hzbus_host] = "http://www.hzbus.cn"
end

configure :production do
  $config[:hzbus_host] = "http://www.hzbus.cn"
end

require File.expand_path("../config/environments/#{Sinatra::Base.environment}",  __FILE__)

require File.expand_path("../lib/point.rb",  __FILE__)

# 加载mongodb模型
Dir[File.expand_path("../models/*.rb",__FILE__)].each{|file| require file }

Mongoid.load!("config/mongoid.yml", Sinatra::Base.environment)

#require './lib/data_source.rb'

# routes
get '/' do
  c = BicycleStation.count
  "Hello world!#{c}"
end

get '/crawler/run' do
  
end
