class AddRetirementRequesterToVmsAndServices < ActiveRecord::Migration
  def change
    [:vms, :services].each do |klass|
      add_column klass, :retirement_requester, :string
    end
  end
end
