require 'debugger'
require 'yajl/json_gem'
require 'sinatra'
require 'mongoid'
require 'mongoid_paperclip'
require 'erb'
require 'sass'



configure :development do
  
end

configure :production do
  
end

require File.expand_path("../config/environments/#{Sinatra::Base.environment}",  __FILE__)

require File.expand_path("../lib/point.rb",  __FILE__)

# 加载mongodb模型
Dir[File.expand_path("../models/*.rb",__FILE__)].each{|file| require file }

Mongoid.load!("config/mongoid.yml", Sinatra::Base.environment)

require './lib/data_source.rb'

# routes
get '/' do
  c = BicycleStation.count
  "Hello world!#{c}"
end

get '/crawler/run' do
  
end
