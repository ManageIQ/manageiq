require 'rubygems'
require 'net/ssh'

#test SSH connection to vm
def check_ssh(ipaddress,)
  $evm.root['Phase'] = "check ssh"
  $evm.log(:info, "**************** #{$evm.root["Phase"]} ****************")
  $evm.log(:info, "Connecting to IPaddress - #{ipaddress}")
  begin
    Net::SSH.start(ipaddress, $evm.root['user'], :paranoid => false) do |ssh|
      $evm.log(:info, "successful ssh to #{ipaddress}")
    end
  rescue
    $evm.root['ae_result'] = "error"
    $evm.root['Message'] = "Cannot connect to #{ipaddress} via ssh"
  end
  $evm.log(:info, "#{$evm.root['Phase']} : #{$evm.root['ae_result']} : #{$evm.root['Message']}")
end

# check ssh to master
def check_ssh_to_master
  $evm.root['ae_result'] = "ok"
  $evm.root['masters'].each do |ip|
    check_ssh(ip)
  end
end

#TODO: probably check ssh access from master to nodes in the master deploy-book
#check ssh to slaves
$evm.root['Message'] = "verified successful ssh to all resources"
check_ssh_to_master
