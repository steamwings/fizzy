require "test_helper"

class Cards::EngagementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:text)

    assert_changes -> { card.reload.doing? }, from: false, to: true do
      post card_engagement_path(card), params: { engagement: "doing" }
      assert_card_container_rerendered(card)
    end
  end

  test "create on_deck" do
    card = cards(:text)

    assert_changes -> { card.reload.on_deck? }, from: false, to: true do
      post card_engagement_path(card), params: { engagement: "on_deck" }
      assert_card_container_rerendered(card)
    end
  end

  test "destroy" do
    card = cards(:logo)

    assert_changes -> { card.reload.doing? }, from: true, to: false do
      delete card_engagement_path(card)
      assert_card_container_rerendered(card)
    end
  end

  private
    def assert_card_container_rerendered(card)
      assert_turbo_stream action: :replace, target: dom_id(card, :card_container)
    end
end
