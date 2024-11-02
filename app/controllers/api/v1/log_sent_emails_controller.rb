class Api::V1::LogSentEmailsController < ApplicationController
  before_action :authenticate_user, only: [:index]

  def index
    company_id = params[:companyId]
    Rails.logger.info("Received companyId: #{company_id}")

    # Requête structurée correcte pour filtrer les documents par companyId
    request_body = {
      structuredQuery: {
        from: [{ collectionId: 'log_sent_emails' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'companyId' },
            op: 'EQUAL',
            value: { stringValue: company_id }
          }
        }
      }
    }

    Rails.logger.info("Request Body: #{request_body.to_json}")
    response = FirebaseRestClient.firestore_request(':runQuery', :post, request_body)

    Rails.logger.info("Response Body: #{response}")

    if response.is_a?(Array)
      logs = response.filter_map do |document|
        next unless document['document'] && document['document']['fields']

        fields = document['document']['fields']
        log = {
          id: document['document']['name'].split('/').last,
          recipient: fields.dig('customerEmail', 'stringValue') || 'Unknown Recipient',
          subject: fields.dig('subject', 'stringValue') || 'No Subject',
          dateSent: fields.dig('timestamp', 'timestampValue') || 'Unknown Date'
        }
        Rails.logger.info("Parsed log: #{log}")
        log
      end

      if logs.any?
        Rails.logger.info("Logs found: #{logs.size}")
        render json: logs, status: :ok
      else
        Rails.logger.info("No email logs found for the provided company ID")
        render json: { message: 'No email logs found for the provided company ID' }, status: :ok
      end
    else
      Rails.logger.error("Unexpected response format: #{response}")
      render json: { error: 'Logs not found' }, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error("Error in LogSentEmailsController#index: #{e.message}")
    render json: { error: 'Internal Server Error' }, status: :internal_server_error
  end
end
