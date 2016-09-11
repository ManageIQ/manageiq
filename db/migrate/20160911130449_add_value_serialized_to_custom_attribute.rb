class AddValueSerializedToCustomAttribute < ActiveRecord::Migration[5.0]
  class CustomAttribute < ActiveRecord::Base
    serialize :serialized_value
  end

  def up
    add_column :custom_attributes, :serialized_value, :text

    say_with_time "Copying values to serialized_value" do
      CustomAttribute.all.each do |custom_attribute|
        custom_attribute.update!(:serialized_value => custom_attribute.value)
      end
    end
  end

  def down
    remove_column :custom_attributes, :serialized_value
  end
end
