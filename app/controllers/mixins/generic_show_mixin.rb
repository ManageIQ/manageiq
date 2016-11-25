module Mixins
  module GenericShowMixin
    def show
      @display = params[:display] || "main" unless control_selected?

      @lastaction = "show"
      @record     = identify_record(params[:id])
      return if record_no_longer_exists?(@record)

      @gtl_url = "/show"
      case @display
      when "download_pdf", "main", "summary_only"
        get_tagdata(@record)
        drop_breadcrumb({:name => "#{self.class.table_name}s",
                         :url  => "/#{self.class.table_name}/show_list?page=#{@current_page}&refresh=y"},
                        true)
        drop_breadcrumb(:name =>  _("%{name} (Summary)") % {:name => @record.name},
                        :url  => "/#{self.class.table_name}/show/#{@record.id}")
        @showtype = "main"
        set_summary_pdf_data if ["download_pdf", "summary_only"].include?(@display)
      when *self.class.display_methods
        display_nested_list(@display)
      end

      # Came in from outside show_list partial
      if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
        replace_gtl_main_div
      end
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
