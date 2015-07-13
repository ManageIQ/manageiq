class AddRetirementStateToVmsAndServices < ActiveRecord::Migration
  def change
    [:vms, :services].each do |klass|
      add_column klass, :retirement_state, :string
    end
  end
end
