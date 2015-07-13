begin
              $evm.log("info", "#{@method} - Root:<$evm.root> Begin Attributes")
              $evm.root.attributes.sort.each do |k, v|
                $evm.log("info", "#{@method} - Root:<$evm.root> Attributes - #{k}: #{v}")
              end
              $evm.log("info", "#{@method} - Root:<$evm.root> End Attributes")
              $evm.log("info", "#{$evm.class.name}")
              $evm.root['method_executed']  = "user"
            end
