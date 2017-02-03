module Api
  class PhysicalServersController < BaseController
    include Subcollections::Firmwares

    def show
      if params[:c_id]
        physical_server = PhysicalServer.find(params[:c_id])
        response_payload = physical_server.as_json
        firmwares = physical_server.firmwares.map(&:as_json)
        response_payload["firmwares"] = firmwares
        response_payload["host_id"] = case physical_server.host
                                      when nil then nil
                                      else physical_server.host.id
                                      end

        render :json=> response_payload
      else
        super
      end
    end

    def turn_on_loc_led_resource(type, id, _data)
      $lenovo_log.info("#{type} #{id}")
      raise BadRequestError, "Must specify an id for starting a #{type} resource" unless id

      api_action(type, id) do |klass|
        server = resource_search(id, type, klass)
        api_log_info("Starting #{klass} #{server}")
        api_log_info(" #{server_ident(server)}")
        desc = "Turn on Loc LED"
        task_id = queue_object_action(server, desc, :method_name => "turn_on_loc_led", :role => "ems_operations")
        action_result(true, desc, :task_id => task_id)
      end
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
      $lenovo_log.info("Change the stae of resource: #{type} instance: #{id}")
      raise BadRequestError, "Must specify an id for starting a #{type} resource" unless id

      api_action(type, id) do |klass|
        server = resource_search(id, type, klass)
        api_log_info(" Processing request to #{state} #{server_ident(server)}")
        desc = state.to_s
        task_id = queue_object_action(server, desc, :method_name => state, :role => :ems_operations)
        action_result(true, desc, :task_id => task_id)
      end
    end

    def server_ident(server)
      "Server instance: #{server.id} name:'#{server.name}'"
    end
  end
end
