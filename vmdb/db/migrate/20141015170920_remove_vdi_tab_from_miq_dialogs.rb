class RemoveVdiTabFromMiqDialogs < ActiveRecord::Migration
  class MiqDialog < ActiveRecord::Base
    serialize :content, Hash
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("Removing VDI tab from MiqDialog") do
      MiqDialog.where(:dialog_type => 'MiqProvisionWorkflow').each do |dialog|
        if dialog.content[:dialogs].present? && dialog.content[:dialogs].keys.include?(:vdi)
          dialog.content[:dialogs].delete(:vdi)
          dialog.content[:dialog_order].delete(:vdi)
          dialog.save
        end
      end
    end
  end
end
