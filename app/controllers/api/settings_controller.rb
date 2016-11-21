module Api
  class SettingsController < BaseController
    def show
      category = @req.c_id
      selected_sections =
        if category
          raise NotFoundError, "Settings category #{category} not found" unless exposed_settings.include?(category)
          category
        else
          exposed_settings
        end

      render_resource :settings, ::Settings.to_hash.slice(*Array(selected_sections).collect(&:to_sym))
    end

    def update
      if @req.c_id == "server"
        edit_server_settings(json_body_resource)
      else
        raise BadRequestError, "Could not update #{@req.c_id} settings. Only server settings update is supported"
      end
    end

    def edit_server_settings(data)
      server = data["id"] ? MiqServer.find(data["id"]) : MiqServer.my_server(true)
      update = server.get_config("vmdb")
      data = data.symbolize_keys.except(:id)
      data.each do |k, v|
        update.config[:server][k] = v
      end
      if update.validate
        server.set_config(update)
      end
      render_resource :settings, ::Settings.to_hash.slice(*Array("server").collect(&:to_sym))
    rescue => err
      raise BadRequestError, "Could not update server settings - #{err}"
    end

    private

    def exposed_settings
      ApiConfig.collections[:settings][:categories]
    end
  end
end
