begin
              vm = $evm.root['vm']
              $evm.root['vm_id_via_hash']     = vm['id']
              $evm.root['vm_id_via_call']     = vm.id
              $evm.root['vm_name']            = vm.name
              $evm.root['vm_normalized_name'] = vm.normalized_name
            end
