Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :garages, only: [:index, :show, :create, :update, :destroy]
      resources :employees, only: [:index, :show, :create, :update, :destroy]
      resources :clients, only: [:index, :show, :create, :update, :destroy]
      resources :vehicles, only: [:index, :show, :create, :update, :destroy]
      resources :repairs, only: [:index, :show, :create, :update, :destroy]
      resources :interventions, only: [:index, :show, :create, :update, :destroy] do
        get 'by_repair/:repair_id', to: 'interventions#by_repair', on: :collection
      end
      resources :notifications, only: [:index, :show, :create, :update, :destroy]
      resources :customers, only: [:index, :show, :create, :update, :destroy] do
        get 'vehicles', to: 'vehicles#by_customer'
      end
    end
  end
end
