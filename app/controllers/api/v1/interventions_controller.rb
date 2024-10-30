class Api::V1::InterventionsController < ApplicationController
  before_action :authenticate_user, only: [:create, :update, :destroy]

  def index
    response = FirebaseRestClient.firestore_request('interventions')
    interventions = FirebaseRestClient.parse_firestore_documents(response)
    render json: interventions, status: :ok
  end

  def show
    response = FirebaseRestClient.firestore_request("interventions/#{params[:id]}")
    intervention = FirebaseRestClient.parse_firestore_document(response)
    if intervention
      render json: intervention, status: :ok
    else
      render json: { error: "Intervention not found" }, status: :not_found
    end
  end

  def create
    intervention_data = params.require(:intervention).permit(:repairId, :date, :description)

    begin
      # Conversion de la date en objet DateTime
      parsed_date = DateTime.parse(intervention_data[:date])
    rescue ArgumentError => e
      render json: { error: "Invalid date format" }, status: :unprocessable_entity
      return
    end
  
    firestore_data = {
      fields: {
        repairId: { stringValue: intervention_data[:repairId] },
        date: { timestampValue: parsed_date.iso8601 }, # Firestore attend un format de type `timestamp`
        description: { stringValue: intervention_data[:description] }
      }
    }
  
    # Création de l'intervention dans Firestore
    document = FirebaseRestClient.firestore_request('interventions', :post, firestore_data)
  
    if document
      # Mise à jour du statut de la réparation associée à "in progress"
      repair_id = intervention_data[:repairId]
      update_repair_status(repair_id, 'in progress')
  
      # Récupération des informations de la réparation
      repair_response = FirebaseRestClient.firestore_request("repairs/#{repair_id}")
      if repair_response && repair_response["fields"]
        # Récupération de `firebaseAuthUserId` du client à partir de la réparation
        firebase_auth_user_id = repair_response.dig("fields", "customer", "mapValue", "fields", "firebaseAuthUserId", "stringValue")
  
        # Recherche du document utilisateur par `firebaseAuthUserId`
        customer_response = FirebaseRestClient.firestore_request(':runQuery', :post, {
          structuredQuery: {
            from: [{ collectionId: 'users' }],
            where: {
              fieldFilter: {
                field: { fieldPath: 'firebaseAuthUserId' },
                op: 'EQUAL',
                value: { stringValue: firebase_auth_user_id }
              }
            },
            limit: 1
          }
        })
  
        # Vérifiez si le client a été trouvé
        if customer_response.is_a?(Array) && customer_response.first['document']
          customer_document = customer_response.first['document']
          customer = {
            fullName: customer_document.dig('fields', 'fullName', 'stringValue'),
            email: customer_document.dig('fields', 'email', 'stringValue')
          }
  
          vehicle = {
            make: repair_response.dig("fields", "vehicle", "mapValue", "fields", "make", "stringValue"),
            model: repair_response.dig("fields", "vehicle", "mapValue", "fields", "model", "stringValue"),
            year: repair_response.dig("fields", "vehicle", "mapValue", "fields", "year", "integerValue")
          }
  
          # Envoi de l'email de notification pour l'intervention créée
          RepairMailer.intervention_created(customer, vehicle, intervention_data).deliver_now
        else
          Rails.logger.error("Client introuvable pour l'envoi de l'email d'intervention créée : #{firebase_auth_user_id}")
        end
      else
        Rails.logger.error("Réparation introuvable pour l'envoi de l'email d'intervention créée")
      end
  
      render json: { id: document['name'].split('/').last, **intervention_data }, status: :created
    else
      render json: { error: "Erreur lors de l'ajout de l'intervention" }, status: :internal_server_error
    end
  end

  def update
    intervention_data = params.require(:intervention).permit(:repairId, :date, :description)
    document = FirebaseRestClient.firestore_request("interventions/#{params[:id]}", :patch, intervention_data.to_h)

    if document
      render json: { status: "intervention mise à jour avec succès", document_data: document }, status: :ok
    else
      render json: { error: "Erreur lors de la mise à jour de l'intervention" }, status: :internal_server_error
    end
  end

  def destroy
    FirebaseRestClient.firestore_request("interventions/#{params[:id]}", :delete)
    render json: { status: "intervention supprimée avec succès" }, status: :ok
  end

  def by_repair
    repair_id = params[:repair_id]
    response = FirebaseRestClient.firestore_request('interventions')
    interventions = FirebaseRestClient.parse_firestore_documents(response)

    repair_interventions = interventions.select { |intervention| intervention[:repairId] == repair_id }
    render json: repair_interventions, status: :ok
  end

  private

  def update_repair_status(repair_id, new_status)
    # Utilisation de la mise à jour du champ spécifique `status`
    FirebaseRestClient.firestore_request(
      "repairs/#{repair_id}?updateMask.fieldPaths=status", # Spécifie que seul le champ `status` doit être mis à jour
      :patch,
      {
        fields: {
          status: { stringValue: new_status }
        }
      }
    )
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error("Erreur lors de la mise à jour du statut de la réparation : #{e.response}")
  end

end
