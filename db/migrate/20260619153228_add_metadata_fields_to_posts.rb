class AddMetadataFieldsToPosts < ActiveRecord::Migration[7.1]
  def change
    add_column :posts, :post_type, :string, default: "general", null: false
    add_column :posts, :verdict, :string
    add_column :posts, :image_url, :string
  end
end
