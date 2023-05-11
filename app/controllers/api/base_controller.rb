# frozen_string_literal: true

module Api
  class BaseController < ApplicationController
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include ActionController::HttpAuthentication::Token::ControllerMethods
    include Pundit::Authorization

    rescue_from Pundit::NotAuthorizedError, with: :not_authorized

    before_action :authenticate_with_api_key, except: :create

    attr_reader :current_bearer, :current_api_key

    def pundit_user
      current_api_key
    end

    protected

    def not_authorized
      render status: :unauthorized, json: {
        errors: ["You are not authorized to perform this action"]
      }
    end

    def authenticate_with_api_key
      authenticate_or_request_with_http_token do |token, options|
        @current_api_key = ApiKey.where(revoked_at: nil).find_by_token(token)
        @current_bearer = current_api_key&.bearer
      end
    end

    # Override rails default 401 response to return JSON content-type
    # with request for Bearer token
    # https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Token/ControllerMethods.html
    def request_http_token_authentication(realm = "Application", message = nil)
      json_response = { errors: [message || "Access denied"] }
      headers["WWW-Authenticate"] = %(Bearer realm="#{realm.tr('"', "")}")
      render json: json_response, status: :unauthorized
    end
  end
end
