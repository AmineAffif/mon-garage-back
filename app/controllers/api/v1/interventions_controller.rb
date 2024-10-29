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
  
    document = FirebaseRestClient.firestore_request('interventions', :post, firestore_data)
  
    if document
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

end
