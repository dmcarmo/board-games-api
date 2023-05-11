module Api
  class GamePolicy < BasePolicy
    def show?
      api_key.bearer.is_a?(User)
    end
  end
end
