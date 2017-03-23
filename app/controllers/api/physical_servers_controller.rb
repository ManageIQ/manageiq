module Api
  class PhysicalServersController < BaseController
    def show
      if params[:c_id]
        physical_server = PhysicalServer.find(params[:c_id])
        response_payload = physical_server.as_json
        response_payload['host_id'] = physical_server.host.try(:id)

        render :json=> response_payload
      else
        super
      end
    end

    def server_ident(server)
      "Server instance: #{server.id} name:'#{server.name}'"
    end
  end
end
