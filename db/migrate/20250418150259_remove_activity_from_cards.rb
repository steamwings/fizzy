class RemoveActivityFromCards < ActiveRecord::Migration[8.1]
  def change
    remove_index :cards, :activity_score_order
    remove_column :cards, :activity_score_order
    remove_column :cards, :activity_score_at
    remove_column :cards, :activity_score
  end
end
