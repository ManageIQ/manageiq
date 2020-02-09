module Automation
  module Provider
    class Pools

      def initialize(handle = $evm, name='my-svc')
        @handle = handle
        @name = name
      end

      def main
        do_stuff
      end

      def fill_dialog(values)
		# may be invoked from debugging on server
		# then @handle.object not exists
		# simulate
		unless	@handle.object 
			def @handle.object() 
				puts "IN SIMULATE dialog"
			{}
			end 
		end
	  
        dialog_field = @handle.object
 
        # sort_by: value / description / none
        dialog_field["sort_by"] = "value"

        # sort_order: ascending / descending
        dialog_field["sort_order"] = "ascending"

        # data_type: string / integer
        dialog_field["data_type"] = "string"

        # required: true / false
        dialog_field["required"] = "true"

        dialog_field["values"] = values

        puts "in dialog pools #{dialog_field}"

      end

      def do_stuff

        svc =  $evm.vmdb(:ext_management_system).where(:name=>@name).first
        puts "!IN POOLS LIST"
        p svc
        #call list_pools method
        puts "call method list_pools on #{svc}"
        lv = svc.object_send('list_pools')
        p lv
        # make list of pool names
        pool_names = lv.map do |v| v['name'] end
        values = {}
        pool_names.each do |v| values[v] = v end
        fill_dialog(values) 
		puts pool_names	
        #puts "calling creat and attach"
        #cat = svc.object_send('create_and_attach_volume', "my-vol", 130)
        #puts cat
      end
    end
  end
end

Automation::Provider::Pools.new.main
