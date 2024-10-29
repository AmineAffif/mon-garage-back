require 'rest-client'

class Api::V1::RepairsController < ApplicationController
  before_action :authenticate_user, only: [:create, :update, :destroy]

  def index
    response = FirebaseRestClient.firestore_request('repairs')
    repairs = FirebaseRestClient.parse_firestore_documents(response)
    render json: repairs, status: :ok
  end
  
  def show_by_firebase_auth_user_id
    firebase_auth_user_id = params[:firebaseAuthUserId]
    
    # Requête structurée correcte pour filtrer les documents par firebaseAuthUserId
    response = FirebaseRestClient.firestore_request(':runQuery', :post, {
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
  
    # Vérifiez si la réponse est un tableau et contient un document
    if response.is_a?(Array) && response.first['document']
      document = response.first['document']
      fields = document['fields']
  
      # Créez un hash avec les informations nécessaires
      user = {
        id: document['name'].split('/').last,
        fullName: fields['fullName']['stringValue'],
        email: fields['email']['stringValue'],
        phone: fields['phone']['stringValue'],
        role: fields['role']['stringValue'],
        firebaseAuthUserId: fields['firebaseAuthUserId']['stringValue']
      }
  
      render json: user, status: :ok
    else
      render json: { error: 'User not found' }, status: :not_found
    end
  end

  def show
    repair_id = params[:id]
    response = FirebaseRestClient.firestore_request("repairs/#{repair_id}")
  
    Rails.logger.info("Response from Firestore (Repair): #{response.inspect}") # Log de vérification des réparations
  
    if response && response["fields"]
      # Récupère l'ID du client via vehicle
      customer_id = response.dig("fields", "customer", "mapValue", "fields", "id", "stringValue")
  
      if customer_id
        # Récupère les détails du client via son ID
        customer_response = FirebaseRestClient.firestore_request("users/#{customer_id}")
        Rails.logger.info("Response from Firestore (Customer): #{customer_response.inspect}") # Log de vérification du client
  
        customer_name = if customer_response && customer_response["fields"]
                          customer_response.dig("fields", "name", "stringValue")
                        else
                          "Unknown Customer"
                        end
      else
        customer_name = "Unknown Customer"
      end
  
      repair = {
        id: repair_id,
        vehicle: {
          make: response.dig("fields", "vehicle", "mapValue", "fields", "make", "stringValue"),
          model: response.dig("fields", "vehicle", "mapValue", "fields", "model", "stringValue"),
          year: response.dig("fields", "vehicle", "mapValue", "fields", "year", "integerValue"),
          licensePlate: response.dig("fields", "vehicle", "mapValue", "fields", "licensePlate", "stringValue"),
        },
        customer_name: customer_name,
        description: response.dig("fields", "description", "stringValue"),
        date: response.dig("fields", "date", "stringValue"),
        status: response.dig("fields", "status", "stringValue")
      }
  
      render json: repair, status: :ok
    else
      render json: { error: "Repair not found" }, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error("Erreur dans le contrôleur Repairs#show : #{e.message}")
    render json: { error: "Internal Server Error" }, status: :internal_server_error
  end

  def create
    # Récupère les données du client et du véhicule
    customer_data = params[:repair][:customer]
    vehicle_data = params[:repair][:vehicle]
  
    # Requête pour chercher le client en utilisant firebaseAuthUserId
    customer_response = FirebaseRestClient.firestore_request(':runQuery', :post, {
      structuredQuery: {
        from: [{ collectionId: 'users' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'firebaseAuthUserId' },
            op: 'EQUAL',
            value: { stringValue: customer_data[:firebaseAuthUserId] }
          }
        },
        limit: 1
      }
    })
  
    if customer_response.is_a?(Array) && customer_response.first['document']
      document = customer_response.first['document']
      firebase_auth_user_id = document.dig('fields', 'firebaseAuthUserId', 'stringValue')
    else
      render json: { error: 'Client non trouvé ou erreur lors de la récupération de firebaseAuthUserId' }, status: :not_found
      return
    end
  
    # Si un nouveau véhicule doit être créé
    vehicle_id = if vehicle_data[:id].nil?
                   # Crée le véhicule sur Firestore
                   vehicle_response = RestClient.post(
                     'https://firestore.googleapis.com/v1/projects/mon-garage-1b850/databases/(default)/documents/vehicles',
                     { fields: {
                         make: { stringValue: vehicle_data[:make] },
                         model: { stringValue: vehicle_data[:model] },
                         year: { integerValue: vehicle_data[:year].to_i },
                         licensePlate: { stringValue: vehicle_data[:licensePlate] },
                         customerId: { stringValue: firebase_auth_user_id }
                       }
                     }.to_json,
                     { content_type: :json, accept: :json }
                   )
                   vehicle_result = JSON.parse(vehicle_response.body)
                   vehicle_result["name"].split("/").last
                 else
                   # Utilise l'ID du véhicule existant
                   vehicle_data[:id]
                 end
  
    # Prépare les données de la réparation avec `firebaseAuthUserId` du client
    repair_data = {
      fields: {
        description: { stringValue: params[:repair][:description] || "No description provided" },
        date: { stringValue: params[:repair][:date] || Time.now.iso8601 },
        status: { stringValue: params[:repair][:status] || "pending" },
        customer: {
          mapValue: {
            fields: { firebaseAuthUserId: { stringValue: firebase_auth_user_id } }
          }
        },
        vehicle: {
          mapValue: {
            fields: {
              id: { stringValue: vehicle_id },
              make: { stringValue: vehicle_data[:make] },
              model: { stringValue: vehicle_data[:model] },
              year: { integerValue: vehicle_data[:year].to_i },
              licensePlate: { stringValue: vehicle_data[:licensePlate] }
            }
          }
        }
      }
    }
  
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
