#
# Description: Dynamically choose dialog based on Category:environment chosen in pre-dialog
#

# Set to true to dynamically choose dialog name based on environment tag
run_env_dialog = false

if run_env_dialog
  # Get incoming environment tags from pre-dialog
  dialog_input_vm_tags = $evm.root['dialog_input_vm_tags']

  # Use a regular expression to grab the environment from the incoming tag category
  # I.e. environment/dev for Category:environment Tag:dev
  regex = /(.*)(\/)(\w*)/i

  # If the regular express matches dynamically choose the next dialog
  if regex =~ dialog_input_vm_tags
    cat = Regexp.last_match[1]
    tag = Regexp.last_match[3]
    $evm.log("info", "Category: <#{cat}> Tag: <#{tag}>")
    dialog_name = 'miq_provision_dialogs-deploy-#{tag}'
  end
  ## Set dialog name in the root object to be picked up by dialogs
  $evm.root['dialog_name'] = dialog_name
  $evm.log("info", "Launching <#{dialog_name}>")
end
