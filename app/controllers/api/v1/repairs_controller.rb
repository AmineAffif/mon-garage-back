require 'rest-client'

class Api::V1::RepairsController < ApplicationController
  before_action :authenticate_user, only: [:create, :update, :destroy]

  def index
    response = FirebaseRestClient.firestore_request('repairs')
    repairs = FirebaseRestClient.parse_firestore_documents(response)
    render json: repairs, status: :ok
  end

  def show
    repair_id = params[:id]
    response = FirebaseRestClient.firestore_request("repairs/#{repair_id}")
    if response && response["fields"]
      repair = FirebaseRestClient.parse_firestore_document(response)
      render json: repair, status: :ok
    else
      render json: { error: "Repair not found" }, status: :not_found
    end
  end

  def create
    # Récupère les données du client et du véhicule
    customer_data = params[:repair][:customer]
    vehicle_data = params[:repair][:vehicle]

    # Si un nouveau client doit être créé
    if customer_data[:id].nil?
      # Crée le client sur Firestore
      customer_response = RestClient.post(
        'https://firestore.googleapis.com/v1/projects/mon-garage-1b850/databases/(default)/documents/customers',
        { fields: {
            name: { stringValue: customer_data[:name] },
            phone: { stringValue: customer_data[:phone] },
            email: { stringValue: customer_data[:email] }
          }
        }.to_json,
        { content_type: :json, accept: :json }
      )
      customer_result = JSON.parse(customer_response.body)
      customer_id = customer_result["name"].split("/").last
    else
      # Utilise l'ID du client existant
      customer_id = customer_data[:id]
    end

    # Si un nouveau véhicule doit être créé
    if vehicle_data[:id].nil?
      # Crée le véhicule sur Firestore
      vehicle_response = RestClient.post(
        'https://firestore.googleapis.com/v1/projects/mon-garage-1b850/databases/(default)/documents/vehicles',
        { fields: {
            make: { stringValue: vehicle_data[:make] },
            model: { stringValue: vehicle_data[:model] },
            year: { integerValue: vehicle_data[:year].to_s },
            licensePlate: { stringValue: vehicle_data[:licensePlate] },
            customerId: { stringValue: customer_id }
          }
        }.to_json,
        { content_type: :json, accept: :json }
      )
      vehicle_result = JSON.parse(vehicle_response.body)
      vehicle_id = vehicle_result["name"].split("/").last
    else
      # Utilise l'ID du véhicule existant
      vehicle_id = vehicle_data[:id]
    end

    # Prépare les données de la réparation
    repair_data = {
      fields: {
        description: { stringValue: params[:repair][:description] },
        date: { stringValue: params[:repair][:date] },
        status: { stringValue: params[:repair][:status] || "pending" },
        customer: {
          mapValue: {
            fields: { id: { stringValue: customer_id } }
          }
        },
        vehicle: {
          mapValue: {
            fields: {
              id: { stringValue: vehicle_id },
              make: { stringValue: vehicle_data[:make] },
              model: { stringValue: vehicle_data[:model] },
              year: { integerValue: vehicle_data[:year].to_s },
              licensePlate: { stringValue: vehicle_data[:licensePlate] }
            }
          }
        }
      }
    }

    # Affiche les données pour vérification
    puts "Data envoyée à Firebase : #{repair_data}"

    # Envoie les données de la réparation à Firestore
    response = RestClient.post(
      'https://firestore.googleapis.com/v1/projects/mon-garage-1b850/databases/(default)/documents/repairs',
      repair_data.to_json,
      { content_type: :json, accept: :json }
    )

    # Vérifie et affiche la réponse
    if response.code == 200
      puts "Création réussie : #{response.body}"
      render json: { status: "Repair created successfully" }, status: :created
    else
      puts "Erreur de création : #{response.body}"
      render json: { error: "Erreur lors de la création de la réparation" }, status: :unprocessable_entity
    end
  rescue RestClient::ExceptionWithResponse => e
    puts "Erreur lors de la requête : #{e.response}"
    render json: { error: "Erreur lors de la création de la réparation" }, status: :unprocessable_entity
  end
  
  

  
  def update
    repair_id = params[:id]
    repair_data = params.require(:repair).permit(:description, :date, :status)
    document = FirebaseRestClient.firestore_request("repairs/#{repair_id}", :patch, repair_data.to_h)
    if document
      render json: { status: "Repair updated", document_data: document }, status: :ok
    else
      render json: { error: "Error updating repair" }, status: :internal_server_error
    end
  end

  def destroy
    repair_id = params[:id]
    FirebaseRestClient.firestore_request("repairs/#{repair_id}", :delete)
    render json: { status: "Repair deleted successfully" }, status: :ok
  end

  private

  def transform_to_firestore_format(data)
    data.transform_values do |value|
      if value.is_a?(Hash)
        { mapValue: { fields: transform_to_firestore_format(value) } }
      elsif value.is_a?(String)
        { stringValue: value }
      elsif value.is_a?(Integer)
        { integerValue: value.to_s }
      else
        { stringValue: value.to_s }
      end
    end
  end
  
  
  
  
end
