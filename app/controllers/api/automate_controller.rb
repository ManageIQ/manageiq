module Api
  class AutomateController < BaseController
    def show
      ae_browser = MiqAeBrowser.new(User.current_user)
      begin
        resources = ae_browser.search(@req.c_suffix, ae_search_options)
      rescue => err
        raise BadRequestError, err.to_s
      end
      attributes = params['attributes'] ? %w(fqname) | params['attributes'].to_s.split(',') : nil
      resources = resources.collect { |resource| resource.slice(*attributes) } if attributes.present?
      render_resource :automate, :name => "automate", :subcount => resources.count, :resources => resources
    end

    private

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
