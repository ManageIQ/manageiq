require 'rubygems'
require 'net/ssh'

#test SSH connection to vm
def checkSSH(ipaddress, user)
  $evm.root['Phase'] = "check ssh"
  $evm.log(:info, "**************** #{$evm.root["Phase"]} ****************")
  $evm.log(:info, "Connecting to IPaddress - #{ipaddress}")
  begin
    Net::SSH.start(ipaddress, user, :paranoid => false) do |ssh|
      $evm.root['ae_result'] = "ok"
      $evm.root['Message'] = "successful ssh to #{ipaddress}"
    end
  rescue
    $evm.root['ae_result'] = "error"
    $evm.root['Message'] = "Cannot connect to #{ipaddress} via ssh"
  end
  $evm.log(:info, "#{$evm.root['Phase']} : #{$evm.root['ae_result']} : #{$evm.root['Message']}")
end

checkSSH("104.155.115.140", "dkorn")