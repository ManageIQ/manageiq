class AddSupportCaseToFileDepot < ActiveRecord::Migration[4.2]
  def change
    add_column :file_depots, :support_case, :string
  end
end
