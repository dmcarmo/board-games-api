class Api::GamesController < Api::BaseController
  def index
    @games = Game.all
    render json: @games
  end
end
