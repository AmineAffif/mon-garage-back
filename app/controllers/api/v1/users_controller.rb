class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user, only: [:update, :destroy]
  skip_before_action :authenticate_user, only: [:create, :login]

  def index
    response = FirebaseRestClient.firestore_request('users')
    users = FirebaseRestClient.parse_firestore_documents(response)

    if users.present?
      render json: users, status: :ok
    else
      render json: { error: "No users found" }, status: :not_found
    end
  end


  def index_customers
    company_id = params[:companyId]

    response = FirebaseRestClient.firestore_request(':runQuery', :post, {
      structuredQuery: {
        from: [{ collectionId: 'users' }],
        where: {
          compositeFilter: {
            op: 'AND',
            filters: [
              {
                fieldFilter: {
                  field: { fieldPath: 'role' },
                  op: 'EQUAL',
                  value: { stringValue: 'Customer' }
                }
              },
              {
                fieldFilter: {
                  field: { fieldPath: 'companyId' },
                  op: 'EQUAL',
                  value: { stringValue: company_id }
                }
              }
            ]
          }
        }
      }
    })

    if response.is_a?(Array)
      customers = response.map do |res|
        fields = res.dig('document', 'fields')
        {
          id: res.dig('document', 'name').split('/').last,
          fullName: fields.dig('fullName', 'stringValue'),
          email: fields.dig('email', 'stringValue'),
          phone: fields.dig('phone', 'stringValue'),
          companyId: fields.dig('companyId', 'stringValue')
        }
      end.compact

      render json: customers, status: :ok
    else
      render json: { error: 'No customers found' }, status: :not_found
    end
  end

  
  def index_professionals
    response = FirebaseRestClient.firestore_request('users')
    users = FirebaseRestClient.parse_firestore_documents(response)
    professional = users.select { |user| user[:role] == 'Professional' }
    render json: professional, status: :ok
  end

  def index_companies
    response = FirebaseRestClient.firestore_request(':runQuery', :post, {
      structuredQuery: {
        from: [{ collectionId: 'users' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'role' },
            op: 'EQUAL',
            value: { stringValue: 'Company' }
          }
        }
      }
    })

    if response.is_a?(Array)
      companies = response.map do |res|
        fields = res.dig('document', 'fields')

        # Vérifiez la présence des champs avant de les ajouter
        {
          id: res.dig('document', 'name').split('/').last,
          companyName: fields.dig('companyName', 'stringValue') || "",
          companyAddress: fields.dig('companyAddress', 'stringValue') || "",
          firebaseAuthUserId: fields.dig('firebaseAuthUserId', 'stringValue')
        }
      end.compact

      render json: companies, status: :ok
    else
      render json: { error: 'No companies found' }, status: :not_found
    end
  end


  def login
    email = params[:email]
    password = params[:password]

    # Logique de validation de l'utilisateur
    response = FirebaseRestClient.firestore_request(':runQuery', :post, {
      structuredQuery: {
        from: [{ collectionId: 'users' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'email' },
            op: 'EQUAL',
            value: { stringValue: email }
          }
        },
        limit: 1
      }
    })

    if response.is_a?(Array) && response.first['document']
      # Hypothèse : valider le mot de passe (ici c’est simplement un exemple)
      document = response.first['document']
      fields = document['fields']
      if password == "validPassword" # Remplacez par une vraie validation de mot de passe
        # Générer un token pour l'utilisateur
        token = SecureRandom.hex(16)
        render json: { token: token }, status: :ok
      else
        render json: { error: "Invalid email or password" }, status: :unauthorized
      end
    else
      render json: { error: "User not found" }, status: :not_found
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
      render json: { error: 'user not found' }, status: :not_found
    end
  end
  
    
  

  def create
    # Ajoutez :companyName, :companyPhone, :companyEmail, :companyAddress à la liste des paramètres autorisés
    user_data = params.require(:user).permit(:firebaseAuthUserId, :email, :role, :fullName, :phone, :companyName, :companyPhone, :companyEmail, :companyAddress, :companyId)

    # Formater les données de l'utilisateur pour Firestore
    firestore_payload = {
      fields: {
        firebaseAuthUserId: { stringValue: user_data[:firebaseAuthUserId] || SecureRandom.uuid },
        email: { stringValue: user_data[:email] },
        role: { stringValue: user_data[:role] },
        fullName: { stringValue: user_data[:fullName] },
        phone: { stringValue: user_data[:phone] }
      }
    }

    # Ajouter des champs pour l'entreprise si le rôle est "Company" et que les valeurs sont présentes
    if user_data[:role] == "Company"
      firestore_payload[:fields][:companyName] = { stringValue: user_data[:companyName].presence || "" }
      firestore_payload[:fields][:companyPhone] = { stringValue: user_data[:companyPhone].presence || "" }
      firestore_payload[:fields][:companyEmail] = { stringValue: user_data[:companyEmail].presence || "" }
      firestore_payload[:fields][:companyAddress] = { stringValue: user_data[:companyAddress].presence || "" }
    elsif user_data[:role] == "Professional" && user_data[:companyId].present?
      firestore_payload[:fields][:companyId] = { stringValue: user_data[:companyId] }
    elsif user_data[:role] == "Customer" && user_data[:companyId].present?
      firestore_payload[:fields][:companyId] = { stringValue: user_data[:companyId] }
    end

    # Envoi des données à Firestore
    document = FirebaseRestClient.firestore_request('users', :post, firestore_payload)

    if document
      render json: { status: "User ajouté avec succès", document_data: document }, status: :created
    else
      Rails.logger.error("Erreur lors de l'ajout du user : #{firestore_payload}")
      render json: { error: "Erreur lors de l'ajout du user. Vérifiez les logs pour plus de détails." }, status: :internal_server_error
    end
  end
  
  def update
    user_data = params.require(:user).permit(:email, :role, :fullName, :phone)
    document = FirebaseRestClient.firestore_request("users/#{params[:id]}", :patch, user_data.to_h)

    if document
      render json: { status: "User mis à jour avec succès", document_data: document }, status: :ok
    else
      render json: { error: "Erreur lors de la mise à jour du user" }, status: :internal_server_error
    end
  end

  def destroy
    FirebaseRestClient.firestore_request("users/#{params[:id]}", :delete)
    render json: { status: "User supprimé avec succès" }, status: :ok
  end

  def destroy_by_firebase_auth_user_id
    firebase_auth_user_id = params[:firebaseAuthUserId]

    # Requête structurée pour rechercher l'utilisateur par firebaseAuthUserId
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

    if response.is_a?(Array) && response.first['document']
      document = response.first['document']
      document_name = document['name']
      document_id = document_name.split('/').last

      # Suppression du document dans Firestore
      FirebaseRestClient.firestore_request("users/#{document_id}", :delete)
      render json: { status: "User supprimé avec succès" }, status: :ok
    else
      render json: { error: 'User not found' }, status: :not_found
    end
  end

  def by_company_id
    company_id = params[:companyId]

    response = FirebaseRestClient.firestore_request(':runQuery', :post, {
      structuredQuery: {
        from: [{ collectionId: 'users' }],
        where: {
          compositeFilter: {
            op: 'AND',
            filters: [
              {
                fieldFilter: {
                  field: { fieldPath: 'role' },
                  op: 'EQUAL',
                  value: { stringValue: 'Professional' }
                }
              },
              {
                fieldFilter: {
                  field: { fieldPath: 'companyId' },
                  op: 'EQUAL',
                  value: { stringValue: company_id }
                }
              }
            ]
          }
        }
      }
    })

    if response.is_a?(Array)
      professionals = response.map do |res|
        fields = res.dig('document', 'fields')
        {
          id: res.dig('document', 'name').split('/').last,
          fullName: fields.dig('fullName', 'stringValue'),
          email: fields.dig('email', 'stringValue'),
          phone: fields.dig('phone', 'stringValue'),
          companyId: fields.dig('companyId', 'stringValue')
        }
      end.compact

      render json: professionals, status: :ok
    else
      render json: { error: 'No professionals found' }, status: :not_found
    end
  end

  def create_pro_demand
    demand_data = params.require(:demand).permit(:email, :fullName, :phone, :companyId, :status)
    demand_data[:date] = DateFormatter.format(DateTime.now.to_s, :long)  # Ajouter la date de la demande
    demand_data[:status] = 'pending'

    firestore_payload = {
      fields: {
        email: { stringValue: demand_data[:email] },
        fullName: { stringValue: demand_data[:fullName] },
        phone: { stringValue: demand_data[:phone] },
        companyId: { stringValue: demand_data[:companyId] },
        date: { stringValue: demand_data[:date] },
        status: { stringValue: demand_data[:status] }
      }
    }

    document = FirebaseRestClient.firestore_request('pro_register_demand', :post, firestore_payload)

    if document
      render json: { status: "Register demand created successfully", document_data: document }, status: :created
    else
      render json: { error: "Error while creating register demand" }, status: :internal_server_error
    end
  end

  # Fetch all register demands for a company
  def fetch_register_demands
    company_id = params[:companyId]

    response = FirebaseRestClient.firestore_request(':runQuery', :post, {
      structuredQuery: {
        from: [{ collectionId: 'pro_register_demand' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'companyId' },
            op: 'EQUAL',
            value: { stringValue: company_id }
          }
        }
      }
    })

    if response.is_a?(Array) && response.any?
      demands = response.map do |res|
        next unless res['document']  # Skip if there is no document key
        fields = res.dig('document', 'fields')
        {
          id: res.dig('document', 'name')&.split('/')&.last,
          fullName: fields.dig('fullName', 'stringValue'),
          email: fields.dig('email', 'stringValue'),
          phone: fields.dig('phone', 'stringValue'),
          date: fields.dig('date', 'stringValue'),
          status: fields.dig('status', 'stringValue')
        }
      end.compact

      if demands.empty?
        render json: { message: 'No demands found' }, status: :ok
      else
        render json: demands, status: :ok
      end
    else
      render json: { message: 'No demands found' }, status: :ok
    end
  end


  def approve_register_demand
    demand_id = params[:id]
    decision = params[:decision]  # 'approve' or 'refuse'

    # Obtenir le document existant à partir de Firestore
    response = FirebaseRestClient.firestore_request("pro_register_demand/#{demand_id}")

    if response && response['fields']
      # Conserver toutes les données existantes du document
      existing_data = response['fields']

      # Mettre à jour uniquement le statut tout en conservant les autres données
      updated_data = existing_data.merge(
        status: { stringValue: decision == 'approve' ? 'approved' : 'refused' }
      )

      # Envoyer les données mises à jour à Firestore
      document = FirebaseRestClient.firestore_request("pro_register_demand/#{demand_id}", :patch, {
        fields: updated_data
      })

      if document && decision == 'approve'
        # Ajout de firebaseAuthUserId si possible
        firebase_auth_user_id = params[:firebaseAuthUserId] || SecureRandom.uuid
        existing_data['firebaseAuthUserId'] = { 'stringValue' => firebase_auth_user_id }

        # Si approuvé, créer le professionnel dans la collection 'users'
        create_professional(existing_data)
      end

      if document
        render json: { status: "Demand updated successfully", document_data: document }, status: :ok
      else
        render json: { error: "Error while updating demand" }, status: :internal_server_error
      end
    else
      render json: { error: 'Demand not found' }, status: :not_found
    end
  end

  private

  def create_professional(demand_data)
    # Vérifier que les champs nécessaires sont bien présents
    email = demand_data.dig('email', 'stringValue')
    full_name = demand_data.dig('fullName', 'stringValue')
    phone = demand_data.dig('phone', 'stringValue')
    company_id = demand_data.dig('companyId', 'stringValue')
    firebase_auth_user_id = demand_data.dig('firebaseAuthUserId', 'stringValue')

    if email && full_name && phone && company_id && firebase_auth_user_id
      firestore_payload = {
        fields: {
          firebaseAuthUserId: { stringValue: firebase_auth_user_id },
          email: { stringValue: email },
          fullName: { stringValue: full_name },
          phone: { stringValue: phone },
          role: { stringValue: "Professional" },
          companyId: { stringValue: company_id }
        }
      }

      document = FirebaseRestClient.firestore_request('users', :post, firestore_payload)

      if document
        Rails.logger.info "User created successfully: #{document}"
      else
        Rails.logger.error "Failed to create user"
      end
    else
      Rails.logger.error "Missing fields in demand data: #{demand_data.inspect}"
    end
  end




end
