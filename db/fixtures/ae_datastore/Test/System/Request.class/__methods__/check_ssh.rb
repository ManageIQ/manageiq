require 'rubygems'
require 'net/ssh'

#test SSH connection to vm

def check_ssh(ipaddress, user)
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

$evm.log(:info, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
$evm.log(:info, $evm.root['automation_task'].automation_request.inspect)


# check ssh to master
def check_ssh_to_master
  masters = $evm.root['automation_task'].automation_request.options[:attrs][:masters]
  $evm.log(:info, "xxxxxxxxxxxxxxxxxxxxxx masters xxxxxxxxxxxxxxxxxxxxxxxx")
  $evm.log(:info, masters)
end


check_ssh_to_master
#check ssh to slaves
