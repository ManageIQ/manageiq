###################################
#
# EVM Automate Method: vm_dialog_name_prefix
#
# Notes: This is the default method to determine the dialog prefix name to use
#
###################################
begin
  @method = 'vm_dialog_name_prefix'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  platform  = $evm.root['platform']
  $evm.log("info", "#{@method} - Detected Platform:<#{platform}>")

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
  $evm.log("info", "#{@method} - Platform:<#{platform}> dialog_name_prefix:<#{dialog_name_prefix}>")

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
