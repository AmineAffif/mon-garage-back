require 'rest-client'

class RepairMailer < ApplicationMailer
  default from: 'affif.amine@live.fr'

  after_action :log_sent_email # Appeler la méthode après l'envoi de l'e-mail

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

  private

  def log_sent_email
    customer_firebase_auth_user_id = @customer[:firebaseAuthUserId]
    customer_company_id = @customer[:companyId]
    customer_email = @customer[:email]
    subject = mail.subject
    body = mail.body.raw_source
    timestamp = Time.now.iso8601

    log_sent_email_data = {
      fields: {
        firebaseAuthUserId: { stringValue: customer_firebase_auth_user_id },
        companyId: { stringValue: customer_company_id },
        customerEmail: { stringValue: customer_email },
        subject: { stringValue: subject },
        body: { stringValue: body },
        timestamp: { timestampValue: timestamp },
      }
    }

    begin
      RestClient.post(
        'https://firestore.googleapis.com/v1/projects/mon-garage-1b850/databases/(default)/documents/log_sent_email',
        log_sent_email_data.to_json,
        { content_type: :json, accept: :json }
      )
      Rails.logger.info("Email log created successfully.")
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error("Erreur lors de la journalisation du message : #{e.response}")
    end
  end

end
