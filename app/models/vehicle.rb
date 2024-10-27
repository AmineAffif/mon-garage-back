class Vehicle
  include ActiveModel::Model

  attr_accessor :id, :customer_id, :vin, :make, :model, :year

  validates :vin, presence: true, length: { is: 17 }
  validates :make, presence: true
  validates :model, presence: true
  validates :year, numericality: { only_integer: true, greater_than: 1885 }, allow_blank: true

  def initialize(attributes = {})
    @id = attributes[:id]
    @customer_id = attributes[:customer_id]
    @vin = attributes[:vin]
    @make = attributes[:make]
    @model = attributes[:model]
    @year = attributes[:year]
  end
end
