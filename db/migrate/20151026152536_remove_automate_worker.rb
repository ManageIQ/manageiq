class RemoveAutomateWorker < ActiveRecord::Migration
  class MiqWorker < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def change
    MiqWorker.destroy_all(:type => 'MiqAutomateWorker')
  end
end
