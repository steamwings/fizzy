class Ai::Tool::ListCollections < Ai::Tool
  description <<-MD
    Lists all collections accessible by the current user.
    The response is paginated so you may need to iterate through multiple pages to get the full list.
    Responses are JSON objects that look like this:
    ```
    {
      "collections": [
        { "id": 3, "name": "Foo" },
        { "id": 4, "name": "Bar" }
      ],
      "pagination": {
        "next_page": "e3c2gh75e4..."
      }
    }
    ```
    Each collection object has the following fields:
    - id [Integer, not null]
    - name [String, not null]
  MD

  param :page,
    type: :string,
    desc: "Which page to return. Leave balnk to get the first page",
    required: false

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  def execute(**params)
    scope = user.collections

    page = GearedPagination::Recordset.new(
      scope,
      ordered_by: { name: :asc, id: :desc }
    ).page(params[:page])

    {
      collections: page.records.map do |collection|
        {
          id: collection.id,
          name: collection.name,
          url: collection_url(collection)
        }
      end,
      pagination: {
        next_page: page.next_param
      }
    }.to_json
  end
end
