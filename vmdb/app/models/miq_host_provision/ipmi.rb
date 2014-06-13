module MiqHostProvision::Ipmi
  def ipmi_reboot(address, userid, password)
    require 'miq-ipmi'

    log_header = "MIQ(#{self.class.name}#ipmi_reboot)"
    # Force the host to restart (or just turn on if already off)
    $log.info("#{log_header} Connecting with address: [#{host.ipmi_address}], userid: [#{host.authentication_userid(:ipmi)}]...")
    ipmi = MiqIPMI.new(host.ipmi_address, *host.auth_user_pwd(:ipmi))
    ipmi_command = 'chassis bootdev pxe'
    $log.info("#{log_header} Invoking [#{ipmi_command}]")
    ipmi.run_command(ipmi_command)
    $log.info("#{log_header} Invoking [power_reset]")
    ipmi.power_reset
  end

end
