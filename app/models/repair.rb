class Repair
  include ActiveModel::Model

  attr_accessor :id, :vehicle_id, :garage_id, :status, :description, :start_date, :end_date, :photos

  validates :vehicle_id, presence: true
  validates :garage_id, presence: true
  validates :status, inclusion: { in: ["en attente", "en cours", "terminé"] }, allow_blank: true
  validates :start_date, presence: true
  validates :end_date, presence: true, if: -> { status == "terminé" }

  def initialize(attributes = {})
    @id = attributes[:id]
    @vehicle_id = attributes[:vehicle_id]
    @garage_id = attributes[:garage_id]
    @status = attributes[:status]
    @description = attributes[:description]
    @start_date = attributes[:start_date]
    @end_date = attributes[:end_date]
    @photos = attributes[:photos] || []
  end
end
