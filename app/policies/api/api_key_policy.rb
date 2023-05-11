module Api
  class ApiKeyPolicy < BasePolicy
    def show?
      api_key.bearer.is_a?(User)
    end

    def create?
      true
    end
  end
end
