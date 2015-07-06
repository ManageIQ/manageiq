begin
              $evm.root['encrypted'] = $evm.current['password']
              $evm.root['decrypted'] = $evm.current.decrypt('password')
            end
