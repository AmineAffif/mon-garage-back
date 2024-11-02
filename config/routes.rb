Rails.application.routes.draw do
  root to: redirect('/api/v1/users') # Redirection vers une ressource existante, par exemple les garages.
  
  namespace :api do
    namespace :v1 do
      get '/health_check', to: 'health#check'

      resources :garages, only: [:index, :show, :create, :update, :destroy]
      resources :employees, only: [:index, :show, :create, :update, :destroy]
      resources :clients, only: [:index, :show, :create, :update, :destroy]
      resources :vehicles, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get 'by_customer', to: 'vehicles#by_customer'
          get 'by_customer/:firebaseAuthUserId', to: 'vehicles#by_customer'
        end
      end

      resources :repairs, only: [:index, :show, :create, :update, :destroy] do
        patch 'update_status', on: :member
        get 'update_status', on: :member
        get 'index_by_firebase_auth_user_id/:firebaseAuthUserId', to: 'repairs#index_by_firebase_auth_user_id', on: :collection
        get 'index_by_company_id/:companyId', to: 'repairs#index_by_company_id', on: :collection
      end
      resources :interventions, only: [:index, :show, :create, :update, :destroy] do
        get 'by_repair/:repair_id', to: 'interventions#by_repair', on: :collection
      end
      resources :notifications, only: [:index, :show, :create, :update, :destroy]
      resources :customers, only: [:index, :show, :create, :update, :destroy] do
        get 'vehicles', to: 'vehicles#by_customer'
      end
      resources :users, only: [:index, :create, :update, :destroy] do
        collection do
          get 'by_firebase_auth_user_id/:firebaseAuthUserId', to: 'users#show_by_firebase_auth_user_id'
          delete 'by_firebase_auth_user_id/:firebaseAuthUserId', to: 'users#destroy_by_firebase_auth_user_id'
          get 'by_company_id/:companyId', to: 'users#by_company_id'
          get 'companies', to: 'users#index_companies'
          post 'create_pro_demand', to: 'users#create_pro_demand'
          get 'fetch_register_demands/:companyId', to: 'users#fetch_register_demands'
          patch 'approve_register_demand/:id', to: 'users#approve_register_demand'
        end
      end
      get 'customers', to: 'users#index_customers'
      get 'customers', to: 'users#index_professionals'
      resources :log_sent_emails, only: [:index]
    end
  end
end
