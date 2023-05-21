# frozen_string_literal: true

class Api::GamesController < Api::BaseController
  def index
    @games = Game.all
    render json: @games
  end

  def show
    @game = Game.find(params[:id])
    render json: {
      id: @game.id,
      name: @game.name,
      bgg_id: @game.bgg_id,
      year_published: @game.year_published,
      min_players: @game.min_players,
      max_players: @game.max_players,
      language_dependence: @game.language_dependence,
      image_url: url_for(@game.image)
    }
  end
end
