# app/mailers/repair_mailer.rb
class RepairMailer < ApplicationMailer
  default from: 'affif.amine@live.fr'

  def repair_created(customer, vehicle, repair)
    @customer = customer
    @vehicle = vehicle
    @repair = repair
    mail(to: @customer[:email], subject: 'Nouvelle réparation créée pour votre véhicule')
  end

  def repair_completed(customer, vehicle)
    @customer = customer
    @vehicle = vehicle
    mail(to: @customer[:email], subject: 'Votre réparation est terminée !')
  end

  def intervention_created(customer, vehicle, intervention)
    @customer = customer
    @vehicle = vehicle
    @intervention = intervention
    mail(to: @customer[:email], subject: 'Nouvelle intervention sur votre véhicule')
  end
end
