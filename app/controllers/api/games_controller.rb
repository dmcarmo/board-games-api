# frozen_string_literal: true

class Api::GamesController < Api::BaseController
  def index
    games = Game.all.includes(image_attachment: :blob).order(:bgg_id)
    games = filter_games(games, params[:filter])
    games = search_games(games, params)
    games = games.search_by_bgg_id(params[:bgg_id]) if params[:bgg_id].present?

    pagy, games = pagy(games, items: 50)

    pagy_headers_merge(pagy)

    unless params[:extended] == "true"
      games = games.map do |game|
        {
          id: game.id,
          name: game.name,
          bgg_id: game.bgg_id,
          year_published: game.year_published,
          image_url: game.image_url
        }
      end
    end

    render json: {
      games: games.as_json(methods: [:image_url]),
      pagination: pagy_metadata(pagy)
    }
  end

  def show
    game = Game.find(params[:id])
    render json: {
      id: game.id,
      name: game.name,
      bgg_id: game.bgg_id,
      base_game_id: game.base_game_id,
      year_published: game.year_published,
      min_players: game.min_players,
      max_players: game.max_players,
      best_at: game.best_at,
      recommended_at: game.recommended_at,
      min_playtime: game.min_playtime,
      max_playtime: game.max_playtime,
      min_age: game.min_age,
      alternative_names: game.alternative_names,
      language_dependence: game.language_dependence,
      image_url: url_for(game.image)
    }
  end

  private

  def filter_games(games, filter)
    case filter
    when "base_games" then games.base_games
    when "expansions" then games.expansions
    else games
    end
  end

  def search_games(games, params)
    if params[:name].present?
      if params[:exact] == "true"
        games.search_by_name_exact(params[:name])
      else
        games.search_by_name_partial(params[:name])
      end
    else
      games
    end
  end
end
