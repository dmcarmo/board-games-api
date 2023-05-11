module Api
  class ApiKeysController < BaseController
    def index
      render json: current_bearer.api_keys
    end

    def show
      render json: {
        id: current_api_key.id,
        bearer_type: current_api_key.bearer_type,
        revoked_at: current_api_key.revoked_at
      }
    end

    def create
      authenticate_with_http_basic do |email, password|
        user = User.find_by email: email

        if user&.authenticate(password)
          api_key = ApiKey.create(bearer: user)

          render json: {
            id: api_key.id,
            bearer_type: api_key.bearer_type,
            bearer_token: api_key.raw_token
          }, status: :created and return
        end
      end

      render status: :unauthorized
    end

    def destroy
      current_api_key.revoked_at = Time.now
      current_api_key.save
      render json: {
        id: current_api_key.id,
        bearer_type: current_api_key.bearer_type,
        revoked_at: current_api_key.revoked_at
      }
    end
  end
end
