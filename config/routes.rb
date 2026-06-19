Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "search", to: "search#index"
  get "compare", to: "comparisons#show"
  get "methodology", to: "pages#methodology"
  get "learn", to: "pages#learn"
  get "learn/:slug", to: "pages#learn_topic", as: :learn_topic
  get "leaderboards", to: "leaderboards#index"
  get "leaderboards/:category", to: "leaderboards#show", as: :leaderboard
  resources :tools, only: :show do
    member { get :review }
  end
  resources :events, only: :create
  resources :posts, only: [:index, :show], path: "blog"

  namespace :admin do
    resources :posts, only: %i[index new create edit update]
    get "fetch_url",  to: "posts#fetch_url"
    post "fetch_news", to: "posts#fetch_news"
  end

  # Defines the root path route ("/")
  root "pages#home"
end
