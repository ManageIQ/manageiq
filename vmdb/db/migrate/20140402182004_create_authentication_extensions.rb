class CreateAuthenticationExtensions < ActiveRecord::Migration
  def change
    create_table :authentication_extensions do |t|
      # stores most commmon configuration values
      t.string     :value_string
      # stores only configuration values needing text length
      t.text       :value_text
      t.belongs_to :authentication
      t.belongs_to :authentication_extension_type
    end
  end
end
