class AddStatusToCardEngagements < ActiveRecord::Migration[8.1]
  def change
    add_column :card_engagements, :status, :string, default: "doing", null: false
    add_index :card_engagements, :status
  end
end
