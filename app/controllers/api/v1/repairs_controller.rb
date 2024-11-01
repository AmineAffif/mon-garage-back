require 'rest-client'

class Api::V1::RepairsController < ApplicationController
  before_action :authenticate_user, only: [:create, :update, :destroy]

  def index
    response = FirebaseRestClient.firestore_request('repairs')
    repairs = FirebaseRestClient.parse_firestore_documents(response)
    render json: repairs, status: :ok
  end

  require 'google/cloud/firestore'
  
  def index_by_company_id
    company_id = params[:companyId]

    # Requête structurée correcte pour filtrer les documents par companyId
    response = FirebaseRestClient.firestore_request(':runQuery', :post, {
      structuredQuery: {
        from: [{ collectionId: 'repairs' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'companyId' },
            op: 'EQUAL',
            value: { stringValue: company_id }
          }
        }
      }
    })

    # Vérifiez si la réponse est un tableau et contient des documents
    if response.is_a?(Array)
      repairs = response.filter_map do |document|
        next unless document['document'] && document['document']['fields']

        fields = document['document']['fields']
        firebase_auth_user_id = fields.dig('customer', 'mapValue', 'fields', 'firebaseAuthUserId', 'stringValue')

        # Requête pour obtenir le fullName du customer
        customer_full_name = "Unknown Customer"
        if firebase_auth_user_id
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

          if customer_response.is_a?(Array) && customer_response.first['document']
            customer_document = customer_response.first['document']
            customer_full_name = customer_document.dig('fields', 'fullName', 'stringValue') || "Unknown Customer"
          end
        end

        {
          id: document['document']['name'].split('/').last,
          description: fields['description']['stringValue'],
          date: fields['date']['stringValue'],
          status: fields['status']['stringValue'],
          customer: {
            fullName: customer_full_name
          },
          vehicle: {
            make: fields.dig('vehicle', 'mapValue', 'fields', 'make', 'stringValue'),
            model: fields.dig('vehicle', 'mapValue', 'fields', 'model', 'stringValue'),
            year: fields.dig('vehicle', 'mapValue', 'fields', 'year', 'integerValue'),
            licensePlate: fields.dig('vehicle', 'mapValue', 'fields', 'licensePlate', 'stringValue')
          }
        }
      end

      render json: repairs, status: :ok
    else
      render json: { error: 'Réparations non trouvées' }, status: :not_found
    end
  end



  def index_by_firebase_auth_user_id
    firebase_auth_user_id = params[:firebaseAuthUserId]
    
    # Requête structurée correcte pour filtrer les documents par firebaseAuthUserId
    response = FirebaseRestClient.firestore_request(':runQuery', :post, {
      structuredQuery: {
        from: [{ collectionId: 'repairs' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'customer.firebaseAuthUserId' },
            op: 'EQUAL',
            value: { stringValue: firebase_auth_user_id }
          }
        }
      }
    })
  
    # Vérifiez si la réponse est un tableau et contient des documents
    if response.is_a?(Array)
      # Si la réponse contient des réparations, formate la réponse ainsi :
      repairs = response.map do |document|
        fields = document['document']['fields']
        {
          id: document['document']['name'].split('/').last,
          description: fields['description']['stringValue'],
          date: fields['date']['stringValue'],
          status: fields['status']['stringValue'],
          vehicle: {
            make: fields.dig('vehicle', 'mapValue', 'fields', 'make', 'stringValue'),
            model: fields.dig('vehicle', 'mapValue', 'fields', 'model', 'stringValue'),
            year: fields.dig('vehicle', 'mapValue', 'fields', 'year', 'integerValue'),
            licensePlate: fields.dig('vehicle', 'mapValue', 'fields', 'licensePlate', 'stringValue')
          }
        }
      end

      render json: repairs, status: :ok
    else
      render json: { error: 'Réparations non trouvées' }, status: :not_found
    end
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

  # app/controllers/api/v1/repairs_controller.rb
  def show
    repair_id = params[:id]
    response = FirebaseRestClient.firestore_request("repairs/#{repair_id}")

    Rails.logger.info("Response from Firestore (Repair): #{response.inspect}") # Log de vérification des réparations

    if response && response["fields"]
      # Récupère `firebaseAuthUserId` à partir de la réparation
      firebase_auth_user_id = response.dig("fields", "customer", "mapValue", "fields", "firebaseAuthUserId", "stringValue")

      if firebase_auth_user_id
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
        customer_name = if customer_response.is_a?(Array) && customer_response.first['document']
                          customer_document = customer_response.first['document']
                          customer_document.dig('fields', 'fullName', 'stringValue')
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
    # Récupère les données du client, du véhicule, et de la société
    customer_data = params[:repair][:customer]
    vehicle_data = params[:repair][:vehicle]
    company_id = params[:repair][:companyId] # Récupère companyId du client connecté

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
                        make: { stringValue: vehicle_data[:make] || "Unknown" },
                        model: { stringValue: vehicle_data[:model] || "Unknown" },
                        year: { integerValue: vehicle_data[:year].to_i },
                        licensePlate: { stringValue: vehicle_data[:licensePlate] || "Unknown" },
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

    # Prépare les données de la réparation avec `firebaseAuthUserId` du client et `companyId`
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
              make: { stringValue: vehicle_data[:make] || "Unknown" },
              model: { stringValue: vehicle_data[:model] || "Unknown" },
              year: { integerValue: vehicle_data[:year].to_i },
              licensePlate: { stringValue: vehicle_data[:licensePlate] || "Unknown" }
            }
          }
        },
        companyId: { stringValue: company_id || "Unknown" } # Vérifiez que companyId est bien présent
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

      # Envoi de l'email de notification au client
      customer = {
        fullName: document.dig('fields', 'fullName', 'stringValue'),
        email: document.dig('fields', 'email', 'stringValue')
      }
      vehicle = {
        make: vehicle_data[:make],
        model: vehicle_data[:model],
        year: vehicle_data[:year]
      }
      repair = {
        description: params[:repair][:description]
      }
      RepairMailer.repair_created(customer, vehicle, repair).deliver_now

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

  # app/controllers/api/v1/repairs_controller.rb
def update_status
  repair_id = params[:id]
  new_status = params.require(:status)

  begin
    # Mise à jour du statut de la réparation dans Firestore
    FirebaseRestClient.firestore_request(
      "repairs/#{repair_id}?updateMask.fieldPaths=status",
      :patch,
      {
        fields: {
          status: { stringValue: new_status }
        }
      }
    )

    # Si le statut est 'completed', envoyez un email au client
    if new_status == 'completed'
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
          document = customer_response.first['document']
          customer = {
            fullName: document.dig('fields', 'fullName', 'stringValue'),
            email: document.dig('fields', 'email', 'stringValue')
          }
          vehicle = {
            make: repair_response.dig("fields", "vehicle", "mapValue", "fields", "make", "stringValue"),
            model: repair_response.dig("fields", "vehicle", "mapValue", "fields", "model", "stringValue"),
            year: repair_response.dig("fields", "vehicle", "mapValue", "fields", "year", "integerValue")
          }

          # Envoi de l'email de notification
          RepairMailer.repair_completed(customer, vehicle).deliver_now
        else
          Rails.logger.error("Client introuvable pour l'envoi de l'email de réparation terminée : #{firebase_auth_user_id}")
        end
      else
        Rails.logger.error("Réparation introuvable pour l'envoi de l'email de réparation terminée")
      end
    end

    render json: { status: "Repair status updated successfully" }, status: :ok
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error("Erreur lors de la mise à jour du statut de la réparation : #{e.response}")
    render json: { error: "Erreur lors de la mise à jour du statut de la réparation" }, status: :internal_server_error
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
