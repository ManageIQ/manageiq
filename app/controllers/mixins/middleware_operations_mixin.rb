module MiddlewareOperationsMixin
  extend ActiveSupport::Concern

  def button
    klass = child_entity_controller
    selected_operation = params[:pressed].to_sym
    if !klass.try(:operations).nil? && klass.operations.key?(selected_operation)
      selected_items = params[:miq_grid_checks]
      selected_entities = identify_selected_entities(selected_items)
      run_specific_operation(klass.operations.fetch(selected_operation), selected_entities, "%{msg}", klass.model)
      javascript_flash if @content.nil?
    else
      super
    end
  end

  private

  def child_entity_controller
    if @display && @display != 'main'
      begin
        return Object.const_get(@display.camelize.singularize + 'Controller')
      rescue NameError
        # There is no such a controller for the display url param
        return self.class
      end
    end
    self.class
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
  def identify_selected_entities(selected_items = params[:miq_grid_checks])
    return selected_items unless selected_items.nil? || selected_items.empty?
    params[:id]
  end

  def run_specific_operation(operation_info, items, success_msg = "%{msg}", klass = self.class.model)
    if items.nil?
      add_flash(_("No %{item_type} selected") % {:item_type => controller_name.pluralize})
      return
    end
    operation_triggered = run_operation_batch(operation_info, items, klass)
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

  def run_operation_batch(operation_info, items, klass = self.class.model)
    operation_triggered = false
    items.split(/,/).each do |item|
      item_record = identify_record item, klass
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
