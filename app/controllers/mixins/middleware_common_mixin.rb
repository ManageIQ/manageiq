module MiddlewareCommonMixin
  extend ActiveSupport::Concern
  def show_list
    process_show_list
  end

  def index
    redirect_to :action => 'show_list'
  end

  def show
    return unless init_show
    show_middleware
  end

  private

  def display_name(display = nil)
    if display.blank?
      ui_lookup(:tables => @record.class.base_class.name)
    else
      ui_lookup(:tables => display)
    end
  end

  def listicon_image(item, _view)
    item.decorate.try(:listicon_image)
  end

  def clear_topology_breadcrumb
    # fix breadcrumbs - remove displaying 'topology' in breadcrumb when navigating to a middleware related entity summary page
    if @breadcrumbs.present? && (@breadcrumbs.last[:name].eql? 'Topology')
      @breadcrumbs.clear
    end
  end

  def init_show(model_class = self.class.model)
    @ems = @record = identify_record(params[:id], model_class)
    return false if record_no_longer_exists?(@record)
    clear_topology_breadcrumb
    @lastaction = 'show'
    @gtl_url = '/show'
    @display = params[:display] || 'main' unless control_selected?
    true
  end

  def show_middleware
    drop_breadcrumb({:name => display_name,
                     :url  => show_list_link(@record, :page => @current_page, :refresh => 'y')
                    }, true)
    case @display
    when 'main'                          then show_main
    when 'download_pdf', 'summary_only'  then show_download
    when 'timeline'                      then show_timeline
    when 'performance'                   then show_performance
    end
  end

  def show_middleware_entities(klass)
    @showtype = @display = params[:display] unless params[:display].nil?
    breadcrumb_title = _("%{name} (All %{title})") % {:name  => @record.name,
                                                      :title => display_name(@display)}
    drop_breadcrumb(:name => breadcrumb_title, :url => show_link(@record, :display => @display))
    @view, @pages = get_view(klass, :parent => @record)
  end

  def trigger_mw_operation(operation, mw_item, params = nil)
    mw_manager = mw_item.ext_management_system
    op = mw_manager.public_method operation
    if params
      op.call(mw_item.ems_ref, params)
    else
      op.call mw_item.ems_ref
    end
  end

  #
  # Identify the selected entities. When we got the call from the
  # single entity page, we need to look at :id, otherwise from
  # the list of entities we need to query :miq_grid_checks
  #
  def identify_selected_entities
    items = params[:miq_grid_checks]
    return items unless items.nil? || items.empty?
    params[:id]
  end

  def run_operation(operation_info, items, success_msg = "%{msg}")
    if items.nil?
      add_flash(_("No %{item_type} selected") % {:item_type => controller_name.pluralize})
      return
    end
    operation_triggered = run_operation_batch(operation_info, items)
    add_flash(_(success_msg) % {:msg => operation_info.fetch(:msg)}) if operation_triggered
  end

  def run_operation_on_record(operation_info, item_record)
    if operation_info.key? :param
      # Fetch param from UI - > see #9462/#8079
      name = operation_info.fetch(:param)
      val = params.fetch name || 0 # Default until we can really get it from the UI ( #9462/#8079)
      trigger_mw_operation operation_info.fetch(:op), item_record, name => val
    else
      trigger_mw_operation operation_info.fetch(:op), item_record
    end
  end

  def skip_operation?(item_record, operation_info)
    provider_name = 'Hawkular'
    if operation_info.fetch(:skip)
      item_record.try(:product) == provider_name || item_record.try(:middleware_server).try(:product) == provider_name
    end
  end

  def run_operation_batch(operation_info, items)
    operation_triggered = false
    items.split(/,/).each do |item|
      item_record = identify_record item
      if skip_operation?(item_record, operation_info)
        message = if operation_info.key?(:skip_msg)
                    operation_info.fetch(:skip_msg)
                  else
                    "Not %{operation_name} the provider itself"
                  end
        add_flash(_(message) % {
          :operation_name => operation_info.fetch(:hawk),
          :record_name    => item_record.name
        }, :warning)
      else
        run_operation_on_record(operation_info, item_record)
        operation_triggered = true
      end
    end
    operation_triggered
  end
end
