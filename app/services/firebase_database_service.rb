class FirebaseDatabaseService
  COLLECTIONS = {
    garages: "garages",
    employees: "employees",
    customers: "customers",
    vehicles: "vehicles",
    repairs: "repairs",
    interventions: "interventions",
    notifications: "notifications"
  }

  # Ajoute un document dans une collection
  def self.add_document(collection, data)
    path = COLLECTIONS[collection]
    return unless path

    formatted_data = data.transform_values { |v| { stringValue: v.to_s } }
    FirebaseRestcustomer.firestore_request(path, :post, { fields: formatted_data })
  end

  # Récupère tous les documents d'une collection
  def self.get_documents(collection)
    path = COLLECTIONS[collection]
    return unless path

    response = FirebaseRestcustomer.firestore_request(path)
    response["documents"].map do |doc|
      doc["fields"].transform_values { |v| v["stringValue"] }.merge("id" => doc["name"].split("/").last)
    end if response && response["documents"]
  end

  # Récupère un document spécifique par ID
  def self.get_document(collection, document_id)
    path = "#{COLLECTIONS[collection]}/#{document_id}"
    document = FirebaseRestcustomer.firestore_request(path)
    document ? document["fields"].transform_values { |v| v["stringValue"] }.merge("id" => document_id) : nil
  end

  # Met à jour un document existant
  def self.update_document(collection, document_id, data)
    path = "#{COLLECTIONS[collection]}/#{document_id}"
    formatted_data = data.transform_values { |v| { stringValue: v.to_s } }
    FirebaseRestcustomer.firestore_request(path, :patch, { fields: formatted_data })
  end

  # Supprime un document
  def self.delete_document(collection, document_id)
    path = "#{COLLECTIONS[collection]}/#{document_id}"
    FirebaseRestcustomer.firestore_request(path, :delete)
  end
end
