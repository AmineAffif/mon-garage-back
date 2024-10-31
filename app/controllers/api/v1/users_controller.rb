class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user, only: [:create, :update, :destroy]

  def index
    response = FirebaseRestClient.firestore_request('users')
    users = FirebaseRestClient.parse_firestore_documents(response)
    render json: users, status: :ok
  end

  def index_customers
    response = FirebaseRestClient.firestore_request('users')
    users = FirebaseRestClient.parse_firestore_documents(response)
    customers = users.select { |user| user[:role] == 'Customer' }
    render json: customers, status: :ok
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
        {
          id: res.dig('document', 'name').split('/').last,
          companyName: fields.dig('companyName', 'stringValue'),
          companyAddress: fields.dig('companyAddress', 'stringValue'),
          firebaseAuthUserId: fields.dig('firebaseAuthUserId', 'stringValue')
        }
      end.compact

      render json: companies, status: :ok
    else
      render json: { error: 'No companies found' }, status: :not_found
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
    # Ajoutez :companyId à la liste des paramètres autorisés
    user_data = params.require(:user).permit(:firebaseAuthUserId, :email, :role, :fullName, :phone, :companyName, :companyPhone, :companyEmail, :companyAddress, :companyId)

    # Formater les données de l'utilisateur pour Firestore
    firestore_payload = {
      fields: {
        firebaseAuthUserId: { stringValue: user_data[:firebaseAuthUserId] },
        email: { stringValue: user_data[:email] },
        role: { stringValue: user_data[:role] },
        fullName: { stringValue: user_data[:fullName] },
        phone: { stringValue: user_data[:phone] },
      }
    }

    if user_data[:role] == "Company"
      firestore_payload[:fields].merge!(
        companyName: { stringValue: user_data[:companyName] },
        companyPhone: { stringValue: user_data[:companyPhone] },
        companyEmail: { stringValue: user_data[:companyEmail] },
        companyAddress: { stringValue: user_data[:companyAddress] }
      )
    elsif user_data[:role] == "Professional" && user_data[:companyId]
      firestore_payload[:fields].merge!(
        companyId: { stringValue: user_data[:companyId] }
      )
    end

    # Envoi des données à Firestore
    document = FirebaseRestClient.firestore_request('users', :post, firestore_payload)

    if document
      render json: { status: "User ajouté avec succès", document_data: document }, status: :created
    else
      render json: { error: "Erreur lors de l'ajout du user" }, status: :internal_server_error
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

end
