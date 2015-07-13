class AddRetirementRequesterToVmsAndServices < ActiveRecord::Migration
  def change
    add_column :vms, :retirement_requester, :string
    add_column :services, :retirement_requester, :string
  end
end
