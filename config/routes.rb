# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api, defaults: { format: :json } do
    get "/games/:id/image", to: "images#show", as: :permanent_image
    resources :games, only: %i[index show]
    resources :collections, only: %i[show create]
    resources :api_keys, path: 'api-keys', only: %i[show index create destroy]
  end
  mount GoodJob::Engine => 'good_job'
end
