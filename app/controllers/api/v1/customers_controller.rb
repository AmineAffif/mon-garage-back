class Api::V1::CustomersController < ApplicationController
  before_action :authenticate_user, only: [:create, :update, :destroy]

  def index
    response = FirebaseRestClient.firestore_request('customers')
    customers = FirebaseRestClient.parse_firestore_documents(response)
    render json: customers, status: :ok
  end

  def show
    response = FirebaseRestClient.firestore_request("customers/#{params[:id]}")
    customer = response && response["fields"] ? {
      id: params[:id],
      name: response["fields"]["name"]["stringValue"],
      phone: response["fields"]["phone"]["stringValue"],
      email: response["fields"]["email"]["stringValue"]
    } : nil

    if customer
      render json: customer, status: :ok
    else
      render json: { error: "customer not found" }, status: :not_found
    end
  end

  def create
    customer_data = params.require(:customer).permit(:name, :phone, :email)
    document = FirebaseRestClient.firestore_request('customers', :post, customer_data.to_h)
  
    if document
      render json: { status: "customer ajouté avec succès", document_data: document }, status: :created
    else
      render json: { error: "Erreur lors de l'ajout du customer" }, status: :internal_server_error
    end
  end  

  def update
    customer_data = params.require(:customer).permit(:name, :phone, :email)
    document = FirebaseRestClient.firestore_request("customers/#{params[:id]}", :patch, customer_data.to_h)

    if document
      render json: { status: "customer mis à jour avec succès", document_data: document }, status: :ok
    else
      render json: { error: "Erreur lors de la mise à jour du customer" }, status: :internal_server_error
    end
  end

  def destroy
    FirebaseRestClient.firestore_request("customers/#{params[:id]}", :delete)
    render json: { status: "customer supprimé avec succès" }, status: :ok
  end
end
