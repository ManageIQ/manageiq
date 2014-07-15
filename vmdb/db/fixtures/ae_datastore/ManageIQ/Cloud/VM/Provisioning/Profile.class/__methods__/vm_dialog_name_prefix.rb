#
# Description: This is the default method to determine the dialog prefix name to use
#

platform  = $evm.root['platform']
$evm.log("info", "Detected Platform:<#{platform}>")

if platform.nil?
  source_id = $evm.root['dialog_input_src_vm_id']
  source    = $evm.vmdb('vm_or_template', source_id) unless source_id.nil?
  if source
    platform = source.model_suffix.downcase
  else
    platform = "vmware"
  end
end

dialog_name_prefix = "miq_provision_#{platform}_dialogs"
dialog_name_prefix = "miq_provision_dialogs" if platform == "vmware"  # For Backward Compatibility

$evm.object['dialog_name_prefix'] = dialog_name_prefix
$evm.log("info", "Platform:<#{platform}> dialog_name_prefix:<#{dialog_name_prefix}>")
