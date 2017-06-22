class SetVisibleToTrueForCustomAttributes < ActiveRecord::Migration[5.0]
  class CustomAttribute < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    CustomAttribute.update_all(:visible => true)
  end

  def down
    # NOP
  end
end
