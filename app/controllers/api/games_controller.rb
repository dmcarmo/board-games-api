# frozen_string_literal: true

class Api::GamesController < Api::BaseController
  after_action { pagy_headers_merge(@pagy) if @pagy }

  def index
    @pagy, @games = if params[:search].present?
                      pagy(Game.search_by_name(params[:search]))
                    else
                      pagy(Game.all)
                    end
    
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
