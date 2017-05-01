class DeleteMiqReplicationWorker < ActiveRecord::Migration[5.0]
  class MiqWorker < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    MiqWorker.where(:type => "MiqReplicationWorker").destroy_all
  end
end
