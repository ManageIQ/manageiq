module ApplicationController::DialogRunner
  extend ActiveSupport::Concern

  def redirect_url(flash)
    model = self.class.model
    if restful_routed?(model)
      polymorphic_path(model.find(session[:edit][:target_id]), :flash_msg => flash)
    else
      {:action => 'show', :id => session[:edit][:target_id], :flash_msg => flash}
    end
  end

  def dialog_cancel_form(flash = nil)
    @sb[:action] = @edit = nil
    @in_a_form = false
    if session[:edit][:explorer]
      add_flash(flash)
      replace_right_cell
    else
      javascript_redirect redirect_url(flash)
    end
  end

  def dialog_form_button_pressed
    case params[:button]
    when "cancel"
      flash = _("%{model} Order was cancelled by the user") % {:model => ui_lookup(:model => 'Service')}
      dialog_cancel_form(flash)
    when "submit"
      return unless load_edit("dialog_edit__#{params[:id]}", "replace_cell__explorer")
      begin
        result = @edit[:wf].submit_request
      rescue => bang
        add_flash(_("Error during 'Provisioning': %{error_message}") % {:error_message => bang.message}, :error)
        javascript_flash
      else
        unless result[:errors].blank?
          # show validation errors
          result[:errors].each do |err|
            add_flash(err, :error)
          end
          javascript_flash
        else
          flash = _("Order Request was Submitted")
          if role_allows?(:feature => "miq_request_show_list", :any => true)
            @sb[:action] = @edit = nil
            @in_a_form = false
            if session[:edit][:explorer]
              add_flash(flash)
              if result[:request].nil?
                replace_right_cell
              else
                javascript_redirect :controller => 'miq_request',
                                    :action     => 'show_list',
                                    :flash_msg  => flash
              end
            else
              javascript_redirect redirect_url(flash)
            end
          else
            dialog_cancel_form(flash)
          end
        end
      end
    when "reset"  # Reset
      dialog_reset_form
      flash = _("All changes have been reset")
      if session[:edit][:explorer]
        add_flash(flash, :warning)
        replace_right_cell(:action => "dialog_provision")
      else
        javascript_redirect :action => 'dialog_load', :flash_msg => flash, :flash_warning => true, :escape => false # redirect to miq_request show_list screen
      end
    else
      return unless load_edit("dialog_edit__#{params[:id]}", "replace_cell__explorer")
      add_flash(_("%{button_name} Button not yet implemented") % {:button_name => params[:button].capitalize}, :error)
      javascript_flash
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def dialog_field_changed
    return unless load_edit("dialog_edit__#{params[:id]}", "replace_cell__explorer")
    dialog_get_form_vars

    # Use JS to update the display
    render :update do |page|
      page << javascript_prologue
      page << "miqSparkle(false);"
    end
  end

  # for non-explorer screen
  def dialog_load
    @edit = session[:edit]
    @record = Dialog.find_by_id(@edit[:rec_id])
    @dialog_prov = true
    @in_a_form = true
    @showtype = "dialog_provision"
    render :action => "show"
  end

  def dynamic_radio_button_refresh
    field = load_dialog_field(params[:name])

    response_json = {:values => field.refresh_json_value(params[:checked_value])}
    dynamic_refresh_response(response_json)
  end

  def dynamic_text_box_refresh
    refresh_for_textbox_checkbox_or_date
  end

  def dynamic_checkbox_refresh
    refresh_for_textbox_checkbox_or_date
  end

  def dynamic_date_refresh
    refresh_for_textbox_checkbox_or_date
  end

  private     #######################

  def refresh_for_textbox_checkbox_or_date
    field = load_dialog_field(params[:name])

    dynamic_refresh_response(:values => field.refresh_json_value)
  end

  def dynamic_refresh_response(response_json)
    respond_to do |format|
      format.json { render :json => response_json, :status => 200 }
    end
  end

  def dialog_reset_form
    return unless load_edit("dialog_edit__#{params[:id]}", "replace_cell__explorer")
    @edit[:new] = copy_hash(@edit[:current])
    @record = Dialog.find_by_id(@edit[:rec_id])
    @right_cell_text = @edit[:right_cell_text]
    @in_a_form = true
  end

  def dialog_initialize(ra, options)
    @edit = {}
    @edit[:new] = options[:dialog] || {}
    opts = {
      :target => options[:target_kls].constantize.find_by_id(options[:target_id])
    }
    @edit[:wf] = ResourceActionWorkflow.new(@edit[:new], current_user, ra, opts)
    @record = Dialog.find_by_id(ra.dialog_id.to_i)
    @edit[:rec_id]   = @record.id
    @edit[:key]     = "dialog_edit__#{@edit[:rec_id] || "new"}"
    @edit[:explorer] = @explorer ? @explorer : false
    @edit[:target_id] = options[:target_id]
    @edit[:target_kls] = options[:target_kls]
    @edit[:dialog_mode] = options[:dialog_mode]
    @edit[:current] = copy_hash(@edit[:new])
    @edit[:right_cell_text] = options[:header].to_s
    @in_a_form = true
    @changed = session[:changed] = true
    if @edit[:explorer]
      replace_right_cell(:action => "dialog_provision")
    else
      javascript_redirect :action => 'dialog_load'
    end
  end

  def dialog_get_form_vars
    @record = Dialog.find_by_id(@edit[:rec_id])

    params.each do |parameter_key, parameter_value|
      parameter_key = parameter_key.split("__protected").first if parameter_key.ends_with?("__protected")

      if parameter_key.starts_with?("miq_date__") && @record.field_name_exist?(parameter_key.split("miq_date__").last)
        field_name = parameter_key.split("miq_date__").last
        old = @edit[:wf].value(field_name)
        new = parameter_value

        # keep the chosen time if DateTime
        new += old[10..-1] if old && old.length > 10

        @edit[:wf].set_value(field_name, new)

      elsif %w(start_hour start_min).include?(parameter_key)
        # find any DateTime field and assume it's the only one..
        field_name = @edit[:wf].dialog.dialog_fields.reverse.find do |f|
          f.type == 'DialogFieldDateTimeControl'
        end.try(:name)
        next if field_name.nil?

        # if user didn't choose the date and goes with default shown in the textbox,
        # need to set that value in wf before adding hour/min
        old = @edit[:wf].value(field_name)
        if old.nil?
          t = Time.zone.now + 1.day
          date_val = [t.strftime('%m/%d/%Y'), t.strftime('%H:%M')]
        else
          date_val = old.split(" ")
        end

        start_hour = date_val.length >= 2 ? date_val[1].split(":").first.to_i : 0
        start_min = date_val.length >= 2 ? date_val[1].split(":").last.to_i : 0

        if parameter_key == "start_hour"
          start_hour = parameter_value.to_i
        else
          start_min = parameter_value.to_i
        end
        date_val[1] = "%02d:%02d" % [start_hour, start_min]

        @edit[:wf].set_value(field_name, date_val.join(' '))

      elsif @edit[:wf].dialog.field(parameter_key).try(:type) == "DialogFieldCheckBox"
        checkbox_value = parameter_value == "1" ? "t" : "f"
        @edit[:wf].set_value(parameter_key, checkbox_value) if @record.field_name_exist?(parameter_key)

      else
        if @record.field_name_exist?(parameter_key)
          @edit[:wf].set_value(parameter_key, parameter_value)
        end
      end
    end
  end

  def load_dialog_field(field_name)
    @edit = session[:edit]
    dialog = @edit[:wf].dialog
    dialog.field(field_name)
  end
end
