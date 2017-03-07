class RemoveAncestryFromMiqAlertStatuses < ActiveRecord::Migration[5.0]
  def change
    # Undo changes done in:
    # https://github.com/ManageIQ/manageiq/pull/13233/files#diff-070aeac6617e5c4ff1c48ee3181c9913R1
    remove_index :network_ports, :column => :ancestry
    remove_column :miq_alert_statuses, :ancestry
  end
end
