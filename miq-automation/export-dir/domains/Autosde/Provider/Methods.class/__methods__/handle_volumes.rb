#
# Description: <Method description here>
#
module Automation
  module Provider
    class Volumes

      def initialize(handle = $evm, name='my-svc')
        @handle = handle
        @name = name
      end

      def main
        do_stuff
      end

      def do_stuff
        puts "$$$*******************"
        puts @handle.root.attributes
        puts "$$$*******************"
        vm = @handle.root['vm']
        vm_name = vm.name
        vm_ip = vm.ipaddresses.first
        puts "*******************"
        puts vm_ip
        puts "*******************"
        
        # get dialog parameters
        cred_name = @handle.root['dialog_cred_name']
        cred_pwd = @handle.root['dialog_cred_password']
        pool_name = @handle.root['dialog_pools']
        vol_name = @handle.root['dialog_volume_name']
        vol_size = @handle.root['dialog_volume_size']
        
        svc =  $evm.vmdb(:ext_management_system).where(:name=>@name).first
        puts "IN POOLS!"
        p svc
        # create_and_attach_volume(volume_name, volume_size, host_name, pool_name, host_ip, host_username, host_password)
        puts "calling create and attach volume with params:"
        puts "vol_name = #{vol_name}, vol_size= #{vol_size}, host_name=#{vm_name}, pool_name=#{pool_name}, host_ip= #{vm_ip}, host_username= #{cred_name}, host_password=#{cred_pwd}"
        cat = svc.object_send('create_and_attach_volume', vol_name, vol_size, vm_name, pool_name, vm_ip, cred_name, cred_pwd )
        puts cat
      end
    end
  end
end

#puts $evm.root.attributes

Automation::Provider::Volumes.new.main

