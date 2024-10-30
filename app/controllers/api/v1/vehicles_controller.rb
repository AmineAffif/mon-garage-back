class Api::V1::VehiclesController < ApplicationController
  before_action :authenticate_user, only: [:create, :update, :destroy]

  def index
    response = FirebaseRestClient.firestore_request('vehicles')
    vehicles = FirebaseRestClient.parse_firestore_documents(response)
    render json: vehicles, status: :ok
  end

  def show
    response = FirebaseRestClient.firestore_request("vehicles/#{params[:id]}")
    vehicle = response && response["fields"] ? {
      id: params[:id],
      make: response["fields"]["make"]["stringValue"],
      model: response["fields"]["model"]["stringValue"],
      year: response["fields"]["year"]["integerValue"].to_i,
      licensePlate: response["fields"]["licensePlate"]["stringValue"],
      firebaseAuthUserId: response["fields"]["firebaseAuthUserId"]["integerValue"].to_i,
      customerName: response["fields"]["customerName"]["stringValue"]
    } : nil

    if vehicle
      render json: vehicle, status: :ok
    else
      render json: { error: "vehicle not found" }, status: :not_found
    end
  end

  def create
    vehicle_data = params.require(:vehicle).permit(:make, :model, :year, :licensePlate, :firebaseAuthUserId, :customerName)
    document = FirebaseRestClient.firestore_request('vehicles', :post, vehicle_data.to_h)
    
    if document
      render json: { status: "vehicle ajouté avec succès", document_data: document }, status: :created
    else
      render json: { error: "Erreur lors de l'ajout du vehicle" }, status: :internal_server_error
    end
  end  
  
  def update
    vehicle_data = params.require(:vehicle).permit(:make, :model, :year, :licensePlate, :firebaseAuthUserId, :customerName)
    document = FirebaseRestClient.firestore_request("vehicles/#{params[:id]}", :patch, vehicle_data.to_h)

    if document
      render json: { status: "vehicle mis à jour avec succès", document_data: document }, status: :ok
    else
      render json: { error: "Erreur lors de la mise à jour du vehicle" }, status: :internal_server_error
    end
  end

  def destroy
    FirebaseRestClient.firestore_request("vehicles/#{params[:id]}", :delete)
    render json: { status: "vehicle supprimé avec succès" }, status: :ok
  end

  def by_customer
    firebase_auth_user_id = params[:firebaseAuthUserId]
    response = FirebaseRestClient.firestore_request('vehicles')
    
    if response && response["documents"]
      vehicles = FirebaseRestClient.parse_firestore_documents(response)
      # Filtrer les véhicules qui ont le bon firebaseAuthUserId
      customer_vehicles = vehicles.select { |vehicle| vehicle[:firebaseAuthUserId] == firebase_auth_user_id }
      render json: customer_vehicles, status: :ok
    else
      render json: { error: "Erreur de récupération des véhicules" }, status: :not_found
    end
  end
  
  def by_repair
    repair_id = params[:repair_id]
    response = FirebaseRestClient.firestore_request('vehicles')
    
    if response && response["documents"]
      vehicles = FirebaseRestClient.parse_firestore_documents(response)
      # Filtrer les véhicules qui ont le bon repair_id
      repair_vehicles = vehicles.select { |vehicle| vehicle[:repair_id] == repair_id }
      render json: repair_vehicles, status: :ok
    else
      render json: { error: "Erreur de récupération des véhicules" }, status: :not_found
    end
  end
  
end
