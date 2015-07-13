#
# Description: This method is used to perform post provisioning tasks
#

prov = $evm.root['miq_host_provision']

ks_cfg = prov.get_option_last(:customization_template_id)

# ESX Processing only
if ks_cfg.include?('ESXi')
  # Enabling VMOTION traffic on vm Kernel
  prov.host.enable_vmotion
  $evm.log("info", "Host: <#{prov.host.name}> Enabling VMOTION on vm Kernel")

  # Exit Maintenance Mode
  prov.host.exit_maintenance_mode
  $evm.log("info", "Host: <#{prov.host.name}> Exiting maintenance-mode")
end
