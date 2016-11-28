module Mixins
  module GenericShowMixin
    def show
      return unless init_show

      case @display
      when "download_pdf", "summary_only" then show_download
      when "main"                         then show_main
      when *self.class.display_methods    then display_nested_list(@display)
      end

      replace_gtl_main_div if is_gtl_request?
    end

    def is_gtl_request?
      params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
    end

    def show_download
      show_main
      set_summary_pdf_data
    end

    def show_main
      get_tagdata(@record)
      drop_breadcrumb({:name => ui_lookup(:tables => self.class.table_name),
                       :url  => "/#{self.class.table_name}/show_list?page=#{@current_page}&refresh=y"},
                      true)

      show_url = restful? ? "/#{self.class.table_name}/" :
                            "/#{self.class.table_name}/show/"

      drop_breadcrumb(:name =>  _("%{name} (Summary)") % {:name => @record.name},
                      :url  => "#{show_url}#{@record.id}")
      @showtype = "main"
    end

    def gtl_url
      restful? ? '/' : '/show'
    end

    def init_show(model_class = self.class.model)
      @record = identify_record(params[:id], model_class)
      return false if record_no_longer_exists?(@record)
      @lastaction = 'show'
      @gtl_url = gtl_url
      @display = params[:display] || 'main' unless control_selected?
      true
    end

    def nested_list_method(display)
      methods = self.class.display_methods
      # Converting to hash so brakeman doesn't complain about using params directly
      methods.zip(methods).to_h[display]
    end

    def nested_list_method_name(display)
      "display_#{nested_list_method(display)}"
    end

    def nested_list_call(display)
      public_send(nested_list_method_name(display))
    end

    def display_nested_list(display)
      respond_to?(nested_list_method_name(display).to_sym) ? nested_list_call(display) : display_nested_generic(display)
    end

    def display_nested_generic(display)
      nested_list(display, display.camelize.singularize.constantize)
    end

    def display_instances
      nested_list("vm_cloud", ManageIQ::Providers::CloudManager::Vm)
    end

    def display_images
      nested_list("template_cloud", ManageIQ::Providers::CloudManager::Template)
    end

    def nested_list(table_name, model)
      title = ui_lookup(:tables => table_name)
      drop_breadcrumb(:name => _("%{name} (Summary)") % {:name => @record.name},
                      :url  => "/#{self.class.table_name}/show/#{@record.id}")
      drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => @record.name, :title => title},
                      :url  => "/#{self.class.table_name}/show/#{@record.id}?display=#{@display}")
      @view, @pages = get_view(model, :parent => @record) # Get the records (into a view) and the paginator
      @showtype     = @display
    end
  end
end
