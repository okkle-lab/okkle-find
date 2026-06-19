class AddSourceToPosts < ActiveRecord::Migration[7.1]
  def change
    add_column :posts, :source_name, :string
    add_column :posts, :source_url, :string
  end
end
