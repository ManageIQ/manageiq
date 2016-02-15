class MiqAeCustomizationController < ApplicationController
  include_concern 'CustomButtons'
  include_concern 'OldDialogs'
  include_concern 'Dialogs'

  include AutomateTreeHelper

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  AE_CUSTOM_X_BUTTON_ALLOWED_ACTIONS = {
    'dialog_edit'            => :dialog_edit,
    'dialog_copy'            => :dialog_copy,
    'dialog_delete'          => :dialog_delete,
    'dialog_add_tab'         => :dialog_add_tab,
    'dialog_add_box'         => :dialog_add_box,
    'dialog_add_element'     => :dialog_add_element,
    'dialog_res_discard'     => :dialog_res_discard,
    'dialog_resource_remove' => :dialog_resource_remove,
    'dialog_new'             => :dialog_new,
    'old_dialogs_new'        => :old_dialogs_new,
    'old_dialogs_edit'       => :old_dialogs_edit,
    'old_dialogs_copy'       => :old_dialogs_copy,
    'old_dialogs_delete'     => :old_dialogs_delete,
    'ab_button_new'          => :ab_button_new,
    'ab_button_edit'         => :ab_button_edit,
    'ab_button_delete'       => :ab_button_delete,
    'ab_button_simulate'     => :ab_button_simulate,
    'ab_group_reorder'       => :ab_group_reorder,
    'ab_group_edit'          => :ab_group_edit,
    'ab_group_delete'        => :ab_group_delete,
    'ab_group_new'           => :ab_group_new,
  }.freeze

  def x_button
    @sb[:action] = action = params[:pressed]

    raise ActionController::RoutingError.new('invalid button action') unless
      AE_CUSTOM_X_BUTTON_ALLOWED_ACTIONS.key?(action)

    send(AE_CUSTOM_X_BUTTON_ALLOWED_ACTIONS[action])
  end

  def upload_import_file
    redirect_options = {:action => :review_import}

    if params[:upload].nil? || params[:upload][:file].nil?
      add_flash("Use the browse button to locate an import file", :warning)
    else
      begin
        import_file_upload_id = dialog_import_service.store_for_import(params[:upload][:file].read)
        add_flash(_("Import file was uploaded successfully"), :success)
        redirect_options[:import_file_upload_id] = import_file_upload_id
      rescue DialogImportValidator::ImportNonYamlError
        add_flash(_("Error: the file uploaded is not of the supported format"), :error)
      rescue DialogImportValidator::ParsedNonDialogYamlError
        add_flash(_("Error during upload: incorrect Dialog format, only service dialogs can be imported"), :error)
      rescue DialogImportValidator::InvalidDialogFieldTypeError
        add_flash(_("Error during upload: one of the DialogField types is not supported"), :error)
      end
    end

    redirect_options[:message] = @flash_array.first.to_json

    redirect_to redirect_options
  end

  def import_service_dialogs
    import_file_upload = ImportFileUpload.find_by(:id => params[:import_file_upload_id])

    if import_file_upload
      dialog_import_service.import_service_dialogs(import_file_upload, params[:dialogs_to_import])
      add_flash(_("Service dialogs imported successfully"), :success)
    else
      add_flash(_("Error: ImportFileUpload expired"), :error)
    end

    respond_to do |format|
      format.js { render :json => @flash_array.to_json, :status => 200 }
    end
  end

  def dialog_accordion_json
    accordion_json = {:locals_for_render => dialog_build_tree.locals_for_render}.to_json

    respond_to do |format|
      format.json { render :json => accordion_json, :status => 200 }
    end
  end

  def review_import
    @import_file_upload_id = params[:import_file_upload_id]
    @message = params[:message]
  end

  def cancel_import
    dialog_import_service.cancel_import(params[:import_file_upload_id])
    add_flash(_("Service dialog import cancelled"), :success)

    respond_to do |format|
      format.js { render :json => @flash_array.to_json, :status => 200 }
    end
  end

  def service_dialog_json
    import_file_upload_json = ImportFileUpload.find(params[:import_file_upload_id]).service_dialog_json

    respond_to do |format|
      format.json { render :json => import_file_upload_json }
    end
  end

  def export_service_dialogs
    if params[:service_dialogs]
      dialogs = Dialog.where(:id => params[:service_dialogs])
      dialog_yaml = DialogYamlSerializer.new.serialize(dialogs)
      timestamp = format_timezone(Time.current, Time.zone, "export_filename")
      send_data(dialog_yaml, :filename => "dialog_export_#{timestamp}.yml")
    else
      add_flash(_("At least 1 item must be selected for export"), :error)
      @sb[:flash_msg] = @flash_array
      redirect_to :action => :explorer
    end
  end

  def accordion_select
    self.x_active_accord = params[:id].sub(/_accord$/, '')
    self.x_active_tree   = "#{x_active_accord}_tree"
    get_node_info
    replace_right_cell(x_node)
  end

  def explorer
    @trees = []
    @flash_array = @sb[:flash_msg] unless @sb[:flash_msg].blank?
    @explorer = true
    build_resolve_screen
    self.x_active_tree ||= 'old_dialogs_tree'
    self.x_active_accord ||= 'old_dialogs'
    if x_active_tree == :dialog_edit_tree ||
       x_active_tree == :automate_tree && x_active_accord == :dialogs
      self.x_active_accord = 'dialogs'
      self.x_active_tree   = 'dialogs_tree'
    end
    @sb[:active_node] ||= {}
    @sb[:active_node][:ab_tree] ||= "root"
    @sb[:active_node][:old_dialogs_tree] ||= "root"
    @sb[:active_node][:dialogs_tree] ||= "root"
    @sb[:active_node][:dialog_import_export_tree] ||= "root"

    @trees = []
    @accords = []

    @trees << old_dialogs_build_tree
    @accords << {
      :name      => "old_dialogs",
      :title     => "Provisioning Dialogs",
      :container => "old_dialogs_accord"
    }

    @trees << dialog_build_tree
    @accords << {
      :name      => "dialogs",
      :title     => "Service Dialogs",
      :container => "dialogs_accord"
    }

    @trees << ab_build_tree
    @accords << {
      :name      => "ab",
      :title     => "Buttons",
      :container => "ab_accord"
    }

    @trees << dialog_import_export_build_tree
    @accords << {
      :name      => "dialog_import_export",
      :title     => "Import/Export",
      :container => "dialog_import_export_accord"
    }

    get_node_info
    @collapse_c_cell = true if (x_active_tree == :old_dialogs_tree &&
        x_node == "root") || x_active_tree == :ab_tree
    @lastaction = "automate_button"
    @layout = "miq_ae_customization"

    render :layout => "application" unless request.xml_http_request?
  end

  def tree_select
    valid = true
    if x_active_tree == :dialog_edit_tree
      @sb[:current_node] = x_node
      valid = dialog_validate
      self.x_node = params[:id] if valid
      @sb[:edit_typ] = nil unless @flash_array
    else
      self.x_node = params[:id]
    end
    if valid
      self.x_node = params[:id]
      get_node_info
      if @replace_tree

        # record being viewed and saved in @sb[:active_node] has been deleted outside UI from VMDB, need to refresh tree
        replace_right_cell(x_node, [:dialogs])
      else
        replace_right_cell(x_node)
      end
    else
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page << "miqDynatreeActivateNodeSilently('#{x_active_tree}', '#{x_node}');"
        page << "miqSparkle(false);"
      end
    end
  end

  # Record clicked on in the explorer right cell
  def x_show
    @explorer = true
    klass = x_active_tree == :old_dialogs_tree ? MiqDialog : Dialog
    @record = identify_record(params[:id], klass)
    params[:id] = x_build_node_id(@record)  # Get the tree node id
    tree_select
  end

  private

  def dialog_import_service
    @dialog_import_service ||= DialogImportService.new
  end

  def replace_right_cell(nodetype, replace_trees = [])
    # fixme, don't call all the time
    build_ae_tree(:automate, :automate_tree) # Build Catalog Items tree
    trees = {}
    if replace_trees
      trees[:ab]           = ab_build_tree                if replace_trees.include?(:ab)
      trees[:old_dialogs]  = old_dialogs_build_tree       if replace_trees.include?(:old_dialogs)
      trees[:dialogs]      = dialog_build_tree            if replace_trees.include?(:dialogs)
      trees[:dialog_edit]  = dialog_edit_build_tree       if replace_trees.include?(:dialog_edit)
    end

    @explorer = true
    presenter = ExplorerPresenter.new(:active_tree => x_active_tree)

    r = proc { |opts| render_to_string(opts) }
    replace_trees_by_presenter(presenter, trees)
    presenter[:osf_node] = x_node unless @in_a_form

    if ['dialog_edit', 'dialog_copy'].include?(params[:pressed])
      presenter[:clear_tree_cookies] = "edit_treeOpenStatex"
    end
    rebuild_toolbars(presenter)
    setup_presenter_based_on_active_tree(nodetype, presenter)
    set_right_cell_text(presenter)
    handle_bottom_cell(presenter)
    setup_dialog_sample_buttons(nodetype, presenter)
    set_miq_record_id(presenter)

    render :js => presenter.to_html
  end

  def dialog_edit_tree_active?
    x_active_tree == :dialog_edit_tree
  end

  def first_sub_node_is_a_folder?(node)
    sub_node = node.split("-").first

    sub_node == "xx" || !(sub_node == "" && node.split('_').length <= 2)
  end

  def get_node_info
    node = x_node
    node = valid_active_node(x_node) unless dialog_edit_tree_active? || first_sub_node_is_a_folder?(node)

    get_specific_node_info(node)

    x_history_add_item(:id => node, :text => @right_cell_text) unless x_active_tree == :dialog_edit_tree
  end

  def get_specific_node_info(node)
    if x_active_tree == :ab_tree
      ab_get_node_info(node)
    elsif x_active_tree == :dialog_edit_tree
      dialog_edit_set_form_vars
    elsif x_active_tree == :dialogs_tree
      dialog_get_node_info(node)
    elsif x_active_tree == :dialog_import_export_tree
      name_sorted_dialogs = Dialog.all.sort_by { |dialog| dialog.name.downcase }
      @dialog_exports = name_sorted_dialogs.collect { |dialog| [dialog.name, dialog.id] }
      @right_cell_text = "Service Dialog Import / Export"
    else
      old_dialogs_get_node_info(node)
    end
  end

  def handle_bottom_cell(presenter)
    if @pages || @in_a_form
      if @pages
        @ajax_paging_buttons = true # FIXME: this should not be done this way
        presenter.update(:paging_div, render_proc[:partial => 'layouts/x_pagingcontrols'])
        presenter.hide(:form_buttons_div).show(:pc_div_1)
      elsif @in_a_form && @sb[:action]
        action_url = case x_active_tree
                     when :old_dialogs_tree then 'old_dialogs_update'
                     when :dialog_edit_tree then 'dialog_edit'
                     else
                       case @sb[:action]
                       when 'ab_group_new'     then 'group_create'
                       when 'ab_group_edit'    then 'group_update'
                       when 'ab_group_reorder' then 'ab_group_reorder'
                       when 'ab_button_new'    then 'button_create'
                       when 'ab_button_edit'   then 'button_update'
                       end
                     end
        locals = {
          :action_url   => action_url,
          :record_id    => @record.try(:id),
          :serialize    => @sb[:action].starts_with?('old_dialogs_'),
          :multi_record => @sb[:action] == 'ab_group_reorder',
        }
        presenter.update(:form_buttons_div, render_proc[:partial => "layouts/x_edit_buttons", :locals => locals])
        presenter.hide(:pc_div_1).show(:form_buttons_div)
      end
      presenter.show(:paging_div)
    else
      presenter.hide(:paging_div)
    end
  end

  def no_items_selected?(field_name)
    !params[field_name] || params[field_name].length == 0 || params[field_name][0] == ""
  end

  def rebuild_toolbars(presenter)
    if !@in_a_form
      c_tb = build_toolbar(center_toolbar_filename)
      h_tb = build_toolbar("x_history_tb") if x_active_tree != :dialogs_tree
    else
      if x_active_tree == :dialog_edit_tree && @in_a_form
        nodes = x_node.split('_')
        if nodes.length == 1 && @sb[:node_typ].blank?
          @sb[:txt] = "Dialog"
        elsif (nodes.length == 2 && @sb[:node_typ] != "box") || (nodes.length == 1 && @sb[:node_typ] == "tab")
          @sb[:txt] = "Tab"
        elsif (nodes.length == 3 && @sb[:node_typ] != "element") || (nodes.length == 2 && @sb[:node_typ] == "box")
          @sb[:txt] = "Box"
        elsif nodes.length == 4 || (nodes.length == 3 && @sb[:node_typ] == "element")
          @sb[:txt] = "Element"
        end
        c_tb = build_toolbar(center_toolbar_filename)
      end
    end

    presenter.set_visibility(h_tb.present? || c_tb.present?, :toolbar)
    presenter.reload_toolbars(:history => h_tb, :center => c_tb)
  end

  def render_proc
    proc { |opts| render_to_string(opts) }
  end

  def set_miq_record_id(presenter)
    presenter[:record_id] = determine_record_id_for_presenter
  end

  def set_right_cell_text(presenter)
    presenter[:right_cell_text] = @right_cell_text
  end

  def get_session_data
    @layout  = "miq_ae_customization"
    @resolve = session[:resolve] if session[:resolve]
  end

  def set_session_data
    session[:resolve] = @resolve if @resolve
  end

  def setup_dialog_sample_buttons(nodetype, presenter)
    # TODO: move button from sample dialog to bottom cell

    if x_active_tree == :dialogs_tree && @sb[:active_tab] == "sample_tab" && nodetype != "root" && @record.buttons
      presenter.update(:form_buttons_div, render_proc[:partial => "dialog_sample_buttons"])
      presenter.hide(:pc_div_1, :form_buttons_div).show(:paging_div)
    end
  end

  def setup_presenter_based_on_active_tree(nodetype, presenter)
    if x_active_tree == :ab_tree
      setup_presenter_for_ab_tree(nodetype, presenter)
    elsif x_active_tree == :dialog_edit_tree
      setup_presenter_for_dialog_edit_tree(presenter)
    elsif x_active_tree == :dialogs_tree
      setup_presenter_for_dialogs_tree(nodetype, presenter)
    elsif x_active_tree == :old_dialogs_tree
      setup_presenter_for_old_dialogs_tree(nodetype, presenter)
    elsif x_active_tree == :dialog_import_export_tree
      presenter.update(:main_div, render_proc[:partial => "dialog_import_export"])
    end
  end

  def setup_presenter_for_ab_tree(nodetype, presenter)
    case nodetype
    when 'button_edit'
      @right_cell_text = @custom_button && @custom_button.id ?
        _("Editing %{model} \"%{name}\"") % {:name => @custom_button.name, :model => ui_lookup(:model => "CustomButton")} :
        _("Adding a new %s") % ui_lookup(:model => "CustomButton")
    when 'group_edit'
      @right_cell_text = @custom_button_set && @custom_button_set.id ?
        _("Editing %{model} \"%{name}\"") % {:name => @custom_button_set.name, :model => ui_lookup(:model => "CustomButtonSet")} :
        _("Adding a new %s") % ui_lookup(:model => "CustomButtonSet")
    when 'group_reorder'
      @right_cell_text = _("%s Group Reorder") % ui_lookup(:models => "CustomButton")
    end

    # Replace right side with based on selected tree node type
    presenter.update(:main_div, render_proc[:partial => "shared/buttons/ab_list"])
    presenter[:lock_unlock_trees][:ab_tree] = !!@edit
  end

  def setup_presenter_for_dialog_edit_tree(presenter)
    presenter.update(:main_div, render_proc[:partial => "dialog_form"])
    presenter[:cell_a_view] = 'custom'

    @right_cell_text = @record.id.blank? ?
      _("Adding a new %s") % ui_lookup(:model => "Dialog") :
      _("Editing %{model} \"%{name}\"") % {:name => @record.label.to_s, :model => "#{ui_lookup(:model => "Dialog")}"}
    @right_cell_text << " [#{@sb[:txt]} Information]"

    # url to be used in url in miqDropComplete method
    presenter[:miq_widget_dd_url] = 'miq_ae_customization/dialog_res_reorder'
    presenter[:init_dashboard] = true
    presenter.update(:custom_left_cell, render_proc[:partial => "dialog_edit_tree"])
    presenter.show(:custom_left_cell).hide(:default_left_cell)
  end

  def setup_presenter_for_dialogs_tree(nodetype, presenter)
    nodes = nodetype.split("_")
    if nodetype == "root"
      presenter.update(:main_div, render_proc[:partial => "layouts/x_gtl"])
    else
      @sb[:active_tab] = params[:tab_id] ? params[:tab_id] : "sample_tab"
      presenter.update(:main_div, render_proc[:partial => "dialog_details"])
    end

    presenter[:build_calendar] = true
    # resetting ManageIQ.oneTransition.oneTrans when tab loads
    presenter[:extra_js] << 'ManageIQ.oneTransition.oneTrans = 0;'
    if %w(save reset).include?(params[:button]) && is_browser_ie?
      presenter[:extra_js] << "ManageIQ.oneTransition.IEButtonPressed = true"
    end
    presenter.hide(:custom_left_cell).show(:default_left_cell)
  end

  def setup_presenter_for_old_dialogs_tree(nodetype, presenter)
    nodes = nodetype.split("_")
    if nodetype == "root" || nodes[0].split('-').first != "odg"
      partial = nodetype == 'root' ? 'old_dialogs_list' : 'layouts/x_gtl'
      presenter.update(:main_div, render_proc[:partial => partial])
    else
      presenter.update(:main_div, render_proc[:partial => 'old_dialogs_details'])
      if @dialog.id.blank? && !@dialog.dialog_type
        @right_cell_text = _("Adding a new %s") % ui_lookup(:model => "MiqDialog")
      else
        title = @edit ? (params[:typ] == "copy" ? "Copy " : "Editing ") : ""
        @right_cell_text = _("Editing %{model} \"%{name}\"") % {:name => @dialog.description.gsub(/'/, "\\'"), :model => "#{title} #{ui_lookup(:model => "MiqDialog")}"}
      end

      presenter[:extra_js] << 'ManageIQ.oneTransition.oneTrans = 0;' # resetting ManageIQ.oneTransition.oneTrans when tab loads
      presenter[:extra_js] << "ManageIQ.oneTransition.IEButtonPressed = true" if %w(save reset).include?(params[:button]) && is_browser_ie?
    end
  end

  def old_dialogs_build_tree
    TreeBuilderProvisioningDialogs.new("old_dialogs_tree", "old_dialogs", @sb)
  end

  def dialog_build_tree
    TreeBuilderServiceDialogs.new("dialogs_tree", "dialogs", @sb)
  end

  def ab_build_tree
    TreeBuilderButtons.new("ab_tree", "ab", @sb)
  end

  def dialog_import_export_build_tree
    TreeBuilderAeCustomization.new("dialog_import_export_tree", "dialog_import_export", @sb)
  end

  def group_button_add_save(typ)
    # override for AE Customization Buttons - the label doesn't say Description
    if @edit[:new][:description].blank?
      render_flash(_("%s is required") % "Button Group Hover Text", :error)
      return
    end

    super(typ)
  end
end
