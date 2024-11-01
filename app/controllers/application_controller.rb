class ApplicationController < ActionController::API
  before_action :set_cors_headers

  ALLOWED_ORIGINS = ['http://localhost:3001', 'mon-garage.vercel.app'].freeze

  private

  def set_cors_headers
    if ALLOWED_ORIGINS.include?(request.origin)
      response.set_header('Access-Control-Allow-Origin', request.origin)
      response.set_header('Access-Control-Allow-Credentials', 'true')
    end
  end

  def authenticate_user
    token = request.headers['Authorization']&.split(' ')&.last
    return render json: { error: 'Unauthorized' }, status: :unauthorized unless token

    begin
      decoded_token = FirebaseRestClient.verify_id_token(token)
      @current_user_uid = decoded_token["sub"] if decoded_token
    rescue => e
      render json: { error: e.message }, status: :unauthorized
    end
  end
end
