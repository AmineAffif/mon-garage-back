require "googleauth"
require "net/http"
require "uri"
require "json"

class FirebaseRestClient
  SCOPE = "https://www.googleapis.com/auth/datastore"

  def self.get_access_token
    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(Rails.root.join("config/firebase_key.json")),
      scope: SCOPE
    )
    authorizer.fetch_access_token!
    authorizer.access_token
  end

  def self.verify_id_token(token)
    uri = URI("https://www.googleapis.com/oauth2/v1/tokeninfo?id_token=#{token}")
    response = Net::HTTP.get(uri)
    JSON.parse(response) if response
  rescue StandardError => e
    Rails.logger.error("Erreur lors de la vérification du jeton ID : #{e.message}")
    nil
  end

  # Méthode générique pour extraire les documents Firestore en fonction de la structure dynamique
  def self.parse_firestore_documents(response)
    return [] unless response && response["documents"]

    response["documents"].map do |doc|
      fields = doc["fields"]
      parsed_data = { id: doc["name"].split("/").last }
      
      fields.each do |field_name, field_value|
        value_type = field_value.keys.first # Ex: "stringValue", "integerValue"
        parsed_data[field_name.to_sym] = field_value[value_type]
      end

      parsed_data
    end
  end

  # Méthode pour créer la structure JSON du document en fonction des champs du modèle
  def self.build_firestore_document(fields)
    firestore_fields = {}
    fields.each do |key, value|
      firestore_fields[key.to_s] = { infer_firestore_type(value) => value }
    end
    { fields: firestore_fields }
  end

  # Inference du type de valeur pour le document JSON Firestore
  def self.infer_firestore_type(value)
    case value
    when String
      "stringValue"
    when Integer
      "integerValue"
    when Float
      "doubleValue"
    when TrueClass, FalseClass
      "booleanValue"
    else
      "stringValue" # Par défaut pour d'autres types
    end
  end

  # Méthode générique Firestore pour tous les modèles
  def self.firestore_request(path, method = :get, body = nil)
    project_id = "mon-garage-1b850"
    uri = URI("https://firestore.googleapis.com/v1/projects/#{project_id}/databases/(default)/documents/#{path}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = case method
              when :post
                Net::HTTP::Post.new(uri.request_uri)
              when :patch
                Net::HTTP::Patch.new(uri.request_uri)
              when :delete
                Net::HTTP::Delete.new(uri.request_uri)
              else
                Net::HTTP::Get.new(uri.request_uri)
              end

    request["Authorization"] = "Bearer #{get_access_token}"
    request["Content-Type"] = "application/json"

    # Ajout du corps JSON pour les méthodes POST et PATCH
    request.body = build_firestore_document(body).to_json if body

    response = http.request(request)

    Rails.logger.info("Firebase REST Request: #{method.upcase} #{uri}")
    Rails.logger.info("Request Body: #{request.body}") if request.body
    Rails.logger.info("Response Code: #{response.code}")
    Rails.logger.info("Response Body: #{response.body}")

    JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
  rescue StandardError => e
    Rails.logger.error("Erreur dans la requête Firestore REST : #{e.message}")
    nil
  end
end
