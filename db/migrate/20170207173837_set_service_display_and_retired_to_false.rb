class SetServiceDisplayAndRetiredToFalse < ActiveRecord::Migration[5.0]
  class Service < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    Service.where(:retired => nil).update_all(:retired => false)
    Service.where(:display => nil).update_all(:display => false)
  end

  def down
    # NOP
  end
end
