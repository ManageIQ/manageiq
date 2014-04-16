class CreateAuthenticationExtensions < ActiveRecord::Migration
  def change
    create_table :authentication_extensions do |t|
      # Named value_string to allow for the model to use "value" for polymorphic
      # value type (see AuthenticationExtensionType)
      t.text       :value_string
      t.belongs_to :authentication
      t.belongs_to :authentication_extension_type
    end
  end
end
