module MiqHostProvision::Ipmi
  def ipmi_reboot(address, userid, password)
    require 'miq-ipmi'

    # Force the host to restart (or just turn on if already off)
    _log.info("Connecting with address: [#{host.ipmi_address}], userid: [#{host.authentication_userid(:ipmi)}]...")
    ipmi = MiqIPMI.new(host.ipmi_address, *host.auth_user_pwd(:ipmi))
    ipmi_command = 'chassis bootdev pxe'
    _log.info("Invoking [#{ipmi_command}]")
    ipmi.run_command(ipmi_command)
    _log.info("Invoking [power_reset]")
    ipmi.power_reset
  end

end
