class Ai::Tool::ListUsers < Ai::Tool
  description <<-MD
    Lists all users accessible by the current user.
    The response is paginated so you may need to iterate through multiple pages to get the full list.
    Responses are JSON objects that look like this:
    ```
    {
      "users": [
        { "id": 3, "name": "John Doe" },
        { "id": 4, "name": "Johanna Doe" }
      ],
      "pagination": {
        "next_page": "e3c2gh75e4..."
      }
    }
    ```
    Each user object has the following fields:
    - id [Integer, not null]
    - name [String, not null]
    - role [String, not null]
    - url [String, not null]
  MD

  param :page,
    type: :string,
    desc: "Which page to return. Leave balnk to get the first page",
    required: false
  param :ids,
    type: :string,
    desc: "If provided, will return only the users with the given IDs (comma-separated)",
    required: false

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  def execute(**params)
    scope = User.all

    scope = scope.where(id: params[:ids].split(",").map(&:to_i)) if params[:ids].present?

    page = GearedPagination::Recordset.new(
      scope,
      ordered_by: { name: :asc, id: :desc }
    ).page(params[:page])

    {
      users: page.records.map do |user|
        {
          id: user.id,
          name: user.name,
          role: user.role,
          url: user_url(user)
        }
      end,
      pagination: {
        next_page: page.next_param
      }
    }.to_json
  end
end
