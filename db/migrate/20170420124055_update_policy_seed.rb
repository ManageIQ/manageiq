class UpdatePolicySeed < ActiveRecord::Migration[5.0]
  class MiqPolicy < ActiveRecord::Base; end

  def up
    defaults = { :towhat => 'Vm', :active => true, :mode => 'control' }
    defaults.each { |col, val| MiqPolicy.where(col => nil).update_all(col => val) }
  end

  def down
    # these values should not be nil
    # no need to rollback
  end
end
