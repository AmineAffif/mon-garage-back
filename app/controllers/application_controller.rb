class ApplicationController < ActionController::API
  private

  def authenticate_user
    token = request.headers['Authorization']&.split(' ')&.last
    return render json: { error: 'Unauthorized' }, status: :unauthorized unless token

    begin
      # Remplacez `FIREBASE_AUTH.verify_id_token(token)` par un appel à FirebaseRestClient
      decoded_token = FirebaseRestClient.verify_id_token(token)
      @current_user_uid = decoded_token["sub"] if decoded_token
    rescue => e
      render json: { error: e.message }, status: :unauthorized
    end
  end
end
