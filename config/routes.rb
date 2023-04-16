Rails.application.routes.draw do
  namespace :api, defaults: { format: :json } do
    resources :games, only: [ :index ]
  end
end
