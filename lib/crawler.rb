# encoding: utf-8
require "em-synchrony"
require './lib/data_source.rb'
class Crawler
  
  def initialize(opts={})
    @ds = DataSource.new
    @logger = BusinessLogger.new('log/crawler.log')
  end
  
  def run
    # first page
    fp_res = @ds.bicycle_stations_query
    if fp_res
      save_bicycle_stations( wrap_bicycle_stations(fp_res[:nodes]) )
      if fp_res[:page_count] && fp_res[:page_count]>1
        EM.synchrony do
          EM::Synchrony::Iterator.new((2..fp_res[:page_count]).to_a, 5).map do |page, iter|
            @ds.bicycle_stations_query(:page => page) do |res|
              if res
                save_bicycle_stations( wrap_bicycle_stations(res[:nodes]) )
              end
              iter.return "page #{page}"
            end
          end  # END EM::Synchrony::Iterator
          
          EM.stop
        end  # END EM.synchrony
      end
    end
  end
  
  
  private
  
  def save_bicycle_stations(bicycle_stations)
    db_existed = BicycleStation.in(:code => bicycle_stations.map(&:code)).inject({}){|h,e| h[e.code]=e; h }
    bicycle_stations.map do |e|
      if db_existed[e.code]
        db_existed[e.code].attributes = e.attributes.except('_id').symbolize_keys
        db_existed[e.code].save!
      else
        e.save!
      end
    end
  end
  
  def wrap_bicycle_stations(nodes)
    nodes.map do |hdata|
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
        s.location = [hdata['lon'].to_f, hdata['lat'].to_f]  if hdata['lon']!='0' && hdata['lat']!='0'
        s.attributes = hdata.slice("bigimage", "smallimage")
        # begin
          # s.image  = URI.parse("#{SITE}/#{hdata['bigimage']}")  if hdata['bigimage']
        # rescue OpenURI::HTTPError => ex
          # @logger.error(ex.exception.inspect+"\n\t"+ex.backtrace.join("\n\t"))
        # end
        s
      end
    end.compact
  end
  
end

