class PxeController < ApplicationController
  # Methods for accordions
  include_concern 'PxeServers'
  include_concern 'PxeImageTypes'
  include_concern 'PxeCustomizationTemplates'
  include_concern 'IsoDatastores'

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'explorer'
  end

  PXE_X_BUTTON_ALLOWED_ACTIONS = {
    'pxe_image_edit'                => :pxe_image_edit,
    'pxe_image_type_new'            => :pxe_image_type_new,
    'pxe_image_type_edit'           => :pxe_image_type_edit,
    'pxe_image_type_delete'         => :pxe_image_type_delete,
    'pxe_server_new'                => :pxe_server_new,
    'pxe_server_edit'               => :pxe_server_edit,
    'pxe_server_delete'             => :pxe_server_delete,
    'pxe_server_refresh'            => :pxe_server_refresh,
    'pxe_wimg_edit'                 => :pxe_wimg_edit,
    'iso_datastore_new'             => :iso_datastore_new,
    'iso_datastore_refresh'         => :iso_datastore_refresh,
    'iso_datastore_delete'          => :iso_datastore_delete,
    'iso_image_edit'                => :iso_image_edit,
    'customization_template_new'    => :customization_template_new,
    'customization_template_delete' => :customization_template_delete,
    'customization_template_copy'   => :customization_template_copy,
    'customization_template_edit'   => :customization_template_edit,
  }.freeze

  def x_button
    @sb[:action] = action = params[:pressed]

    raise ActionController::RoutingError.new('invalid button action') unless
      PXE_X_BUTTON_ALLOWED_ACTIONS.key?(action)

    send(PXE_X_BUTTON_ALLOWED_ACTIONS[action])
  end

  def accordion_select
    self.x_active_accord = params[:id].sub(/_accord$/, '')
    self.x_active_tree   = "#{x_active_accord}_tree"
    get_node_info(x_node)
    replace_right_cell(x_node)
  end

  def tree_select
    self.x_active_tree = params[:tree] if params[:tree]
    self.x_node        = params[:id]
    get_node_info(x_node)
    replace_right_cell(x_node)
  end

  def explorer
    @breadcrumbs = []
    @explorer = true

    build_accordions_and_trees

    @right_cell_div ||= "pxe_server_list"
    @right_cell_text ||= _("All PXE Servers")
    @pxe_image_types_count = PxeImageType.count

    render :layout => "application"
  end

  private

  def features
    [{:role     => "pxe_server_accord",
      :role_any => true,
      :name     => :pxe_servers,
      :title    => _("PXE Servers")},

     {:role     => "customization_template_accord",
      :role_any => true,
      :name     => :customization_templates,
      :title    => _("Customization Templates")},

     {:role     => "pxe_image_type_accord",
      :role_any => true,
      :name     => :pxe_image_types,
      :title    => _("System Image Types")},

     {:role     => "iso_datastore_accord",
      :role_any => true,
      :name     => :iso_datastores,
      :title    => _("ISO Datastores")},
    ].map do |hsh|
      ApplicationController::Feature.new_with_hash(hsh)
    end
  end

  def get_node_info(node)
    node = valid_active_node(node)
    case x_active_tree
    when :pxe_servers_tree             then pxe_server_get_node_info(node)
    when :customization_templates_tree then template_get_node_info(node)
    when :pxe_image_types_tree         then pxe_image_type_get_node_info(node)
    when :iso_datastores_tree          then iso_datastore_get_node_info(node)
    end
    x_history_add_item(:id => node, :text => @right_cell_text)
  end

  def replace_right_cell(nodetype, replace_trees = [])
    replace_trees = @replace_trees if @replace_trees  # get_node_info might set this
    # FIXME

    @explorer = true

    trees = {}
    if replace_trees
      trees[:pxe_servers]             = pxe_server_build_tree               if replace_trees.include?(:pxe_servers)
      trees[:pxe_image_types]         = pxe_image_type_build_tree           if replace_trees.include?(:pxe_image_types)
      trees[:customization_templates] = customization_template_build_tree   if replace_trees.include?(:customization_templates)
      trees[:iso_datastores]          = iso_datastore_build_tree            if replace_trees.include?(:iso_datastores)
    end

    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
    )
    r = proc { |opts| render_to_string(opts) }

    c_tb = build_toolbar(center_toolbar_filename) unless @in_a_form
    h_tb = build_toolbar('x_history_tb')

    replace_trees_by_presenter(presenter, trees)

    # Rebuild the toolbars
    presenter.reload_toolbars(:history => h_tb)
    case x_active_tree
    when :pxe_servers_tree
      presenter.update(:main_div, r[:partial => "pxe_server_list"])
      if nodetype == "root"
        right_cell_text = _("All %{models}") % {:models => ui_lookup(:models => "PxeServer")}
      else
        right_cell_text = case nodetype
                          when 'ps'
                            if @ps.id.blank?
                              _("Adding a new %{model}") % {:model => ui_lookup(:model => "PxeServer")}
                            else
                              temp = _("%{model} \"%{name}\"") % {:name  => @ps.name, :model => ui_lookup(:model => "PxeServer")}
                              @edit ? "Editing #{temp}" : temp
                            end
                          when 'pi'
                            _("%{model} \"%{name}\"") % {:name  => @img.name, :model => ui_lookup(:model => "PxeImage")}
                          when 'wi'
                            _("%{model} \"%{name}\"") % {:name  => @wimg.name, :model => ui_lookup(:model => "WindowsImage")}
                          end
      end
    when :pxe_image_types_tree
      presenter.update(:main_div, r[:partial => "pxe_image_type_list"])
      right_cell_text = case nodetype
                        when 'root'
                          _("All %{models}") % {:models => ui_lookup(:models => "PxeImageType")}
                        when 'pit'
                          if @pxe_image_type.id.blank?
                            _("Adding a new %{models}") % {:models => ui_lookup(:model => "PxeImageType")}
                          else
                            temp = _("%{model} \"%{name}\"") % {:name  => @pxe_image_type.name, :model => ui_lookup(:model => "PxeImageType")}
                            @edit ? "Editing #{temp}" : temp
                          end
                        else
                          _("%{model} \"%{name}\"") % {:name  => @pxe_image_type.name, :model => ui_lookup(:model => "PxeImageType")}
                        end
    when :customization_templates_tree
      presenter.update(:main_div, r[:partial => "template_list"])
      nodes = nodetype.split('_')
      if @in_a_form
        right_cell_text =
          if @ct.id.blank?
            _("Adding a new %{model}") % {:model => ui_lookup(:model => "PxeCustomizationTemplate")}
          else
            @edit ? _("Editing %{model} \"%{name}\"") % {:name  => @ct.name, :model => ui_lookup(:model => "PxeCustomizationTemplate")} :
                    _("%{model} \"%{name}\"") % {:name  => @ct.name, :model => ui_lookup(:model => "PxeCustomizationTemplate")}
          end
        # resetting ManageIQ.oneTransition.oneTrans when tab loads
        presenter.reset_one_trans
        presenter.one_trans_ie if %w(save reset).include?(params[:button]) && is_browser_ie?
      end
    when :iso_datastores_tree
      presenter.update(:main_div, r[:partial => "iso_datastore_list"])
      right_cell_text =
        case nodetype
        when 'root' then _("All %{models}") % {:models => ui_lookup(:models => "IsoDatastore")}
        when 'isd'  then _("Adding a new %{models}") % {:models => ui_lookup(:model => "IsoDatastore")}
        when 'isi'  then _("%{model} \"%{name}\"") % {:name => @img.name, :model => ui_lookup(:model => "IsoImage")}
        end
    end

    # forcing form buttons to turn off, to prevent Abandon changes popup when replacing right cell after form button was pressed
    presenter[:reload_toolbars][:center] = c_tb if c_tb.present?
    presenter.set_visibility(c_tb.present?, :toolbar)

    # FIXME: check where @right_cell_text is set and replace that with loca variable
    presenter[:right_cell_text] = right_cell_text || @right_cell_text

    if !@view || @in_a_form ||
       (@pages && (@items_per_page == ONE_MILLION || @pages[:items] == 0))
      if @in_a_form
        presenter.hide(:toolbar)
        # in case it was hidden for summary screen, and incase there were no records on show_list
        presenter.show(:paging_div, :form_buttons_div)

        action_url, multi_record = case x_active_tree
                                   when :pxe_servers_tree
                                     if x_node == 'root'
                                       "pxe_server_create_update"
                                     else
                                       case x_node.split('-').first
                                       when 'pi' then ["pxe_image_edit", true]
                                       when 'wi' then ["pxe_wimg_edit",  true]
                                       else "pxe_server_create_update"
                                       end
                                     end
                                   when :iso_datastores_tree
                                     if x_node == "root"
                                       "iso_datastore_create"
                                     else
                                       if x_node.split('-').first == "isi"
                                         ["iso_image_edit", true]
                                       else
                                         "iso_datastore_create"
                                       end
                                     end
                                   when :pxe_image_types_tree
                                     "pxe_image_type_edit"
                                   else
                                     "template_create_update"
                                   end

        presenter.update(:form_buttons_div, r[
          :partial => "layouts/x_edit_buttons",
          :locals  => {
            :record_id    => @edit[:rec_id],
            :action_url   => action_url,
            :multi_record => multi_record,
            :serialize    => true
          }
        ])
      else
        presenter.hide(:form_buttons_div)
      end
      presenter.hide(:pc_div_1)
    else
      presenter.hide(:form_buttons_div).show(:pc_div_1)
    end

    presenter[:record_id] = determine_record_id_for_presenter

    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'

    # Save open nodes, if any were added
    presenter[:osf_node] = x_node
    presenter.lock_tree(x_active_tree, @in_a_form && @edit)

    render :json => presenter.for_render
  end

  def get_session_data
    @title        = "PXE"
    @layout       = "pxe"
    @lastaction   = session[:pxe_lastaction]
    @display      = session[:pxe_display]
    @current_page = session[:pxe_current_page]
  end

  def set_session_data
    session[:pxe_lastaction]   = @lastaction
    session[:pxe_current_page] = @current_page
    session[:pxe_display]      = @display unless @display.nil?
  end
end
