class Garage
  include ActiveModel::Model

  attr_accessor :id, :name, :address, :phone, :email

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, presence: true

  def initialize(attributes = {})
    @id = attributes[:id]
    @name = attributes[:name]
    @address = attributes[:address]
    @phone = attributes[:phone]
    @email = attributes[:email]
  end
end
