class DropUrlFromProviders < ActiveRecord::Migration[5.0]
  def change
    remove_column :providers, :url, :string
  end
end
