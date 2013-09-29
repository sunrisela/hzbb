class BicycleStation
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip
  include Mongoid::Paranoia

  field :code
  field :name
  # 站点地址
  field :address
  field :road_position
  # 位置坐标lon, lat
  field :location, :type => Point
  # 可租数量tCount
  field :used_num, :as => :rent_num
  # 可还数量cCount
  field :idle_num, :as => :rented_num
  # 服务时间
  field :service_time, :as => :opening_hours
  # 可提供的其它服务
  field :provide_service, :type => Array
  # 服务电话
  field :phone
  # 值班状态
  field :duty_status
  # 停止服务
  field :stop_status, :type => Integer
  # 周边地标
  field :round_building
  
  has_mongoid_attached_file :image,
    :default_style  => :original,
    :url            => "/system/:class_images/:id/:hash.:extension",
    :path           => "#{Sinatra::Application.public_folder}:url",
    :hash_data      => ":class/:attachment/:id/:style",
    :hash_secret    => "e6Uv+KPnR9UVz1oaXUvRqVaWx6tKWQHT84mwx4QOw3y4MNFzvBJigHvMWk52lEGb7MSMTtWrCLdhRT8iNlq3MQ==",  # generate by SecureRandom.base64(64)
    :styles         => { :thumb => "150x92>" }

  belongs_to :area
  
  validates  :code, :name, :presence => true
  
  
  def full_address
    if self.road_position.present?
      "#{self.address}(#{self.road_position})"
    else
      self.address
    end
  end
  
  def image_url(style=:big)
    key = "#{style}image"
    "#{$config[:hzbus_host]}/#{self[key]}"  if self[key]
  end
  

end
