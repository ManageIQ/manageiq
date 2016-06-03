if MiqDialog.find_by(:name => "miq_provision_redhat_dialogs_template")
  blueprint = MiqDialog.find_by(:name => "miq_provision_redhat_dialogs_template")
  miq_dialog_buttons = blueprint.content[:buttons].collect(&:to_s) * ","
  # dialog = Dialog.new(:buttons => miq_dialog_buttons, :label => (blueprint.name + " 0000".succ).humanize )
  dialog = Dialog.new(:buttons => miq_dialog_buttons, :label => (blueprint.name + " " + Time.now.to_i.to_s).humanize)
  dialog_tab = DialogTab.new(:label => "Basic Information")
  dialog_group = DialogGroup.new(:label => "Options")
  dialog_field = DialogField.new(:label => "sample field label", :name => "name of field")

  dialog.dialog_tabs << dialog_tab
  dialog_tab.dialog_groups << dialog_group
  dialog_group.dialog_fields << dialog_field
  dialog.save!
end
