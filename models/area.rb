class Area
  include Mongoid::Document
  include Mongoid::Timestamps

  field :code
  field :name

  has_many :bicycle_stations
end
