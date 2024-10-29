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

    firestore_data = {
      fields: {
        repairId: { stringValue: intervention_data[:repairId] },
        date: { stringValue: intervention_data[:date] },
        description: { stringValue: intervention_data[:description] }
      }
    }
  
    # Création de l'intervention dans Firestore
    document = FirebaseRestClient.firestore_request('interventions', :post, firestore_data)
  
    if document
      # Mise à jour du statut de la réparation associée à "in progress"
      repair_id = intervention_data[:repairId]
      update_repair_status(repair_id, 'in progress')

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
    # Préparation des données de mise à jour du statut
    repair_data = {
      fields: {
        status: { stringValue: new_status }
      }
    }
  
    # Mise à jour du document de réparation avec le nouveau statut
    FirebaseRestClient.firestore_request("repairs/#{repair_id}", :patch, repair_data)
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error("Erreur lors de la mise à jour du statut de la réparation : #{e.response}")
  end

end
