# add column for hiding, populate it based on value in dialog -- display field
# id dropdowns with values: memory, cpus, etc, set them

blueprint = MiqDialog.find_by(:name => "miq_provision_vmware_dialogs_template")
if blueprint
  miq_dialog_buttons = blueprint.content[:buttons].collect(&:to_s) * ","
  if Dialog.exists?(:label => blueprint.name)
    dialog = Dialog.find_by(:label => "miq_provision_vmware_dialogs_template")
    dialog.dialog_tabs.each(&:delete)
  else
    dialog = Dialog.new(:buttons => miq_dialog_buttons, :label => blueprint.name)
  end

  blueprint.content[:dialogs].each do |f|
    dialog_tab = DialogTab.new(:label => (f[0]).to_s.humanize, :description => f[1][:description],
                               :display => f[1][:display])
    dialog_tab.position = blueprint.content[:dialog_order].index(f[0])
    dialog.dialog_tabs << dialog_tab
    dialog_group = DialogGroup.new(:label => "Options", :display => "edit")
    dialog_tab.dialog_groups << dialog_group

    f[1][:fields].each do |g|
      dialog_field = DialogField.new(:label => g[1][:description], :name => "name of field",
                                     :data_type => g[1][:data_type], :display => g[1][:display])
      dialog_group.dialog_fields << dialog_field
    end
  end
  dialog.save!
end
