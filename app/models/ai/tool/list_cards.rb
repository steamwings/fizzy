class Ai::Tool::ListCards < Ai::Tool
  description <<-MD
    Lists all cards accessible by the current user.
    The response is paginated so you may need to iterate through multiple pages to get the full list.
    A next page exists if the `pagination.next_page` field is present in the response.
    Responses are JSON objects that look like this:
    ```
    {
      "cards": [
        { "id": 3 },
        { "id": 4 }
      ],
      "pagination": {
        "next_page": "e3c2gh75e4..."
      }
    }
    ```
    Each card object has the following fields:
    - id [Integer, not null]
    - title [String, not null] - The title of the card
    - status [String, not null] - Enum of "creating", "draft" and "published"
    - last_active_at [DateTime, not null] - The last time the card was updated
    - collection_id [Integer, not null] - The ID of the collection this card belongs to
    - stage [Object, not null] - The stage this card is in, with fields:
      - id [Integer, not null]
      - name [String, not null]
    - creator [Object, not null] - The user who created the card, with fields:
      - id [Integer, not null]
      - name [String, not null]
    - assignees [Array of Objects, not null] - The users assigned to the card, each with fields:
      - id [Integer, not null]
      - name [String, not null]
  MD

  param :ids,
    type: :string,
    desc: "If provided, will return only the cards with the given IDs (comma-separated)",
    required: false
  param :query,
    type: :string,
    desc: "If provided, will perform a semantinc search by embeddings and return only matching cards",
    required: false
  param :page,
    type: :string,
    desc: "Which page to return. Leave balnk to get the first page",
    required: false
  param :collection_id,
    type: :integer,
    desc: "If provided, will return only cards for the specified collection",
    required: false
  param :golden,
    type: :boolean,
    desc: "If provided, will return only golden cards",
    required: false
  param :created_at_gte,
    type: :string,
    desc: "If provided, will return only card created on or after after the given ISO timestamp",
    required: false
  param :created_at_lte,
    type: :string,
    desc: "If provided, will return only card created on or before the given ISO timestamp",
    required: false
  param :last_active_at_gte,
    type: :string,
    desc: "If provided, will return only card that were last active on or after after the given ISO timestamp",
    required: false
  param :last_active_at_lte,
    type: :string,
    desc: "If provided, will return only card that were last active on or before the given ISO timestamp",
    required: false

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  def execute(**params)
    cards = Card.where(collection: user.collections).includes(:stage, :creator, :assignees, :goldness)

    cards = cards.search(params[:query]) if params[:query].present?
    cards = cards.golden if params[:golden].present?
    cards = cards.where(collection_id: params[:collection_id]) if params[:collection_id].present?
    cards = cards.where(id: params[:ids]&.split(",")&.map(&:to_i)) if params[:ids].present?

    if params[:last_active_at_gte].present?
      timestamp = DateTime.parse(params[:last_active_at_gte])
      cards = cards.where(last_active_at: timestamp..)
    end

    if params[:last_active_at_lte].present?
      timestamp = DateTime.parse(params[:last_active_at_lte])
      cards = cards.where(last_active_at: ..timestamp)
    end

    if params[:created_at_gte].present?
      timestamp = DateTime.parse(params[:created_at_gte])
      cards = cards.where(created_at: timestamp..)
    end

    if params[:created_at_lte].present?
      timestamp = DateTime.parse(params[:created_at_lte])
      cards = cards.where(created_at: ..timestamp)
    end

    page = GearedPagination::Recordset.new(cards, ordered_by: { id: :desc }).page(params[:page])

    puts "="*80
    puts "Account: #{Account.sole.id}"
    puts "Tenant: #{ApplicationRecord.current_tenant}"
    puts "URL options: #{default_url_options.inspect}"
    puts "="*80

    {
      cards: page.records.map do |card|
        {
          id: card.id,
          title: card.title,
          status: card.status,
          last_active_at: card.last_active_at,
          collection_id: card.collection_id,
          golden: card.golden?,
          stage: card.stage.as_json(only: [ :id, :name ]),
          creator: card.creator.as_json(only: [ :id, :name ]),
          assignees: card.assignees.as_json(only: [ :id, :name ]),
          description: card.description.to_plain_text.truncate(1000),
          url: collection_card_url(card.collection, card)
        }
      end,
      pagination: {
        next_page: page.next_param
      }
    }.to_json
  end
end
