class AddRetirementRequesterToVmsAndServices < ActiveRecord::Migration[4.2]
  def change
    add_column :vms, :retirement_requester, :string
    add_column :services, :retirement_requester, :string
  end
end
