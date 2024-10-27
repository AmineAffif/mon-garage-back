class Notification
  include ActiveModel::Model

  attr_accessor :id, :customer_id, :repair_id, :date, :type, :content

  validates :customer_id, presence: true
  validates :repair_id, presence: true
  validates :date, presence: true
  validates :type, inclusion: { in: ["email", "SMS", "push"] }, presence: true
  validates :content, presence: true

  def initialize(attributes = {})
    @id = attributes[:id]
    @customer_id = attributes[:customer_id]
    @repair_id = attributes[:repair_id]
    @date = attributes[:date]
    @type = attributes[:type]
    @content = attributes[:content]
  end
end
