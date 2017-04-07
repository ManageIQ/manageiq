module Api
  class PhysicalServersController < BaseController
    def blink_loc_led_resource(type, id, _data)
      change_resource_state(:blink_loc_led, type, id)
    end

    def turn_on_loc_led_resource(type, id, _data)
      change_resource_state(:turn_on_loc_led, type, id)
    end

    def turn_off_loc_led_resource(type, id, _data)
      change_resource_state(:turn_off_loc_led, type, id)
    end

    #
    # Name: power_on_resource
    # Description: Power on server
    #
    def power_on_resource(type, id, _data)
      change_resource_state(:power_on, type, id)
    end

    def power_off_resource(type, id, _data)
      change_resource_state(:power_off, type, id)
    end

    def restart_resource(type, id, _data)
      change_resource_state(:restart, type, id)
    end

    private

    def change_resource_state(state, type, id)
      raise BadRequestError, "Must specify an id for changing a #{type} resource" unless id

      api_action(type, id) do |klass|
        begin
          server = resource_search(id, type, klass)
          desc = "Requested server state #{state} for #{server_ident(server)}"
          api_log_info("desc")
          task_id = queue_object_action(server, desc, :method_name => state, :role => :ems_operations)
          action_result(true, desc, :task_id => task_id)
        rescue => err
          action_result(false, err.to_s)
        end
      end
    end

    def server_ident(server)
      "Server instance: #{server.id} name:'#{server.name}'"
    end
  end
end
