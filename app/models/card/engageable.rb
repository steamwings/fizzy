module Card::Engageable
  extend ActiveSupport::Concern

  included do
    has_one :engagement, dependent: :destroy, class_name: "Card::Engagement"

    scope :considering, -> { published_or_drafted_by(Current.user).open.where.missing(:engagement) }
    scope :on_deck,     -> { published.open.joins(:engagement).where(card_engagements: { status: "on_deck" }) }
    scope :doing,       -> { published.open.joins(:engagement).where(card_engagements: { status: "doing" }) }

    scope :by_engagement_status, ->(status) do
      case status.to_s
      when "considering" then considering.with_golden_first
      when "on_deck"     then on_deck.with_golden_first
      when "doing"       then doing.with_golden_first
      end
    end
  end

  def doing?
    open? && published? && engagement&.status == "doing"
  end

  def on_deck?
    open? && published? && engagement&.status == "on_deck"
  end

  def considering?
    open? && published? && engagement.blank?
  end

  def engagement_status
    if doing?
      "doing"
    elsif on_deck?
      "on_deck"
    elsif considering?
      "considering"
    end
  end

  def engage
    unless doing?
      transaction do
        reopen
        create_engagement!(status: "doing")
      end
    end
  end

  def move_to_on_deck
    unless on_deck?
      transaction do
        reopen
        if engagement.present?
          engagement.update!(status: "on_deck")
        else
          create_engagement!(status: "on_deck")
        end
      end
    end
  end

  def reconsider
    transaction do
      reopen
      engagement&.destroy
      activity_spike&.destroy
      touch_last_active_at
    end
  end
end
