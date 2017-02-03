class AddManagerRefToAuthentications < ActiveRecord::Migration[5.0]
  def change
    add_column :authentications, :manager_ref, :string
  end
end
