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
    user_data = params.require(:user).permit(:firebaseAuthUserId, :email, :role, :fullName, :phone) # Utiliser firebaseAuthUserId
    document = FirebaseRestClient.firestore_request('users', :post, user_data.to_h)
  
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
  
end
