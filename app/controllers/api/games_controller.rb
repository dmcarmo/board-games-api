# frozen_string_literal: true

class Api::GamesController < Api::BaseController
  def index
    @games = Game.all
    render json: @games
  end

  def show
    @game = Game.find(params[:id])
    render json: @game
  end
end
