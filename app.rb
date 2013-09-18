require 'debugger'
require 'yajl/json_gem'
require 'sinatra'
require 'mongoid'
require 'erb'
require 'sass'


configure :development do
  
end

configure :production do
  
end

require File.expand_path("../config/environments/#{Sinatra::Base.environment}",  __FILE__)

# 加载mongodb模型
Dir[File.expand_path("../models/*.rb",__FILE__)].each{|file| require file }

Mongoid.load!("config/mongoid.yml", Sinatra::Base.environment)

set :public_folder, File.dirname(__FILE__) + '/assets'

# routes
get '/' do
  c = BicycleStation.count
  "Hello world!#{c}"
end

get '/crawler/run' do
  
end
