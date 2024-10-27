class Employee
  include ActiveModel::Model

  attr_accessor :id, :garage_id, :name, :role, :email

  validates :name, presence: true
  validates :role, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  def initialize(attributes = {})
    @id = attributes[:id]
    @garage_id = attributes[:garage_id]
    @name = attributes[:name]
    @role = attributes[:role]
    @email = attributes[:email]
  end
end
