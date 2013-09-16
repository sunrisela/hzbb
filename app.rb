require 'debugger'
require 'yajl/json_gem'
require 'sinatra'
require 'mongoid'
require File.expand_path("../config/environments/#{Sinatra::Base.environment}",  __FILE__)

require_relative 'models/bicycle_station'
require_relative 'models/area'

set :public_folder, File.dirname(__FILE__) + '/assets'

Mongoid.load!("config/mongoid.yml", Sinatra::Base.environment)

get '/' do
  c = BicycleStation.count
  "Hello world!#{c}"
end
