class Cards::EngagementsController < ApplicationController
  include CardScoped

  def create
    case params[:engagement]
    when "doing"
      @card.engage
    when "on_deck"
      @card.move_to_on_deck
    end
    render_card_replacement
  end

  def destroy
    @card.reconsider
    render_card_replacement
  end
end
