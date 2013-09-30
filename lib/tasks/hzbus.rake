# encoding: utf-8
namespace :hzbus do
  desc "公共自行车数据抓取"
  task :run_crawler => :environment do |t|
    require File.expand_path('../lib/crawler', __FILE__)
    Crawler.new.run
  end
end