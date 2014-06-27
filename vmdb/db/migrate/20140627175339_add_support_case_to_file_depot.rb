class AddSupportCaseToFileDepot < ActiveRecord::Migration
  def change
    add_column :file_depots, :support_case, :string
  end
end
