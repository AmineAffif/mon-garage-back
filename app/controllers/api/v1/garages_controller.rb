class Api::V1::GaragesController < ApplicationController
  before_action :authenticate_user, only: [:create, :update, :destroy]

  def index
    garages = FirebaseRestClient.get_documents(:garages)
    render json: garages, status: :ok
  end

  def show
    garage = FirebaseRestClient.get_document(:garages, params[:id])
    if garage
      render json: garage, status: :ok
    else
      render json: { error: "Garage not found" }, status: :not_found
    end
  end

  def create
    garage_data = params.require(:garage).permit(:name, :address, :phone, :email)
    document = FirebaseRestClient.add_document(:garages, garage_data.to_h)

    if document
      render json: { status: "Garage ajouté avec succès", document_data: document }, status: :created
    else
      render json: { error: "Erreur lors de l'ajout du garage" }, status: :internal_server_error
    end
  end

  def update
    garage_data = params.require(:garage).permit(:name, :address, :phone, :email)
    document = FirebaseRestClient.update_document(:garages, params[:id], garage_data.to_h)

    if document
      render json: { status: "Garage mis à jour avec succès", document_data: document }, status: :ok
    else
      render json: { error: "Erreur lors de la mise à jour du garage" }, status: :internal_server_error
    end
  end

  def destroy
    FirebaseRestClient.delete_document(:garages, params[:id])
    render json: { status: "Garage supprimé avec succès" }, status: :ok
  end
end
