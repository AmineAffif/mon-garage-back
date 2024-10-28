class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user, only: [:create, :update, :destroy]

  def index
    response = FirebaseRestClient.firestore_request('users')
    users = FirebaseRestClient.parse_firestore_documents(response)
    render json: users, status: :ok
  end

  def show
    response = FirebaseRestClient.firestore_request("users/#{params[:id]}")
    user = response && response["fields"] ? {
      id: params[:id],
      email: response["fields"]["email"]["stringValue"],
      role: response["fields"]["role"]["stringValue"],
      fullName: response["fields"]["fullName"]["stringValue"],
      phone: response["fields"]["phone"]["stringValue"]
    } : nil

    if user
      render json: user, status: :ok
    else
      render json: { error: "user not found" }, status: :not_found
    end
  end

  def create
    user_data = params.require(:user).permit(:userId, :email, :role, :fullName, :phone)
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
end
