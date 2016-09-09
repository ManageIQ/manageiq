module Api
  class AutomateController < BaseController
    def show
      ae_browser = MiqAeBrowser.new(@auth_user_obj)
      begin
        resources = ae_browser.search(@req.c_suffix, ae_search_options)
      rescue => err
        raise BadRequestError, err.to_s
      end
      attributes = params['attributes'] ? %w(fqname) | params['attributes'].to_s.split(',') : nil
      resources = resources.collect { |resource| filter_ae_resource(resource, attributes) } if attributes
      render_resource :automate, :name => "automate", :subcount => resources.count, :resources => resources
    end

    private

    def filter_ae_resource(resource, attributes = nil)
      attributes.blank? ? resource : resource.slice(*attributes)
    end

    def ae_search_options
      # For /api/automate (discovering domains, scope is 1 if unspecified)
      # Otherwise, we default depth to 0 (current object), use -1 for unlimited depth search
      depth = if params[:depth]
                params[:depth] == "-1" ? nil : params[:depth].to_i
              else
                @req.c_suffix.blank? ? 1 : 0
              end
      search_options = {:depth => depth, :serialize => true}
      search_options[:state_machines] = true if search_option?(:state_machines)
      search_options
    end
  end
end
