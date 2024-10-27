class Intervention
  include ActiveModel::Model

  attr_accessor :id, :repair_id, :date, :description

  validates :repair_id, presence: true
  validates :date, presence: true
  validates :description, presence: true

  def initialize(attributes = {})
    @id = attributes[:id]
    @repair_id = attributes[:repair_id]
    @date = attributes[:date]
    @description = attributes[:description]
  end
end
