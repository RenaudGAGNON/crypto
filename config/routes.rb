Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "articles#index"

  # Routes protégées par authentification
  authenticate :user do
    resources :trading_configs do
      member do
        post :start_trading
        post :stop_trading
      end
    end

    resources :trades, only: [ :index, :show ]

    # Opportunités de croissance
    resources :growth_opportunities, only: [ :index ] do
      collection do
        post :refresh
      end
    end

    resources :trading_recommendations, only: [ :index ] do
      collection do
        post :refresh
      end
    end

    # Interface Sidekiq
    require "sidekiq/web"
    mount Sidekiq::Web => "/sidekiq"
  end

  resources :market_movers, only: [ :index ] do
    collection do
      post :refresh
    end
  end

  resources :trading_orders, only: [ :index, :show ] do
    collection do
      get :refresh
    end
  end

  resources :voucher_orders

  # Route racine
  root "trading_configs#index"
end
