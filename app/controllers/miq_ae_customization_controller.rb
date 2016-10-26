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
    generic_x_button(AE_CUSTOM_X_BUTTON_ALLOWED_ACTIONS)
  end

  def upload_import_file
    if params[:upload].nil? || params[:upload][:file].blank?
      add_flash(_("Use the Choose file button to locate an import file"), :warning)
    else
      begin
        import_file = dialog_import_service.store_for_import(params[:upload][:file].read)
        @import_file_upload_id = import_file.id
        @import = import_file.service_dialog_list
        add_flash(_("Select Dialogs to import"), :info)
      rescue DialogImportValidator::ImportNonYamlError
        add_flash(_("Error: the file uploaded is not of the supported format"), :error)
      rescue DialogImportValidator::ParsedNonDialogYamlError
        add_flash(_("Error during upload: incorrect Dialog format, only service dialogs can be imported"), :error)
      rescue DialogImportValidator::InvalidDialogFieldTypeError
        add_flash(_("Error during upload: one of the DialogField types is not supported"), :error)
      end
    end
    get_node_info
    replace_right_cell(x_node)
  end

  def import_service_dialogs
    if params[:commit] == _('Commit')
      if params[:dialogs_to_import].blank?
        javascript_flash(:spinner_off => true,
                         :text => _("At least one Service Dialog must be selected."),
                         :severity => :error)
        return
      end

      import_file_upload = ImportFileUpload.find_by(:id => params[:import_file_upload_id])

      if import_file_upload
        dialog_import_service.import_service_dialogs(import_file_upload, params[:dialogs_to_import])
        add_flash(_("Service dialogs imported successfully"), :success)
      else
        add_flash(_("Error: ImportFileUpload expired"), :error)
      end
    else
      dialog_import_service.cancel_import(params[:import_file_upload_id])
      add_flash(_("Service dialog import cancelled"), :success)
    end
    get_node_info
    replace_right_cell(x_node, [:dialogs])
  end

  def export_service_dialogs
    if params[:service_dialogs].present?
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

    # service dialog edit abandoned
    self.x_active_tree = :dialogs_tree if x_active_tree == :dialog_edit_tree

    build_accordions_and_trees

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
        page << javascript_prologue
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page << "miqTreeActivateNodeSilently('#{x_active_tree}', '#{x_node}');"
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

  def features
    [{:role     => "old_dialogs_accord",
      :role_any => true,
      :name     => :old_dialogs,
      :title    => _("Provisioning Dialogs")},

     {:role     => "dialog_accord",
      :role_any => true,
      :name     => :dialogs,
      :title    => _("Service Dialogs")},

     {:role     => "ab_buttons_accord",
      :role_any => true,
      :name     => :ab,
      :title    => _("Buttons")},

     {:role     => "miq_ae_class_import_export",
      :name     => :dialog_import_export,
      :title    => _("Import/Export")},
    ].map do |hsh|
      ApplicationController::Feature.new_with_hash(hsh)
    end
  end

  def set_active_elements(feature)
    if feature
      self.x_active_tree ||= feature.tree_list_name
      self.x_active_accord ||= feature.accord_name
    end
    get_node_info
  end

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

    render :json => presenter.for_render
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
      @right_cell_text = _("Service Dialog Import / Export")
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
          @sb[:txt] = _("Dialog")
        elsif (nodes.length == 2 && @sb[:node_typ] != "box") || (nodes.length == 1 && @sb[:node_typ] == "tab")
          @sb[:txt] = _("Tab")
        elsif (nodes.length == 3 && @sb[:node_typ] != "element") || (nodes.length == 2 && @sb[:node_typ] == "box")
          @sb[:txt] = _("Box")
        elsif nodes.length == 4 || (nodes.length == 3 && @sb[:node_typ] == "element")
          @sb[:txt] = _("Element")
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
      @right_cell_text = if @custom_button && @custom_button.id
                           _("Editing %{model} \"%{name}\"") % {:name  => @custom_button.name,
                                                                :model => ui_lookup(:model => "CustomButton")}
                         else
                           _("Adding a new %{model}") % {:model => ui_lookup(:model => "CustomButton")}
                         end
    when 'group_edit'
      @right_cell_text = if @custom_button_set && @custom_button_set.id
                           _("Editing %{model} \"%{name}\"") % {:name  => @custom_button_set.name,
                                                                :model => ui_lookup(:model => "CustomButtonSet")}
                         else
                           _("Adding a new %{model}") % {:model => ui_lookup(:model => "CustomButtonSet")}
                         end
    when 'group_reorder'
      @right_cell_text = _("%{models} Group Reorder") % {:models => ui_lookup(:models => "CustomButton")}
    end

    # Replace right side with based on selected tree node type
    presenter.update(:main_div, render_proc[:partial => "shared/buttons/ab_list"])
    presenter.lock_tree(:ab_tree, @edit)
  end

  def setup_presenter_for_dialog_edit_tree(presenter)
    presenter.update(:main_div, render_proc[:partial => "dialog_form"])
    presenter[:cell_a_view] = 'custom'

    @right_cell_text = if @record.id.blank?
                         _("Adding a new %{model}") % {:model => ui_lookup(:model => "Dialog")}
                       else
                         _("Editing %{model} \"%{name}\"") % {:name  => @record.label.to_s,
                                                              :model => ui_lookup(:model => "Dialog")}
                       end
    @right_cell_text << _(" [%{text} Information]") % {:text => @sb[:txt]}

    # url to be used in url in miqDropComplete method
    presenter[:miq_widget_dd_url] = 'miq_ae_customization/dialog_res_reorder'
    presenter[:init_dashboard] = true
    presenter[:init_accords] = true
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
    presenter.reset_one_trans
    presenter.one_trans_ie if %w(save reset).include?(params[:button]) && is_browser_ie?
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
        @right_cell_text = _("Adding a new %{model}") % {:model => ui_lookup(:model => "MiqDialog")}
      else
        title = if @edit
                  if params[:typ] == "copy"
                    _("Copy ")
                  else
                    _("Editing ")
                  end
                else
                  ""
                end
        @right_cell_text = _("Editing %{model} \"%{name}\"") % {:name => @dialog.description, :model => "#{title} #{ui_lookup(:model => "MiqDialog")}"}
      end

      presenter.reset_one_trans
      presenter.one_trans_ie if %w(save reset).include?(params[:button]) && is_browser_ie?
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
      render_flash(_("Button Group Hover Text is required"), :error)
      return
    end

    super(typ)
  end
end
