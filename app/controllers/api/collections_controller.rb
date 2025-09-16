class Api::CollectionsController < Api::BaseController
  def show
    collection = Collection.find_by(bgg_username: params[:id])

    if collection.nil?
      BggCreateCollectionJob.perform_later(params[:id])
      render json: { error: "Collection not found, try again later." }, status: :not_found
    elsif collection.collection_games.empty?
      render json: {
        id: collection.id,
        bgg_username: collection.bgg_username,
        status: collection.status,
        games: []
      }
    else
      pagy, collection_games = pagy(
        collection.collection_games.includes(:game).order("games.bgg_id"),
        items: 50
      )
      pagy_headers_merge(pagy)
      puts
      render json: {
        id: collection.id,
        bgg_username: collection.bgg_username,
        status: collection.status,
        updated_at: collection.updated_at,
        games: collection_games.map do |collection_game|
          {
            id: collection_game.game.id,
            name: collection_game.game.name,
            bgg_id: collection_game.game.bgg_id,
            base_game_id: collection_game.game.base_game_id,
            year_published: collection_game.game.year_published,
            min_players: collection_game.game.min_players,
            max_players: collection_game.game.max_players,
            best_at: collection_game.game.best_at,
            recommended_at: collection_game.game.recommended_at,
            min_playtime: collection_game.game.min_playtime,
            max_playtime: collection_game.game.max_playtime,
            min_age: collection_game.game.min_age,
            alternative_names: collection_game.game.alternative_names,
            language_dependence: collection_game.game.language_dependence,
            image_url: url_for(collection_game.game.image)
          }
        end,
        pagination: pagy_metadata(pagy)
      }
    end
  end

  def create
    if params[:username]
      BggCollectionImportJob.perform_later(params[:username])
      render json: { status: "Import in progress." }
    else
      render json: { error: "Bad Request", message: "Missing required key: username" }, status: :bad_request
    end
  end
end
