class Api::ImagesController < Api::BaseController
  skip_before_action :authenticate_with_api_key, only: [:show], raise: false

  def show
    skip_authorization

    game = Game.find(params[:id])

    if game.image.attached?
      if stale?(game.image.blob, public: true)
        file_path = ActiveStorage::Blob.service.path_for(game.image.blob.key)
        
        send_file file_path, 
                  type: game.image.content_type, 
                  disposition: "inline"
      end
    else
      render json: { error: "No image attached" }, status: :not_found
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Game not found" }, status: :not_found
  end
end
