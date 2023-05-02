# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api, defaults: { format: :json } do
    resources :games, only: %i[index show]
  end
  mount GoodJob::Engine => 'good_job'
end
