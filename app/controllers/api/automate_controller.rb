module Api
  class AutomateController < BaseController
    def index
      resources = fetch_resources
      render_resource :automate, :name => "automate", :subcount => resources.count, :resources => resources
    end

    def show
      resources = fetch_resources(@req.c_suffix)
      render_resource :automate, :name => "automate", :subcount => resources.count, :resources => resources
    end

    private

    def fetch_resources(object_ref = nil)
      resources = ae_browser.search(object_ref, ae_search_options)
      resources.collect! { |resource| resource.slice(*attribute_params) } if attribute_params.present?
      resources
    rescue => err
      raise BadRequestError, err.to_s
    end

    def ae_browser
      @ae_browser ||= MiqAeBrowser.new(User.current_user)
    end

    def attribute_params
      @attribute_params ||= params['attributes'] ? %w(fqname) | params['attributes'].to_s.split(',') : nil
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
