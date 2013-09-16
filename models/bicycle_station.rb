class BicycleStation
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia

  field :code
  field :name
  field :type
  field :desc
  # 坐标
  field :point, :type => Array
  # 可租数量
  field :used_num
  # 可还数量
  field :idle_num

  belongs_to :area

  alias :rent_num   :used_num
  alias :rented_num :idle_num

end
