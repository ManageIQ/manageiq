require "rexml/document"
class MiqAeClassController < ApplicationController
  include MiqAeClassHelper

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  # GET /automation_classes
  # GET /automation_classes.xml
  def index
    redirect_to :action => 'explorer'
  end

  def change_tab
    #resetting flash array so messages don't get displayed when tab is changed
    @flash_array = Array.new
    @explorer = true
    @ae_class = MiqAeClass.find_by_id(from_cid(@edit[:ae_class_id]))
    @sb[:active_tab] = params[:tab_id]
    c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename)
    case params[:tab_id]
      when "instances"
        div_suffix = "_class_instances"
      when "methods"
        div_suffix = "_class_methods"
      when "props"
        div_suffix = "_class_props"
      when "schema"
        div_suffix = "_class_fields"
    end
    render :update do |page|                      # Use JS to update the display
      page.replace("flash_msg_div#{div_suffix}", :partial=>"layouts/flash_msg", :locals=>{:div_num=>div_suffix})
      if c_buttons && c_xml
        page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
        page << "$('center_buttons_div').show();"
      else
        page << "$('center_buttons_div').hide();"
      end
      page << "miqSparkle(false);"
    end
  end

  AE_X_BUTTON_ALLOWED_ACTIONS = {
    'instance_fields_edit'        => :edit_instance,
    'method_inputs_edit'          => :edit_mehod,
    'miq_ae_class_edit'           => :edit_class,
    'miq_ae_class_delete'         => :deleteclasses,
    'miq_ae_class_new'            => :new,
    'miq_ae_domain_delete'        => :delete_domain,
    'miq_ae_domain_edit'          => :edit_domain,
    'miq_ae_domain_lock'          => :domain_lock,
    'miq_ae_domain_unlock'        => :domain_unlock,
    'miq_ae_domain_new'           => :new_domain,
    'miq_ae_domain_priority_edit' => :domains_priority_edit,
    'miq_ae_field_edit'           => :edit_fields,
    'miq_ae_field_seq'            => :fields_seq_edit,
    'miq_ae_instance_delete'      => :deleteinstances,
    'miq_ae_instance_edit'        => :edit_instance,
    'miq_ae_instance_new'         => :new_instance,
    'miq_ae_item_edit'            => :edit_item,
    'miq_ae_method_delete'        => :deletemethods,
    'miq_ae_method_edit'          => :edit_method,
    'miq_ae_method_new'           => :new_method,
    'miq_ae_namespace_delete'     => :delete_ns,
    'miq_ae_namespace_edit'       => :edit_ns,
    'miq_ae_namespace_new'        => :new_ns,
  }.freeze

  def x_button
    @sb[:action] = action = params[:pressed]
    raise ActionController::RoutingError, I18n.t("flash.invalid_button_action") unless
        AE_X_BUTTON_ALLOWED_ACTIONS.key?(action)
    send(AE_X_BUTTON_ALLOWED_ACTIONS[action])
  end

  def explorer
    @built_trees = []
    @sb[:open_tree_nodes] ||= Array.new # Create array to keep open tree nodes (only for autoload trees)
    @explorer = true
    #don't need right bottom cell
    @collapse_c_cell = true
    @breadcrumbs = Array.new
    bc_name = "Explorer"
    bc_name += " (filtered)" if @filters && (!@filters[:tags].blank? || !@filters[:cats].blank?)
    drop_breadcrumb( {:name=>bc_name, :url=>"/miq_ae_class/explorer"} )
    @lastaction = "replace_right_cell"
    @ns_ids = Array.new                     # Capture all VM ids in the tree
    @trees = Array.new
    @accords = Array.new
    self.x_active_tree = :ae_tree
    tree = build_ae_tree
    @built_trees << tree
    @accords << {:name => "datastores", :title => "Datastore", :container => "ae_tree_div", :image => "folder"}
    @sb[:active_accord] = :ae
    @sb[:active_tab] ||= "namespaces"
    self.x_node ||= "root"
    @right_cell_text ||= "Datastore"
    get_node_info(x_node)
    render :layout => "explorer"
  end

  def set_right_cell_text(id,rec=nil)
    nodes = id.split('-')
    case nodes[0]
    when "root"
      txt = "Datastore"
      @sb[:namespace_path] = ""
    when "aec"
      txt =  ui_lookup(:model=>"MiqAeClass")
      @sb[:namespace_path] = rec.fqname
    when "aei"
      txt = ui_lookup(:model=>"MiqAeInstance")
      updated_by = rec.updated_by ? " by #{rec.updated_by}" : ""
      @sb[:namespace_path] = rec.fqname
      @right_cell_text = txt +
          " [" + get_rec_name(rec) + " - Updated " + format_timezone(rec.created_on, Time.zone, "gtl") +
          updated_by + "]"
    when "aem"
      txt = ui_lookup(:model=>"MiqAeMethod")
      updated_by = rec.updated_by ? " by #{rec.updated_by}" : ""
      @sb[:namespace_path] = rec.fqname
      @right_cell_text = txt + " [" + get_rec_name(rec) +
          " - Updated " + format_timezone(rec.created_on, Time.zone, "gtl") +
          updated_by + "]"
    when "aen"
      txt = ui_lookup(:model=>"MiqAeNamespace")
      @sb[:namespace_path] = rec.fqname
    end
    @sb[:namespace_path].gsub!(/\//," / ") if @sb[:namespace_path]
    @right_cell_text = "#{txt} \
      #{I18n.t("cell_header.name", :name => get_rec_name(rec))}" unless %w(root aei aem).include?(nodes[0])
  end

  def expand_toggle
    render :update do |page|                                # Use RJS to update the display
      if @sb[:squash_state]
        @sb[:squash_state] = false
        page << "$('inputs_div').show();"
        page << "$('exp_collapse_img').src='/images/toolbars/squashed-false.png';"
        page << "$('exp_collapse_img').title='Hide Input Parameters';"
        page << "$('exp_collapse_img').alt='Hide Input Parameters';"
      else
        @sb[:squash_state] = true
        page << "$('inputs_div').hide();"
        page << "$('exp_collapse_img').src='/images/toolbars/squashed-true.png';"
        page << "$('exp_collapse_img').title='Show Input Parameters';"
        page << "$('exp_collapse_img').alt='Show Input Parameters';"
      end
    end
  end

  #reset node to root node when previously viewed item no longer exists
  def set_root_node
    self.x_node = "root"
    get_node_info(x_node)
  end

	def get_node_info(node)
    id = valid_active_node(node).split('-')
    @sb[:row_selected] = nil if params[:action] == "tree_select"
    if @button != "reset" && !params[:pressed]
      @edit = Hash.new
      @edit[:current] = Hash.new
      @edit[:new] = Hash.new
      @edit[:new][:ae_ns] = MiqAeNamespace.new
      @edit[:new][:ae_inst] = Hash.new
      @edit[:new][:ae_method] = MiqAeMethod.new
    end
    case id[0]
      when "aec"
        @sb[:active_tab] = "instances" if !@in_a_form && !params[:button] && !params[:pressed]
        @record = @ae_class = MiqAeClass.find_by_id(from_cid(id[1]))
        @edit[:ae_class_id] = @ae_class.id
        if @ae_class.nil?
          set_root_node
        else
          @edit[:grid_inst_list_xml] = build_details_grid(@ae_class.ae_instances)
          @temp[:combo_xml] = get_combo_xml(@ae_class.ae_fields)
          @temp[:dtype_combo_xml] = get_dtype_combo_xml(@ae_class.ae_fields)    # passing fields because that's how many combo boxes we need
          @edit[:grid_methods_list_xml] = build_details_grid(@ae_class.ae_methods)
          set_right_cell_text(x_node,@ae_class)
        end
      when "aei"
        @record = MiqAeInstance.find_by_id(from_cid(id[1]))
        if @record.nil?
          set_root_node
        else
          @edit[:new][:ae_inst][:name]         = @record.name
          @edit[:new][:ae_inst][:display_name] = @record.display_name
          @edit[:new][:ae_inst][:description]  = @record.description
          @ae_class             = @record.ae_class
          @edit[:ae_class_id]   = @ae_class.id
          @edit[:grid_inst_xml] = build_fields_grid(@ae_class.ae_fields, @record)
          @sb[:active_tab]      = "instances"
          set_right_cell_text(x_node, @record)
        end
      when "aem"
        @record = @edit[:new][:ae_method] = @ae_method = MiqAeMethod.find_by_id(from_cid(id[1]))
        if @edit[:new][:ae_method].nil?
          set_root_node
        else
          @ae_class = @edit[:new][:ae_method].ae_class
          @edit[:ae_class_id] = @ae_class.id
          inputs = @edit[:new][:ae_method].inputs
          @edit[:grid_methods_xml] = inputs.blank? ? nil : build_methods_grid(inputs)
          @sb[:squash_state] = true
          @sb[:active_tab] = "methods"
          set_right_cell_text(x_node,@edit[:new][:ae_method])
        end
      when "aen"
        @record = MiqAeNamespace.find_by_id(from_cid(id[1]))
        if @record.nil?
          set_root_node
        else
          records = Array.new
          # Add Namespaces under a namespace
          details = MiqAeNamespace.all(:conditions => {:parent_id => @record.id.to_i})
          details.flatten.sort{|a,b| a.display_name.to_s + a.name.to_s <=> b.display_name.to_s + b.name.to_s}.each do |r|
            records.push(r)
          end
          # Add classes under a namespace
          details_cls = @record.ae_classes
          if !details_cls.nil?
            details_cls.flatten.sort{|a,b| a.display_name.to_s + a.name.to_s <=> b.display_name.to_s + b.name.to_s}.each do |r|
              records.push(r)
            end
          end
          @temp[:grid_ns_xml] = build_details_grid(records,false)
          @temp[:combo_xml] = get_combo_xml([MiqAeField.new])
          @temp[:dtype_combo_xml] = get_dtype_combo_xml([MiqAeField.new])   # passing fields because that's how many combo boxes we need
          @sb[:active_tab] = "details"
          set_right_cell_text(x_node, @record)
        end
      else
        rec = MiqAeNamespace.all(:conditions => {:parent_id=>nil})
        @record = nil
        @temp[:grid_xml] = build_toplevel_grid(rec)
        @right_cell_text = "Datastore"
        @sb[:active_tab] = "namespaces"
        set_right_cell_text(x_node)
    end
    x_history_add_item(:id=>x_node, :text=>@right_cell_text)
	end

  # Tree node selected in explorer
  def tree_select
    @explorer = true
    @lastaction = "explorer"
    self.x_active_tree = params[:tree] if params[:tree]
    self.x_node = params[:id]
    @sb[:action] = nil
    replace_right_cell
  end

  def replace_right_cell(replace_trees = [])
    @explorer = true

    # fixme: is the following line needed?
    #replace_trees = @replace_trees if @replace_trees  #get_node_info might set this

    nodes = x_node.split('-')

    @in_a_form = @in_a_form_fields = @in_a_form_props = false if params[:button] == "cancel" ||
                    (["save","add"].include?(params[:button]) && replace_trees)
    get_node_info(x_node) if !@in_a_form && @button != "reset"
    ae_tree = build_ae_tree if replace_trees

    c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename) if !@in_a_form
    h_buttons, h_xml = build_toolbar_buttons_and_xml("x_history_tb")

    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
      :temp        => @temp,
    )
    r = proc { |opts| render_to_string(opts) }

    presenter[:save_open_states_trees] << :ae_tree
    presenter[:right_cell_text] = @right_cell_text

    # Build hash of trees to replace and optional new node to be selected
    replace_trees.each do |t|
      presenter[:replace_partials]["#{t}_tree_div".to_sym] = r[
        :partial => 'shared/tree',
        :locals  => {:tree => ae_tree,
                     :name => ae_tree.name.to_s
        }
      ]
    end

    if @sb[:action] == "miq_ae_field_seq"
      presenter[:replace_partials][:flash_msg_div_fields_seq] = r[
        :partial => "layouts/flash_msg",
        :locals  => {:div_num=>"_fields_seq"}
      ] if @flash_array
      presenter[:update_partials][:class_fields_div] = r[:partial => "fields_seq_form"]
    elsif @sb[:action] == "miq_ae_domain_priority_edit"
      presenter[:replace_partials][:flash_msg_div_domains_priority] = r[
          :partial => "layouts/flash_msg",
          :locals  => {:div_num => "_domains_priority"}
      ] if @flash_array
      presenter[:update_partials][:ns_list_div] = r[:partial => "domains_priority_form"]
    else
      if @sb[:action] == "miq_ae_class_edit"
        @sb[:active_tab] = 'props'
      else
        @sb[:active_tab] ||= 'instances'
      end
      presenter[:update_partials][:main_div] = r[:partial=>"all_tabs"]
    end
    if @in_a_form
      action_url =  create_action_url(nodes.first)
      presenter[:expand_collapse_cells][:c] = 'expand' # incase it was collapsed for summary screen, and incase there were no records on show_list
      presenter[:set_visible_elements][:form_buttons_div] = true
      presenter[:update_partials][:form_buttons_div] = r[
        :partial => "layouts/x_edit_buttons",
        :locals  => {
          :record_id    => @edit[:rec_id],
          :action_url   => action_url,
          :multi_record => @sb[:action] == "miq_ae_domain_priority_edit",
          :serialize    => @sb[:active_tab] == 'methods',
        }
      ]
    else
      # incase it was collapsed for summary screen, and incase there were no records on show_list
      presenter[:expand_collapse_cells][:c] = 'collapse'
      presenter[:set_visible_elements][:form_buttons_div] = false
    end

    presenter[:lock_unlock_trees][x_active_tree] = @in_a_form && @edit

    if !@in_a_form || (params[:pressed] && params[:pressed].ends_with?("_delete"))
      presenter[:set_visible_elements][:params_div] =
        !!(@sb[:active_tab] == "methods" && @edit[:grid_methods_xml])
    end

    # Clear the JS gtl_list_grid var if changing to a type other than list
    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'

    # Rebuild the toolbars
    presenter[:reload_toolbars][:history] = { :buttons => h_buttons, :xml => h_xml }
    if c_buttons && c_xml
      presenter[:expand_collapse_cells][:a] = 'expand'
      presenter[:reload_toolbars][:center] = { :buttons => c_buttons, :xml => c_xml }
      presenter[:set_visible_elements][:center_buttons_div] = true
    else
      presenter[:expand_collapse_cells][:a] = 'collapse'
      presenter[:set_visible_elements][:center_buttons_div] = false
    end

    presenter[:miq_record_id] = @record && !@in_a_form ? @record.id : @edit && @edit[:rec_id] && @in_a_form ? @edit[:rec_id] : nil
    presenter[:osf_node] = x_node
    presenter[:extra_js] << "miqButtons('hide');"

    # Render the JS responses to update the explorer screen
    render :js => presenter.to_html
  end

  def get_combo_xml(fields)
    aetypes = MiqAeField.available_aetypes
    combo_xml = Array.new
    fields.each do |fld|
      xml = REXML::Document.load("")
      xml << REXML::XMLDecl.new(1.0, "UTF-8")
      # Create root element
      root = xml.add_element("complete")
      if fld.aetype.blank? && (session[:field_data].blank? || session[:field_data][:aetype].blank?)
        fld.aetype = "attribute"
      elsif !session[:field_data].blank? && !session[:field_data][:aetype].blank?
        fld.aetype = session[:field_data][:aetype]
      end
      aetypes.each do |aetype|
        opt = root.add_element("option", {"value"=>aetype,"img_src"=>"/images/icons/new/16_ae_#{aetype}.png"})
        if fld.aetype == aetype
          opt.add_attribute("selected","true")
        end
        opt.text = aetype.titleize
      end
      combo_xml.push(xml.to_s)
    end
    return combo_xml
  end

  def get_dtype_combo_xml(fields)
    dtypes = MiqAeField.available_datatypes_for_ui
    combo_xml = Array.new
    fields.each do |fld|
      xml = REXML::Document.load("")
      xml << REXML::XMLDecl.new(1.0, "UTF-8")
      # Create root element
      root = xml.add_element("complete")
      if fld.datatype.blank? && (session[:field_data].blank? || session[:field_data][:datatype].blank?)
        fld.datatype = "string"
      elsif !session[:field_data].blank? && !session[:field_data][:datatype].blank?
        fld.datatype = session[:field_data][:datatype]
      end
      dtypes.each do |dtype|
        opt = root.add_element("option", {"value"=>dtype,"img_src"=>"/images/icons/new/#{dtype}.png", "img_style"=>"height:16px;width:16px"})
        if fld.datatype == dtype
          opt.add_attribute("selected","true")
        end
        opt.text = dtype.titleize
      end
      combo_xml.push(xml.to_s)
    end
    return combo_xml
  end

  def set_cls(cls)
    case cls.to_s.split("::").last
    when "MiqAeClass"
      cls = "aec"
      img_name = "ae_class"
    when "MiqAeNamespace"
      cls = "aen"
      img_name = "ae_namespace"
    when "MiqAeInstance"
      cls = "aei"
      img_name = "ae_instance"
    when "MiqAeField"
      cls = "Field"
      img_name = "ae_field"
    when "MiqAeMethod"
      cls = "aem"
      img_name = "ae_method"
    end
    return cls, img_name
  end

  def build_details_grid(view,mode=true)
    xml = REXML::Document.load("")
    xml << REXML::XMLDecl.new(1.0, "UTF-8")

    # Create root element
    root = xml.add_element("rows")
    # Build the header row
    head = root.add_element("head")
    header = ""
    new_column = head.add_element("column", {"type"=>"ch", "width"=>25, "align"=>"center"}) # Checkbox column
    new_column = head.add_element("column", {"width"=>"30","align"=>"left", "sort"=>"na"})
    new_column.add_attribute("type", 'ro')
    new_column.text = header
    new_column = head.add_element("column", {"width"=>"*","align"=>"left", "sort"=>"na"})
    new_column.add_attribute("type", 'ro')
    new_column.text = header

    records = Array.new
    # passing in mode, don't need to sort records for namaspace node, it will be passed in sorted order, need to show Namesaces first and then Classes
    if mode
      view.flatten.sort{|a,b| a.display_name.to_s + a.name.to_s <=> b.display_name.to_s + b.name.to_s}.each do |r|
        records.push(r)
      end
    else
        records = view
    end
    records.each do |kids|
      cls,img_name = set_cls(kids.class)
      rec_name = get_rec_name(kids)
      if rec_name
        rec_name = rec_name.gsub(/\n/,"\\n")
        rec_name = rec_name.gsub(/\t/,"\\t")
        rec_name = rec_name.gsub(/"/,"'")
        rec_name = CGI.escapeHTML(rec_name)
        rec_name = rec_name.gsub(/\\/,"&#92;")
      end
      srow = root.add_element("row", {"id"=>"#{cls}-#{to_cid(kids.id)}", "style"=>"border-bottom: 1px solid #CCCCCC;color:black; text-align: center"})
      srow.add_element("cell").text = "0" # Checkbox column unchecked
      srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{cls}","style"=>"border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = REXML::CData.new("<img src='/images/icons/new/#{img_name}.png' border='0' height='20', width='20', align='middle' alt='#{cls}' title='#{cls}'>")
      srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{rec_name}","style"=>"border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = rec_name
    end
    return xml.to_s
  end

  def build_toplevel_grid(view)
    xml = REXML::Document.load("")
    xml << REXML::XMLDecl.new(1.0, "UTF-8")

    # Create root element
    root = xml.add_element("rows")
    # Build the header row
    head = root.add_element("head")
    toplevel_grid_add_header(head)
    toplevel_grid_add_rows(root, view)
    xml.to_s
  end

  def toplevel_grid_add_header(hrow)
    new_column = hrow.add_element("column", "type" => "ch", "width" => 25, "align" => "center")
    ["", "Name", "Description", "Enabled"].each do |col|
      width = col == "" ? "30" : "*"
      new_column = hrow.add_element("column", "width" => width, "align" => "left", "sort" => "na")
      new_column.add_attribute("type", 'ro')
      new_column.text = col
    end
  end

  def toplevel_grid_add_rows(root, view)
    view.flatten.sort_by { |a| a.priority.to_s }.reverse.each do |kids|
      next if kids[:name] == "$"  # Skip the build-in namespace
      cls, _ = set_cls(kids.class)
      rec_name = get_rec_name(kids)
      if rec_name
        rec_name = rec_name.gsub(/\n/, "\\n")
        rec_name = rec_name.gsub(/\t/, "\\t")
        rec_name = rec_name.gsub(/"/, "'")
        rec_name = CGI.escapeHTML(rec_name)
        rec_name = rec_name.gsub(/\\/, "&#92;")
      end
      srow = root.add_element("row",
                              "id"    => "#{cls}-#{to_cid(kids.id)}",
                              "style" => "border-bottom: 1px solid #CCCCCC;color:black; text-align: center")
      toplevel_grid_add_row_data(srow, kids, cls, rec_name)
    end
  end

  def toplevel_grid_add_row_data(srow, kids, cls, rec_name)
    srow.add_element("cell").text = "0" # Checkbox column unchecked
    srow.add_element("cell",
                     "image" => "blank.png",
                     "title" => "#{cls}",
                     "style" => "border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;").text = \
                     REXML::CData.new("<img src='/images/icons/new/ae_domain.png' border='0' height='20', \
                       width='20', align='middle' alt='#{cls}' title='#{cls}'>")
    srow.add_element("cell",
                     "image" => "blank.png",
                     "title" => "#{rec_name}",
                     "style" => "border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;").text = rec_name
    %w(description enabled).each do |field|
      srow.add_element("cell",
                       "image" => "blank.png",
                       "title" => "#{kids.send(field)}",
                       "style" => "border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;").text = \
                       kids.send(field)
    end
  end

  def grid_add_header(head)
    col_width = 900 / 7
    columns = ["Name", "Value", "On Entry", "On Exit", "Collect", "Max Retries", "Max Time", "Message"]

    columns.each do |column|
      options = {"width" => "#{col_width}", "sort" => "na"}
      options.merge!("align" => "left") if %w(Name Value).include?(column)
      new_column = head.add_element("column", options)
      new_column.add_attribute("type", 'ro')
      new_column.text = column
    end
  end

  def build_fields_grid(view,inst)
    xml = REXML::Document.load("")
    xml << REXML::XMLDecl.new(1.0, "UTF-8")

    # Create root element
    root = xml.add_element("rows")
    # Build the header row
    hrow = root.add_element("head")
    grid_add_header(hrow)

    view.flatten.sort_by{|a| [a.priority.to_i]}.each do |kids|
      cls,img_name = set_cls(kids.class)
      img_name = "ae_#{kids.aetype}"

      if kids.substitute
        substitute_img = "passed"
      else
        substitute_img = "failed"
      end

      kids.datatype = kids.datatype == nil ? "string" : kids.datatype

      val = MiqAeValue.find_by_instance_id_and_field_id(inst.id,kids.id)
      if val.nil?
        val = MiqAeValue.new
        val.field_id = kids.id.to_i
        val.instance_id = inst.id.to_i
      end
      field_val = val.value
      rec_name = get_rec_name(kids)
      def_val = kids.default_value
      if kids.default_value && kids.datatype != "password"
        def_val.gsub!(/\n/,"\\n")
        def_val.gsub!(/\t/,"\\t")
        def_val.gsub!(/"/,"'")
        def_val = CGI.escapeHTML(kids.default_value)
        def_val.gsub!(/\\/,"&#92;")
      elsif kids.default_value && kids.datatype == "password"
        def_val = "********"
      end

      if field_val && kids.datatype != "password"
        field_val.gsub!(/\n/,"\\n")
        field_val.gsub!(/\t/,"\\t")
        field_val.gsub!(/"/,"'")
        field_val = CGI.escapeHTML(field_val)
        field_val.gsub!(/\\/,"&#92;")
      elsif field_val && kids.datatype == "password"
        field_val = "********"
      end
      if !def_val.blank? || !field_val.blank? || !kids.collect.blank? || !val.collect.blank?  || !kids.on_entry.blank? || !val.on_entry.blank? || !kids.on_exit.blank? || !val.on_exit.blank? || !kids.on_error.blank? || !val.on_error.blank? || !kids.max_retries.blank? || !val.max_retries.blank? || !kids.max_time.blank? || !val.max_time.blank?
        srow = root.add_element("row", {"id"=>"#{cls}-#{to_cid(kids.id)}", "style"=>"border-bottom: 1px solid #CCCCCC;color:black; text-align: center"})
        if kids.datatype != "string"
          srow.add_element("cell", {"image"=>"blank.png", "title"=>"Type: #{kids.aetype}, Data Type: #{kids.datatype}, Substitution: #{kids.substitute}, #{rec_name}","style"=>"border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = REXML::CData.new("<img src='/images/icons/new/#{img_name}.png' height='20', width='20', border='0' align='middle' alt='Type: #{kids.aetype}' title='Type: #{kids.aetype}'>&nbsp;<img src='/images/icons/new/#{kids.datatype}.png' height='20', width='20', border='0' align='middle' alt='Data Type: #{kids.datatype}' title='Data Type: #{kids.datatype}'>&nbsp;<img src='/images/icons/16/#{substitute_img}.png' height='20', width='20', border='0' align='middle' alt='Substitution: #{kids.substitute}' title='Substitution: #{kids.substitute}'>&nbsp; #{rec_name}")
        else
          srow.add_element("cell", {"image"=>"blank.png", "title"=>"Type: #{kids.aetype}, Substitution: #{kids.substitute}, #{rec_name}","style"=>"border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = REXML::CData.new("<img src='/images/icons/new/#{img_name}.png' height='20', width='20', border='0' align='middle' alt='Type: #{kids.aetype}' title='Type: #{kids.aetype}'>&nbsp;<img src='/images/icons/16/#{substitute_img}.png' height='20', width='20', border='0' align='middle' alt='Substitution: #{kids.substitute}' title='Substitution: #{kids.substitute}'>&nbsp; #{rec_name}")
        end
        clr = val.value.nil? || val.value == "" ? "#a8a8a8" : "#000000"
        value = val.value.nil? || val.value == "" ? (kids.datatype == "password" ? "********" : kids.default_value) : (kids.datatype == "password" ? "********" : val.value)
        srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{field_val}","style"=>"color: #{clr}; border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = value
        clr = val.on_entry.nil? || val.on_entry == "" ? "#a8a8a8" : "#000000"
        on_entry = val.on_entry.nil? || val.on_entry == "" ? kids.on_entry : val.on_entry
        srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{val.on_entry}","style"=>"color: #{clr}; border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = on_entry
        clr = val.on_exit.nil? || val.on_exit == "" ? "#a8a8a8" : "#000000"
        on_exit = val.on_exit.nil? || val.on_exit == "" ? kids.on_exit : val.on_exit
        srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{val.on_exit}","style"=>"color: #{clr}; border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = on_exit
        clr = val.on_error.nil? || val.on_error == "" ? "#a8a8a8" : "#000000"
        on_error = val.on_error.nil? || val.on_error == "" ? kids.on_error : val.on_error
        srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{val.on_error}","style"=>"color: #{clr}; border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = on_error
        clr = val.collect.nil? || val.collect == "" ? "#a8a8a8" : "#000000"
        collect = val.collect.nil? || val.collect == "" ? kids.collect : val.collect
        srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{val.collect}","style"=>"color: #{clr}; border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = collect
        clr = val.max_retries.nil? || val.max_retries == "" ? "#a8a8a8" : "#000000"
        max_retries = val.max_retries.nil? || val.max_retries == "" ? kids.max_retries : val.max_retries
        srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{val.on_entry}","style"=>"color: #{clr}; border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = max_retries
        clr = val.max_time.nil? || val.max_time == "" ? "#a8a8a8" : "#000000"
        max_time = val.max_time.nil? || val.max_time == "" ? kids.max_time : val.max_time
        srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{val.on_entry}","style"=>"color: #{clr}; border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = max_time
        srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{kids.message}","style"=>"border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = kids.message
      end
    end
    return xml.to_s
  end

  def build_methods_grid(view)
    xml = REXML::Document.load("")
    xml << REXML::XMLDecl.new(1.0, "UTF-8")

    # Create root element
    root = xml.add_element("rows")
    # Build the header row
    head = root.add_element("head")
    new_column = head.add_element("column", {"width"=>"*","align"=>"left", "sort"=>"na"})
    new_column.add_attribute("type", 'ro')
    new_column.text = "Input Name"
    new_column = head.add_element("column", {"width"=>"*","align"=>"left", "sort"=>"na"})
    new_column.add_attribute("type", 'ro')
    new_column.text = "Default Value"
    new_column = head.add_element("column", {"width"=>"*","align"=>"left", "sort"=>"na"})
    new_column.add_attribute("type", 'ro')
    new_column.text = "Data Type"

    view.flatten.sort_by{|a| [a.priority.to_i]}.each do |kids|
      cls,img_name = set_cls(kids.class)
      rec_name = get_rec_name(kids)
      def_val = kids.default_value
      data_type = kids.datatype ? kids.datatype : "string"
      if kids.default_value && kids.datatype != "password"
        def_val.gsub!(/\n/,"\\n")
        def_val.gsub!(/\t/,"\\t")
        def_val.gsub!(/"/,"'")
        kids.default_value = CGI.escapeHTML(kids.default_value)
        def_val.gsub!(/\\/,"&#92;")
      elsif kids.default_value && kids.datatype == "password"
        def_val = "********"
      end
      srow = root.add_element("row", {"id"=>"#{cls}-#{to_cid(kids.id)}", "style"=>"border-bottom: 1px solid #CCCCCC;color:black; text-align: center"})
      srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{rec_name}","style"=>"border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = rec_name
      srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{def_val}","style"=>"border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = def_val
      srow.add_element("cell", {"image"=>"blank.png", "title"=>"#{kids.datatype}","style"=>"border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;"}).text = data_type
    end
    return xml.to_s
  end

  def edit_item
    item = find_checked_items
    @sb[:row_selected] = item[0]
    if @sb[:row_selected].split('-')[0] == "aec"
      edit_class
    else
      edit_ns
    end
  end

  def edit_class
    assert_privileges("miq_ae_class_edit")
    if params[:pressed] == "miq_ae_item_edit"       # came from Namespace details screen
      id = @sb[:row_selected].split('-')
      @ae_class = MiqAeClass.find(from_cid(id[1]))
    else
      @ae_class = MiqAeClass.find(params[:id].to_i)
    end
    set_form_vars
    # have to get name and set node info, to load multiple tabs correctly
    #rec_name = get_rec_name(@ae_class)
    #get_node_info("aec-#{to_cid(@ae_class.id)}")
    @in_a_form = true
    @in_a_form_props = true
    session[:changed] = @changed = false
    replace_right_cell
  end

  def edit_fields
    assert_privileges("miq_ae_field_edit")
    if params[:pressed] == "miq_ae_item_edit"       # came from Namespace details screen
      id = @sb[:row_selected].split('-')
      @ae_class = MiqAeClass.find(from_cid(id[1]))
    else
      @ae_class = MiqAeClass.find(params[:id].to_i)
    end
    fields_set_form_vars
    @in_a_form = true
    @in_a_form_fields = true
    session[:changed] = @changed = false
    replace_right_cell
  end

  def edit_domain
    assert_privileges("miq_ae_domain_edit")
    edit_domain_or_namespace
  end

  def edit_ns
    assert_privileges("miq_ae_namespace_edit")
    edit_domain_or_namespace
  end

  def edit_instance
    assert_privileges("miq_ae_instance_edit")
    obj = find_checked_items
    if !obj.blank?
      @sb[:row_selected] = obj[0]
      id = @sb[:row_selected].split('-')
    else
      id = x_node.split('-')
    end
    @ae_inst = MiqAeInstance.find(from_cid(id[1]))
    initial_setup_for_instances_form_vars(@ae_inst)
    set_instances_form_vars
    @in_a_form = true
    session[:changed] = @changed = false
    replace_right_cell
  end

  def edit_method
    assert_privileges("miq_ae_method_edit")
    obj = find_checked_items
    if !obj.blank?
      @sb[:row_selected] = obj[0]
      id = @sb[:row_selected].split('-')
    else
      id = x_node.split('-')
    end
    @ae_method = MiqAeMethod.find(from_cid(id[1]))
    set_method_form_vars
    @in_a_form = true
    session[:changed] = @changed = false
    replace_right_cell
  end

  # Set form variables for edit
  def set_instances_form_vars
    session[:inst_data] = Hash.new
    @ae_class = MiqAeClass.find_by_id(from_cid(@edit[:ae_class_id]))
    @edit = {
      :ae_inst_id  => @ae_inst.id,
      :ae_class_id => @ae_class.id,
      :rec_id      => @ae_inst.id || nil,
      :key         => "aeinst_edit__#{@ae_inst.id || "new"}",
      :new         => {}
    }
    @edit[:new][:ae_inst]   = {}
    @edit[:new][:ae_values] = []
    @edit[:new][:ae_fields] = []
    instance_column_names.each do |fld|
      @edit[:new][:ae_inst][fld] = @ae_inst.send(fld)
    end

    @ae_values.each do |ae_value|
      values = {}
      value_column_names.each do |fld|
        values[fld] = ae_value.send(fld)
      end
      @edit[:new][:ae_values].push(values)
    end

    @ae_class.ae_fields.each do |ae_field|
      field = {}
      field_column_names.each do |fld|
        field[fld] = ae_field.send(fld)
      end
      @edit[:new][:ae_fields].push(field)
    end

    @edit[:current] = copy_hash(@edit[:new])
    @right_cell_text = @edit[:rec_id].nil? ?
        I18n.t("cell_header.adding_model_record",:model=>ui_lookup(:model=>"MiqAeInstance")) :
        I18n.t("cell_header.editing_model_record",:model=>ui_lookup(:model=>"MiqAeInstance"), :name=>@ae_inst.name)
    session[:edit] = @edit
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_instance_field_changed
    return unless load_edit("aeinst_edit__#{params[:id]}","replace_cell__explorer")
    get_instances_form_vars

    render :update do |page|                    # Use JS to update the display

      params.each do |var, val|
        # for instance tab on class screen
        if var.starts_with?("cls_inst_value") || var.starts_with?("cls_inst_password_value") ||
            var.starts_with?("cls_inst_collect") || var.starts_with?("cls_inst_on_entry") ||
            var.starts_with?("cls_inst_on_exit") || var.starts_with?("cls_inst_on_error") ||
            var.starts_with?("cls_inst_max_retries") || var.starts_with?("cls_inst_max_time")
          @ae_class.ae_fields.sort! { |a,b| a.priority.to_i <=> b.priority.to_i } if @ae_class
        end
        # for instance node selected in the left tree
        if var.starts_with?("inst_value") || var.starts_with?("inst_password_value") ||
            var.starts_with?("inst_collect") || var.starts_with?("inst_on_entry") ||
            var.starts_with?("inst_on_exit") || var.starts_with?("inst_on_error") ||
            var.starts_with?("inst_max_retries") || var.starts_with?("inst_max_time")
          @ae_class.ae_fields.sort! { |a,b| a.priority.to_i <=> b.priority.to_i } if @ae_class
        end
      end

      @changed = (@edit[:current] != @edit[:new])
      page << javascript_for_miq_button_visibility(@changed)
    end
  end

  def update_instance
    assert_privileges("miq_ae_instance_edit")
    return unless load_edit("aeinst_edit__#{params[:id]}","replace_cell__explorer")
    get_instances_form_vars
    @changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      add_flash(I18n.t("flash.edit.cancelled",
                      :model=>ui_lookup(:model=>"MiqAeInstance"),
                      :name=>@ae_inst.name))
      @in_a_form = false
      replace_right_cell
    when "save"
      if @edit[:new][:ae_inst]["name"].blank? || @edit[:new][:ae_inst]["name"] == ""
        add_flash(I18n.t("flash.edit.field_required", :field=>"Name"), :error)
      end
      if @flash_array
        render :update do |page|
          if @sb[:row_selected]
            page.replace("flash_msg_div_class_instances", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_class_instances"})
          else
            page.replace("flash_msg_div_instance_fields", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_instance_fields"})
          end
        end
        return
      end
      set_instances_record_vars(@ae_inst)    # Set the instance record variables, but don't save
      set_instances_value_vars(@ae_values)   # Set the instance record variables, but don't save
      begin
        MiqAeInstance.transaction do
          @ae_inst.save!
          @ae_values.each do |val|
            val = nil if val == ""
            val.save!
          end
        end   # end of transaction
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"save") << bang.message, :error)
        @in_a_form = true
        render :update do |page|
          if @sb[:row_selected]
            page.replace("flash_msg_div_class_instances", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_class_instances"})
          else
            page.replace("flash_msg_div_instance_fields", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_instance_fields"})
          end
        end
      else
        AuditEvent.success(build_saved_audit(@ae_class, @edit))
        session[:edit] = nil  # clean out the saved info
        @in_a_form = false
        add_flash(I18n.t("flash.edit.saved",
                        :model=>ui_lookup(:model=>"MiqAeInstance"),
                        :name=>@ae_inst.name))
        replace_right_cell([:ae])
        return
      end
    when "reset"
      set_instances_form_vars
      add_flash(I18n.t("flash.edit.reset"), :warning)
      @in_a_form = true
      @button = "reset"
      replace_right_cell
    end
  end

  def create_instance
    assert_privileges("miq_ae_instance_new")
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      add_flash(I18n.t("flash.add.cancelled",
                      :model=>ui_lookup(:model=>"MiqAeInstance")))
      @in_a_form = false
      replace_right_cell
    when "add"
      return unless load_edit("aeinst_edit__new","replace_cell__explorer")
      get_instances_form_vars
      if @edit[:new][:ae_inst]["name"].blank? || @edit[:new][:ae_inst]["name"] == ""
        add_flash(I18n.t("flash.edit.field_required", :field=>"Name"), :error)
      end
      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div_class_instances", :partial => "layouts/flash_msg", :locals=>{:div_num=>"_class_instances"})
        end
        return
      end
      add_aeinst = MiqAeInstance.new
      set_instances_record_vars(add_aeinst)  # Set the instance record variables, but don't save
      set_instances_value_vars(@ae_values)   # Set the instance value record variables, but don't save
      begin
        MiqAeInstance.transaction do
          add_aeinst.save!
          @ae_values.each do |val|
            val.instance_id = add_aeinst.id
            val.save!
          end
        end  # end of transaction
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"add") << bang.message, :error)
        @in_a_form = true
        add_aeinst.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        render :update do |page|
          page.replace("flash_msg_div_class_instances", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_class_instances"})
        end
      else
        AuditEvent.success(build_created_audit(add_aeinst, @edit))
        add_flash(I18n.t("flash.add.added",
                        :model=>ui_lookup(:model=>"MiqAeInstance"),
                        :name=>add_aeinst.name))
        @in_a_form = false
        replace_right_cell([:ae])
        return
      end
    end
  end

  # Set form variables for edit
  def set_form_vars
    @in_a_form_props = true
    session[:field_data] = Hash.new
    @edit = Hash.new
    session[:edit] = Hash.new
    @edit[:ae_class_id] = @ae_class.id
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:new_field] = Hash.new
    @edit[:rec_id] = @ae_class.id || nil
    @edit[:key] = "aeclass_edit__#{@ae_class.id || "new"}"

    @edit[:new][:name] = @ae_class.name
    @edit[:new][:display_name] = @ae_class.display_name
    @edit[:new][:description] = @ae_class.description
    @edit[:new][:namespace] = @ae_class.namespace
    @edit[:new][:inherits] = @ae_class.inherits
    @edit[:inherits_from] = MiqAeClass.all.collect {|c| [ c.fqname, c.fqname ] }
    @edit[:current] = @edit[:new].dup
    @right_cell_text = @edit[:rec_id].nil? ?
        I18n.t("cell_header.adding_model_record",:model=>ui_lookup(:model=>"Class")) :
        I18n.t("cell_header.editing_model_record",:model=>ui_lookup(:model=>"Class"), :name=>@ae_class.name)
    session[:edit] = @edit
    @in_a_form = true
  end

  # Set form variables for edit
  def fields_set_form_vars
    @in_a_form_fields = true
    session[:field_data] = Hash.new
    @edit = Hash.new
    session[:edit] = Hash.new
    @edit[:ae_class_id] = @ae_class.id
    @edit[:rec_id] = @ae_class ? @ae_class.id : nil
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:new_field] = Hash.new
    @edit[:key] = "aefields_edit__#{@ae_class.id || "new"}"

    @edit[:new][:datatypes] = get_dtype_combo_xml([MiqAeField.new])     # setting combo for adding a new field
    @edit[:new][:aetypes] = get_combo_xml([MiqAeField.new])             # setting combo for adding a new field
    @edit[:new][:fields] = @ae_class.ae_fields.deep_clone
    @temp[:combo_xml] = get_combo_xml(@edit[:new][:fields].sort_by{|a| [a.priority.to_i]})                # combo to show existing fields
    @temp[:dtype_combo_xml] = get_dtype_combo_xml(@edit[:new][:fields].sort_by{|a| [a.priority.to_i]})    # passing fields because that's how many combo boxes we need
    @edit[:current] = @edit[:new].dup
    @edit[:current][:fields] = @edit[:new][:fields].deep_clone
    @right_cell_text = @edit[:rec_id].nil? ?
                        I18n.t("cell_header.adding_model_record",:model=>ui_lookup(:model=>"Class Schema")) :
                        I18n.t("cell_header.editing_model_record",:model=>ui_lookup(:model=>"Class Schema"), :name=>@ae_class.name)
    session[:edit] = @edit
  end

  # Set form variables for edit
  def set_method_form_vars
    session[:field_data] = Hash.new
    @ae_class = MiqAeClass.find_by_id(from_cid(@edit[:ae_class_id]))
    @edit = Hash.new
    session[:edit] = Hash.new
    @edit[:ae_method_id] = @ae_method.id
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:new_field] = Hash.new
    @edit[:ae_class_id] = @ae_class.id
    @edit[:rec_id] = @ae_method.id || nil
    @edit[:key] = "aemethod_edit__#{@ae_method.id || "new"}"
    @sb[:form_vars_set] = true
    @sb[:squash_state] ||= true

    @edit[:new][:name] = @ae_method.name
    @edit[:new][:display_name] = @ae_method.display_name
    @edit[:new][:scope] = "instance"
    @edit[:new][:language] = "ruby"
    @edit[:new][:available_locations] = MiqAeMethod.available_locations
    @edit[:new][:location] = @ae_method.location == nil ? "inline" : @ae_method.location
    @edit[:new][:data] = @ae_method.data.to_s
    if @edit[:new][:location] == "inline" && !@ae_method.data
      @edit[:new][:data] = "#
#            Automate Method
#
$evm.log(\"info\", \"Automate Method Started\")
#
#            Method Code Goes here
#

#
#
#
$evm.log(\"info\", \"Automate Method Ended\")
exit MIQ_OK"
    end
    @edit[:default_verify_status] = @edit[:new][:location] == "inline" && @edit[:new][:data] && @edit[:new][:data] != ""
    @edit[:new][:fields] = @ae_method.inputs.deep_clone
    @edit[:new][:available_datatypes] = MiqAeField.available_datatypes_for_ui
    @edit[:current] = @edit[:new].dup
    @edit[:current][:fields] = @edit[:new][:fields].deep_clone
    @right_cell_text = @edit[:rec_id].nil? ?
        I18n.t("cell_header.adding_model_record",:model=>ui_lookup(:model=>"MiqAeMethod")) :
        I18n.t("cell_header.editing_model_record",:model=>ui_lookup(:model=>"MiqAeMethod"), :name=>@ae_method.name)
    session[:log_depot_default_verify_status] = false
    session[:edit] = @edit
    session[:changed] = @changed = false
  end

  def validate_method_data
    return unless load_edit("aemethod_edit__#{params[:id]}","replace_cell__explorer")
    @edit[:new][:data] = params[:cls_method_data] if params[:cls_method_data]
    @edit[:new][:data] = params[:method_data] if params[:method_data]
    res = MiqAeMethod.validate_syntax(@edit[:new][:data])
    line = 0
    if !res
      add_flash(I18n.t("flash.data_validation_success"))
    else
      res.each do |err|
        line = err[0] if line == 0
        add_flash(I18n.t("flash.error_on_line", :line_num=>err[0], :err_txt=>err[1]), :error)
      end
    end
    render :update do |page|
      page << "if ($('cls_method_data')){"
        page.replace("flash_msg_div_class_methods", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_class_methods"})
        page << "var ta = document.getElementById('cls_method_data');"
      page << "} else {"
        page.replace("flash_msg_div_method_inputs", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_method_inputs"})
        page << "var ta = document.getElementById('method_data');"
      page << "}"
      page << "var lineHeight = ta.clientHeight / ta.rows;"
      page << "ta.scrollTop = (#{line.to_i}-1) * lineHeight;"
      if line > 0
        if @sb[:row_selected]
          page << "$('cls_method_data_lines').scrollTop = ta.scrollTop;"
          page << "$('cls_method_data').scrollTop = ta.scrollTop;"
        else
          page << "$('method_data_lines').scrollTop = ta.scrollTop;"
          page << "$('method_data').scrollTop = ta.scrollTop;"
        end
      end
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("aeclass_edit__#{params[:id]}","replace_cell__explorer")
    get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page.replace_html(@refresh_div, :partial=>@refresh_partial) if @refresh_div
      page << javascript_for_miq_button_visibility(@changed)
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def fields_form_field_changed
    return unless load_edit("aefields_edit__#{params[:id]}","replace_cell__explorer")
    fields_get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    @edit[:current][:fields].each_with_index do |fld,i|         #needed to compare each object's attributes to find out if something has changed
      if @edit[:new][:fields][i].attributes != fld.attributes
        @changed = true
      end
    end
    render :update do |page|                    # Use JS to update the display
      page.replace_html(@refresh_div, :partial=>@refresh_partial) if @refresh_div
      if !["up","down"].include?(params[:button])
        if params[:field_datatype]
          if session[:field_data][:datatype] == "password"
            page << "$('field_default_value').hide();"
            page << "$('field_password_value').show();"
            page << "$('field_password_value').value = '';"
          else
            page << "$('field_password_value').hide();"
            page << "$('field_default_value').show();"
            page << "$('field_default_value').value = '';"
          end
        end
        params.keys.each do |field|
          if field.to_s.starts_with?("fields_datatype")
            f = field.split('fields_datatype')
            def_field = "fields_default_value_" << f[1].to_s
            pwd_field = "fields_password_value_" << f[1].to_s
            if @edit[:new][:fields][f[1].to_i].datatype == "password"
              page << "$('#{def_field}').hide();"
              page << "$('#{pwd_field}').show();"
              page << "$('#{pwd_field}').value='';"
              @edit[:new][:fields][f[1].to_i].default_value = nil
            else
              page << "$('#{pwd_field}').hide();"
              page << "$('#{def_field}').show();"
              page << "$('#{def_field}').value='';"
              @edit[:new][:fields][f[1].to_i].default_value = nil
            end
          end
        end
      end
      page << javascript_for_miq_button_visibility_changed(@changed)
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_method_field_changed
    if !@sb[:form_vars_set]  # workaround to prevent an error that happens when IE sends a transaction form form even after save button is clicked when there is text_area in the form
      render :nothing=>true
    else
      return unless load_edit("aemethod_edit__#{params[:id]}","replace_cell__explorer")
      @prev_location = @edit[:new][:location]
      get_method_form_vars
      if @sb[:row_selected] || x_node.split('-').first == "aec"
        @refresh_div = "class_methods_div"
        @refresh_partial = "class_methods"
        @field_name = "cls_method"
      else
        @refresh_div = "method_inputs_div"
        @refresh_partial = "method_inputs"
        @field_name = "method"
      end
      if @edit[:current][:location] == "inline" && @edit[:current][:data]
        @edit[:method_prev_data] = @edit[:current][:data]
      end
      if @edit[:new][:location] == "inline" && !params[:cls_method_data] && !params[:method_data] && !params[:transOne]
        if !@edit[:method_prev_data]
        @edit[:new][:data] = "#
  #            Automate Method
  #
  $evm.log(\"info\", \"Automate Method Started\")
  #
  #            Method Code Goes here
  #

  #
  #
  #
  $evm.log(\"info\", \"Automate Method Ended\")
  exit MIQ_OK"
        else
          @edit[:new][:data] = @edit[:method_prev_data]
        end
      elsif params[:cls_method_location] || params[:method_location]      #reset data if location is changed
        @edit[:new][:data] = ""
      end
      @changed = (@edit[:new] != @edit[:current])
      @edit[:current][:fields].each_with_index do |fld,i|         #needed to compare each object's attributes to find out if something has changed
        if @edit[:new][:fields][i].attributes != fld.attributes
          @changed = true
        end
      end
      @edit[:default_verify_status] = @edit[:new][:location] == "inline" && @edit[:new][:data] && @edit[:new][:data] != ""
      render :update do |page|                    # Use JS to update the display
        page.replace_html(@refresh_div, :partial=>@refresh_partial)  if @refresh_div && @prev_location != @edit[:new][:location]
        #page.replace_html("hider_1", :partial=>"method_data", :locals=>{:field_name=>@field_name})  if @prev_location != @edit[:new][:location]
        if params[:cls_field_datatype]
          if session[:field_data][:datatype] == "password"
            page << "$('cls_field_default_value').hide();"
            page << "$('cls_field_password_value').show();"
            page << "$('cls_field_password_value').value = '';"
          else
            page << "$('cls_field_password_value').hide();"
            page << "$('cls_field_default_value').show();"
            page << "$('cls_field_default_value').value = '';"
          end
        end
        if params[:method_field_datatype]
          if session[:field_data][:datatype] == "password"
            page << "$('method_field_default_value').hide();"
            page << "$('method_field_password_value').show();"
            page << "$('method_field_password_value').value = '';"
          else
            page << "$('method_field_password_value').hide();"
            page << "$('method_field_default_value').show();"
            page << "$('method_field_default_value').value = '';"
          end
        end
        params.keys.each do |field|
          if field.to_s.starts_with?("cls_fields_datatype_")
            f = field.split('cls_fields_datatype_')
            def_field = "cls_fields_value_" << f[1].to_s
            pwd_field = "cls_fields_password_value_" << f[1].to_s
            if @edit[:new][:fields][f[1].to_i].datatype == "password"
              page << "$('#{def_field}').hide();"
              page << "$('#{pwd_field}').show();"
              page << "$('#{pwd_field}').value='';"
              @edit[:new][:fields][f[1].to_i].default_value = nil
            else
              page << "$('#{pwd_field}').hide();"
              page << "$('#{def_field}').show();"
              page << "$('#{def_field}').value='';"
              @edit[:new][:fields][f[1].to_i].default_value = nil
            end
          elsif field.to_s.starts_with?("fields_datatype_")
            f = field.split('fields_datatype_')
            def_field = "fields_value_" << f[1].to_s
            pwd_field = "fields_password_value_" << f[1].to_s
            if @edit[:new][:fields][f[1].to_i].datatype == "password"
              page << "$('#{def_field}').hide();"
              page << "$('#{pwd_field}').show();"
              page << "$('#{pwd_field}').value='';"
              @edit[:new][:fields][f[1].to_i].default_value = nil
            else
              page << "$('#{pwd_field}').hide();"
              page << "$('#{def_field}').show();"
              page << "$('#{def_field}').value='';"
              @edit[:new][:fields][f[1].to_i].default_value = nil
            end
          end
        end
        if @edit[:default_verify_status] != session[:log_depot_default_verify_status]
          session[:log_depot_default_verify_status] = @edit[:default_verify_status]
          if @edit[:default_verify_status]
            page << "miqValidateButtons('show', 'default_');"
          else
            page << "miqValidateButtons('hide', 'default_');"
          end
        end
        page << javascript_for_miq_button_visibility_changed(@changed)
      end
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_ns_field_changed
    return unless load_edit("aens_edit__#{params[:id]}","replace_cell__explorer")
    get_ns_form_vars
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page << javascript_for_miq_button_visibility(@changed)
    end
  end

  def update
    assert_privileges("miq_ae_class_edit")
    return unless load_edit("aeclass_edit__#{params[:id]}","replace_cell__explorer")
    get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      add_flash(I18n.t("flash.edit.cancelled",
                      :model=>ui_lookup(:model=>"MiqAeClass"),
                      :name=>@ae_class.name))
      @in_a_form = false
      replace_right_cell
    when "save"
      ae_class = find_by_id_filtered(MiqAeClass, params[:id])
      set_record_vars(ae_class)                     # Set the record variables, but don't save
      begin
        MiqAeClass.transaction do
          ae_class.save!
        end  # end of transaction
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"save") << bang.message, :error)
        session[:changed] = @changed
        @changed = true
        render :update do |page|
          page.replace("flash_msg_div_class_props", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_class_props"})
        end
      else
        add_flash(I18n.t("flash.edit.saved",
                        :model=>ui_lookup(:model=>"MiqAeClass"),
                        :name=>ae_class.fqname))
        AuditEvent.success(build_saved_audit(ae_class, @edit))
        session[:edit] = nil  # clean out the saved info
        @in_a_form = false
        replace_right_cell([:ae])
        return
      end
    when "reset"
      set_form_vars
      session[:changed] = @changed = false
      add_flash(I18n.t("flash.edit.reset"), :warning)
      @button = "reset"
      replace_right_cell
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell([:ae])
    end
  end

  def update_fields
    return unless load_edit("aefields_edit__#{params[:id]}","replace_cell__explorer")
    fields_get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      add_flash(I18n.t("flash.edit.cancelled_for_class",
                      :model=>ui_lookup(:model=>"MiqAeClass"),
                      :name=>@ae_class.name))
      @in_a_form = false
      replace_right_cell
    when "save"
      ae_class = find_by_id_filtered(MiqAeClass, params[:id])
      to_delete, flds_flg = set_field_vars(@edit[:current][:fields])
      begin
        MiqAeClass.transaction do
          MiqAeField.find_all_by_id(to_delete).each do |fld|
            fld.destroy
          end
          @edit[:current][:fields].sort_by{|a| [a.priority.to_i]}.each do |fld|
            fld.default_value = nil if fld.default_value == ""
            fld.save!
          end
        end  # end of transaction
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"save") << bang.message, :error)
        session[:changed] = @changed
        @changed = true
        render :update do |page|
          page.replace("flash_msg_div_class_fields", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_class_fields"})
        end
      else
        add_flash(I18n.t("flash.edit.saved_for_class",
                      :model=>ui_lookup(:model=>"MiqAeClass"),
                      :name=>ae_class.name))
        AuditEvent.success(build_saved_audit(ae_class, @edit))
        session[:edit] = nil  # clean out the saved info
        @in_a_form = false
        replace_right_cell([:ae])
        return
      end
    when "reset"
      fields_set_form_vars
      session[:changed] = @changed = false
      add_flash(I18n.t("flash.edit.reset"), :warning)
      @button = "reset"
      @in_a_form = true
      replace_right_cell
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell([:ae])
    end
  end

  def update_ns
    assert_privileges("miq_ae_namespace_edit")
    return unless load_edit("aens_edit__#{params[:id]}", "replace_cell__explorer")
    get_ns_form_vars
    @changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      add_flash(I18n.t("flash.edit.cancelled",
                       :model => ui_lookup(:model => "#{@edit[:new][:domain] ? "MiqAeDomain" : "MiqAeNamespace"}"),
                       :name  => @ae_ns.name))
      @in_a_form = false
      replace_right_cell
    when "save"
      ae_ns = find_by_id_filtered(MiqAeNamespace, params[:id])
      ns_set_record_vars(ae_ns)                     # Set the record variables, but don't save
      begin
        MiqAeNamespace.transaction do
          ae_ns.save!
        end  # end of transaction
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"save") << bang.message, :error)
        session[:changed] = @changed
        @changed = true
        render :update do |page|
          page.replace("flash_msg_div_ns_list",
                       :partial => "layouts/flash_msg",
                       :locals  => {:div_num => "_ns_list"})
        end
      else
        add_flash(I18n.t("flash.edit.saved",
                         :model => ui_lookup(:model => "#{@edit[:new][:domain] ? "MiqAeDomain" : "MiqAeNamespace"}"),
                         :name  => ae_ns.name))
        AuditEvent.success(build_saved_audit(ae_ns, @edit))
        session[:edit] = nil  # clean out the saved info
        @in_a_form = false
        replace_right_cell([:ae])
      end
    when "reset"
      ns_set_form_vars(@ae_ns.domain? ? "MiqAeDomain" : "MiqAeNamespace")
      session[:changed] = @changed = false
      add_flash(I18n.t("flash.edit.reset"), :warning)
      @button = "reset"
      replace_right_cell
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell([:ae])
    end
  end

  def update_method
    assert_privileges("miq_ae_method_edit")
    return unless load_edit("aemethod_edit__#{params[:id]}","replace_cell__explorer")
    get_method_form_vars
    @changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      add_flash(I18n.t("flash.edit.cancelled",
                      :model=>ui_lookup(:model=>"MiqAeMethod"),
                      :name=>@ae_method.name))
      @sb[:form_vars_set] = false
      @in_a_form = false
      replace_right_cell
    when "save"
      ae_method = find_by_id_filtered(MiqAeMethod, params[:id])
      set_method_record_vars(ae_method)                     # Set the record variables, but don't save
      to_delete, flds_flg = set_input_vars(@edit[:current][:fields])
      begin
        MiqAeMethod.transaction do
          ae_method.save!
          MiqAeField.find_all_by_id(to_delete).each do |fld|
            fld.destroy
          end
          @edit[:current][:fields].sort_by{|a| [a.priority.to_i]}.each do |fld|
            fld.default_value = nil if fld.default_value == ""
            fld.save!
          end
        end  # end of transaction
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"save") << bang.message, :error)
        session[:changed] = @changed
        @changed = true
        render :update do |page|
          if @sb[:row_selected]
            page.replace("flash_msg_div_class_methods", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_class_methods"})
          else
            page.replace("flash_msg_div_method_inputs", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_method_inputs"})
          end
        end
      else
        add_flash(I18n.t("flash.edit.saved",
                        :model=>ui_lookup(:model=>"MiqAeMethod"),
                        :name=>ae_method.name))
        AuditEvent.success(build_saved_audit(ae_method, @edit))
        session[:edit] = nil  # clean out the saved info
        @sb[:form_vars_set] = false
        @in_a_form = false
        replace_right_cell([:ae])
        return
      end
    when "reset"
      set_method_form_vars
      session[:changed] = @changed = false
      @in_a_form = true
      add_flash(I18n.t("flash.edit.reset"), :warning)
      @button = "reset"
      replace_right_cell
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell
    end
  end

  def new
    assert_privileges("miq_ae_class_new")
    @ae_class = MiqAeClass.new
    set_form_vars
    @in_a_form = true
    replace_right_cell
  end

  def new_instance
    assert_privileges("miq_ae_instance_new")
    @ae_inst = MiqAeInstance.new
    initial_setup_for_instances_form_vars(@ae_inst)
    set_instances_form_vars
    @in_a_form = true
    replace_right_cell
  end

  def new_method
    assert_privileges("miq_ae_method_new")
    @ae_method = MiqAeMethod.new
    set_method_form_vars
    @in_a_form = true
    replace_right_cell
  end

  def create
    assert_privileges("miq_ae_class_new")
    return unless load_edit("aeclass_edit__new","replace_cell__explorer")
    get_form_vars
    @in_a_form = true
    case params[:button]
    when "cancel"
      add_flash(I18n.t("flash.add.cancelled",
                      :model=>ui_lookup(:model=>"MiqAeClass")))
      @in_a_form = false
      replace_right_cell([:ae])
    when "add"
      add_aeclass = MiqAeClass.new
      set_record_vars(add_aeclass)                        # Set the record variables, but don't save
      begin
        MiqAeClass.transaction do
          add_aeclass.save!
        end
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"add") << bang.message, :error)
        @in_a_form = true
        render :update do |page|
          page.replace("flash_msg_div_class_props", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_class_props"})
        end
      else
        add_flash(I18n.t("flash.add.added",
                        :model=>ui_lookup(:model=>"MiqAeClass"),
                        :name=>add_aeclass.fqname))
        @in_a_form = false
        replace_right_cell([:ae])
      end
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell([:ae])
    end
  end

  def create_method
    assert_privileges("miq_ae_method_new")
    @in_a_form = true
    case params[:button]
    when "cancel"
      add_flash(I18n.t("flash.add.cancelled",
                      :model=>ui_lookup(:model=>"MiqAeMethod")))
      @sb[:form_vars_set] = false
      @in_a_form = false
      replace_right_cell
    when "add"
      return unless load_edit("aemethod_edit__new","replace_cell__explorer")
      get_method_form_vars
      add_aemethod = MiqAeMethod.new
      set_method_record_vars(add_aemethod)                        # Set the record variables, but don't save
      begin
        MiqAeMethod.transaction do
          add_aemethod.save!
          ae_method = MiqAeMethod.find_by_name_and_class_id(add_aemethod.name, from_cid(@edit[:ae_class_id]))
          @edit[:new][:fields].each do |fld|
            fld.method_id = ae_method.id
            fld.save!
          end
        end
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"add") << bang.message, :error)
        @in_a_form = true
        render :update do |page|
          page.replace("flash_msg_div_class_methods", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_class_methods"})
        end
      else
        add_flash(I18n.t("flash.add.added",
                        :model=>ui_lookup(:model=>"MiqAeMethod"),
                        :name=>add_aemethod.name))
        @sb[:form_vars_set] = false
        @in_a_form = false
        replace_right_cell([:ae])
      end
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      @sb[:form_vars_set] = false
      replace_right_cell([:ae])
    end
  end

  def create_ns
    assert_privileges("miq_ae_namespace_new")
    return unless load_edit("aens_edit__new", "replace_cell__explorer")
    get_ns_form_vars
    case params[:button]
    when "cancel"
      add_flash(I18n.t("flash.add.cancelled",
                       :model => ui_lookup(:model => "#{@edit[:new][:domain] ? "MiqAeDomain" : "MiqAeNamespace"}")))
      @in_a_form = false
      replace_right_cell
    when "add"
      add_ae_ns = MiqAeNamespace.new
      ns_set_record_vars(add_ae_ns)                       # Set the record variables, but don't save
      begin
        MiqAeNamespace.transaction do
          add_ae_ns.save!
        end
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task => "add") << bang.message, :error)
        render :update do |page|
          page.replace("flash_msg_div_ns_list",
                       :partial => "layouts/flash_msg",
                       :locals  => {:div_num => "_ns_list"})
        end
      else
        add_flash(I18n.t("flash.add.added",
                         :model => ui_lookup(:model => "#{@edit[:new][:domain] ? "MiqAeDomain" : "MiqAeNamespace"}"),
                         :name  => add_ae_ns.name))
        @in_a_form = false
        replace_right_cell([:ae])
      end
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell
    end
  end

  # AJAX driven routine to select a classification entry
  def field_select
    fields_get_form_vars
    @temp[:combo_xml] = get_combo_xml(@edit[:new][:fields])
    @temp[:dtype_combo_xml] = get_dtype_combo_xml(@edit[:new][:fields])   # passing fields because that's how many combo boxes we need
    session[:field_data] = Hash.new
    @edit[:new_field][:substitute] = session[:field_data][:substitute] = true
    @changed = (@edit[:new] != @edit[:current])
    @edit[:current][:fields].each_with_index do |fld,i|         #needed to compare each object's attributes to find out if something has changed
      if @edit[:new][:fields][i].attributes != fld.attributes
        @changed = true
      end
    end
    render :update do |page|                    # Use JS to update the display
      page.replace_html("class_fields_div", :partial=>"class_fields")
      page << javascript_for_miq_button_visibility(@changed)
      page << "miqSparkle(false);"
    end
  end

  # AJAX driven routine to select a classification entry
  def field_accept
    fields_get_form_vars
    #session[:field_data] = Hash.new
    @changed = (@edit[:new] != @edit[:current])
    @edit[:current][:fields].each_with_index do |fld,i|         #needed to compare each object's attributes to find out if something has changed
      if @edit[:new][:fields][i].attributes != fld.attributes
        @changed = true
      end
    end
    @temp[:combo_xml] = get_combo_xml(@edit[:new][:fields])
    @temp[:dtype_combo_xml] = get_dtype_combo_xml(@edit[:new][:fields])   # passing fields because that's how many combo boxes we need
    render :update do |page|                    # Use JS to update the display
      page.replace_html("class_fields_div", :partial=>"class_fields")
      page << javascript_for_miq_button_visibility(@changed)
      page << "miqSparkle(false);"
    end
  end

  # AJAX driven routine to delete a classification entry
  def field_delete
    fields_get_form_vars
    @temp[:combo_xml]       = get_combo_xml(@edit[:new][:fields])
    @temp[:dtype_combo_xml] = get_dtype_combo_xml(@edit[:new][:fields])
    if params[:id].to_i != 0
      #@edit[:new][:fields][params[:id].to_i].id = "0"
      @edit[:new][:fields].sort_by{|a| [a.priority.to_i]}.each_with_index do |flds,i|
        if i == params[:arr_id].to_i
          flds.id = "0"
        end
      end
    else
      @edit[:new][:fields].sort_by{|a| [a.priority.to_i]}.each_with_index do |flds,i|
        if i == params[:arr_id].to_i
          @edit[:new][:fields].delete(flds)
        end
      end
    end
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page.replace_html("class_fields_div", :partial=>"class_fields")
      page << javascript_for_miq_button_visibility(@changed)
      page << "miqSparkle(false);"
    end
  end

  # AJAX driven routine to select a classification entry
  def field_method_select
    get_method_form_vars
    if @sb[:row_selected] || x_node.split('-').first == "aec"
      @refresh_div = "class_methods_div"
      @refresh_partial = "class_methods"
    else
      @refresh_div = "method_inputs_div"
      @refresh_partial = "method_inputs"
    end
    session[:field_data] = Hash.new
    @changed = (@edit[:new] != @edit[:current])
    @edit[:current][:fields].each_with_index do |fld,i|         #needed to compare each object's attributes to find out if something has changed
      if @edit[:new][:fields][i].attributes != fld.attributes
        @changed = true
      end
    end
    @in_a_form = true
    render :update do |page|                    # Use JS to update the display
      page.replace_html(@refresh_div, :partial=>@refresh_partial) if @refresh_div
      if @sb[:row_selected] || x_node.split('-').first == "aec"
        page << "$('class_methods_div').show();"
        page << "$('cls_field_name').focus();"
      else
        page << "$('method_inputs_div').show();"
        page << "$('field_name').focus();"
      end
      page << javascript_for_miq_button_visibility(@changed)
      page << "$('inputs_div').show();"
      page << "miqSparkle(false);"
    end
  end

# AJAX driven routine to select a classification entry
  def field_method_accept
    get_method_form_vars
    if @sb[:row_selected] || x_node.split('-').first == "aec"
      @refresh_div = "class_methods_div"
      @refresh_partial = "class_methods"
    else
      @refresh_div = "method_inputs_div"
      @refresh_partial = "method_inputs"
    end
    session[:field_data] = Hash.new
    @changed = (@edit[:new] != @edit[:current])
    @edit[:current][:fields].each_with_index do |fld,i|         #needed to compare each object's attributes to find out if something has changed
      if @edit[:new][:fields][i].attributes != fld.attributes
        @changed = true
      end
    end
    @in_a_form = true
    render :update do |page|                    # Use JS to update the display
      page.replace_html(@refresh_div, :partial=>@refresh_partial)  if @refresh_div
      if @sb[:row_selected] || x_node.split('-').first == "aec"
        page << "$('class_methods_div').show();"
      else
        page << "$('method_inputs_div').show();"
      end
      page << javascript_for_miq_button_visibility(@changed)
      page << "$('inputs_div').show();"
      page << "miqSparkle(false);"
    end
  end

  # AJAX driven routine to delete a classification entry
  def field_method_delete
    get_method_form_vars
    if @sb[:row_selected] || x_node.split('-').first == "aec"
      @refresh_div = "class_methods_div"
      @refresh_partial = "class_methods"
    else
      @refresh_div = "method_inputs_div"
      @refresh_partial = "method_inputs"
    end
    if params[:id].to_i != 0
      @edit[:new][:fields].each_with_index do |flds,i|
        if i == params[:arr_id].to_i
          flds.id = "0"
        end
      end
    else
      @edit[:new][:fields].delete_at(params[:arr_id].to_i)
    end
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page.replace_html(@refresh_div, :partial=>@refresh_partial)  if @refresh_div
      if @sb[:row_selected] || x_node.split('-').first == "aec"
        page << "$('class_methods_div').show();"
      else
        page << "$('method_inputs_div').show();"
      end
      page << javascript_for_miq_button_visibility(@changed)
      page << "$('inputs_div').show();"
      page << "miqSparkle(false);"
    end
  end

  # Get variables from user edit form
  def fields_seq_field_changed
    return unless load_edit("fields_edit__seq","replace_cell__explorer")
    move_selected_fields_up(@edit[:new][:fields_list], params[:seq_fields], "Fields")   if params[:button] == "up"
    move_selected_fields_down(@edit[:new][:fields_list], params[:seq_fields], "Fields") if params[:button] == "down"
    unless @flash_array
      @refresh_div = "column_lists"
      @refresh_partial = "fields_seq_form"
    end
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page.replace("flash_msg_div_fields_seq",
                   :partial => "layouts/flash_msg",
                   :locals  => {:div_num => "_fields_seq"}) unless @refresh_div && @refresh_div != "column_lists"
      page.replace(@refresh_div, :partial=>@refresh_partial) if @refresh_div
      if @changed
        page << javascript_for_miq_button_visibility(@changed)
      end
      page << "miqSparkle(false);"
    end
  end

  def fields_seq_edit
    assert_privileges("miq_ae_field_seq")
    case params[:button]
    when "cancel"
      @sb[:action] = session[:edit] = nil # clean out the saved info
      add_flash(I18n.t("flash.class_schema_sequence_cancelled"))
      @in_a_form = false
      replace_right_cell
    when "save"
      return unless load_edit("fields_edit__seq","replace_cell__explorer")
      err = false
      @edit[:new][:fields_list].each_with_index do |f, i|
        fld = MiqAeField.find_by_name_and_class_id(f.split('(').last.split(')').first, from_cid(@edit[:ae_class_id]))   #leave display name and parenthesis out
        fld.priority = i+1
        if fld.save
          AuditEvent.success(build_saved_audit(fld, @edit))
        else
          fld.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          err = true
        end
      end
      if !err
        add_flash(I18n.t("flash.class_schema_sequence_saved"))
        @sb[:action] = @edit = session[:edit] = nil # clean out the saved info
        @in_a_form = false
        replace_right_cell
      else
        @in_a_form = true
        @changed = true
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      end
    when "reset", nil # Reset or first time in
      id = params[:id] ? params[:id] : from_cid(@edit[:ae_class_id])
      @in_a_form = true
      fields_seq_edit_screen(id)
      if params[:button] == "reset"
        add_flash(I18n.t("flash.edit.reset"), :warning)
      end
      replace_right_cell
    end
  end

  def priority_form_field_changed
    return unless load_edit(params[:id], "replace_cell__explorer")
    priority_get_form_vars
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      page.replace("flash_msg_div_domains_priority",
                   :partial => "layouts/flash_msg",
                   :locals  => {:div_num => "_domains_priority"}) if @flash_array
      page.replace(@refresh_div,
                   :partial => @refresh_partial,
                   :locals  => {:action => "domains_priority_edit"}) if @refresh_div
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  def domains_priority_edit
    assert_privileges("miq_ae_domain_priority_edit")
    case params[:button]
    when "cancel"
      @sb[:action] = @in_a_form = @edit = session[:edit] = nil  # clean out the saved info
      add_flash(I18n.t("flash.priority_order_cancelled"))
      replace_right_cell
    when "save"
      return unless load_edit("priority__edit", "replace_cell__explorer")
      # TODO: need to move this to model method
      @edit[:new][:domain_order].reverse!.each_with_index do |domain, i|
        d = MiqAeDomain.find_by_name(domain.split(" (Locked)").first)
        d.priority = i + 1
        d.save!
      end
      add_flash(I18n.t("flash.priority_order_saved"))
      @sb[:action] = @in_a_form = @edit = session[:edit] = nil  # clean out the saved info
      replace_right_cell([:ae])
    when "reset", nil # Reset or first time in
      priority_edit_screen
      add_flash(I18n.t("flash.edit.reset"), :warning) if params[:button] == "reset"
      session[:changed] = @changed = false
      replace_right_cell
    end
  end

private

  def initial_setup_for_instances_form_vars(ae_inst)
    if ae_inst.id
      @ae_class  = MiqAeClass.find(@ae_inst.class_id)
      @ae_fields = @ae_class.ae_fields
      @ae_values = []
      @ae_fields.sort_by { |a| [a.priority.to_i] }.each do |fld|
        val = MiqAeValue.find_by_field_id_and_instance_id(fld.id.to_i, @ae_inst.id.to_i)
        if val.nil?
          val             = MiqAeValue.new
          val.field_id    = fld.id.to_i
          val.instance_id = @ae_inst.id.to_i
        end
        @ae_values.push(val)
      end
    else
      @ae_values = []
      @ae_inst   = MiqAeInstance.new
      @ae_class  = MiqAeClass.find_by_id(@edit[:ae_class_id])
      @ae_class.ae_fields.each do |fld|
        v             = MiqAeValue.new
        v.instance_id = @ae_inst.id.to_i
        v.field_id    = fld.id.to_i
        @ae_values.push(v)
      end
    end
  end

  def instance_column_names
    %w(name description display_name)
  end

  def field_column_names
    %w(aetype collect datatype default_value display_name name on_entry on_error on_exit substitute)
  end

  def value_column_names
    %w(collect display_name on_entry on_error on_exit max_retries max_time value)
  end

  def create_action_url(node)
    if @sb[:action] == "miq_ae_domain_priority_edit"
      'domains_priority_edit'
    elsif @sb[:action] == 'miq_ae_field_seq'
      'fields_seq_edit'
    else
      prefix = @edit[:rec_id].nil? ? 'create' : 'update'
      if node ==  'aec'
        suffix_hash = {
          'instances' => '_instance',
          'methods'   => '_method',
          'props'     => '',
          'schema'    => '_fields'
        }
        suffix = suffix_hash[@sb[:active_tab]]
      else
        suffix_hash = {
          'root' => '_ns',
          'aei'  => '_instance',
          'aem'  => '_method',
          'aen'  => @edit.key?(:ae_class_id) ? '' : '_ns'
        }
        suffix = suffix_hash[node]
      end
      prefix + suffix
    end
  end

  def get_rec_name(rec)
    column = rec.display_name.blank? ? :name : :display_name
    if rec.kind_of?(MiqAeNamespace) && rec.domain? && !rec.editable?
      add_read_only_suffix(rec.send(column))
    else
      rec.send(column)
    end
  end

  # Add the children of a node that is being expanded (autoloaded), called by generic tree_autoload method
  def tree_add_child_nodes(id)
    return x_get_child_nodes(x_active_tree, id)
  end

  # Delete all selected or single displayed aeclasses(s)
  def deleteclasses
    assert_privileges("miq_ae_class_delete")
    aeclasses = []
    if params[:id]
      aeclasses.push(params[:id])
      cls = MiqAeClass.find_by_id(from_cid(params[:id]))
      self.x_node = "aen-#{to_cid(cls.namespace_id)}"
    else
      @sb[:row_selected] = find_checked_items
      @sb[:row_selected].each do |items|
        item = items.split('-')
        aeclasses.push(from_cid(item[1]))
      end
    end
    process_aeclasses(aeclasses, "destroy") unless aeclasses.empty?
    replace_right_cell([:ae])
  end

  # Common aeclasses button handler routines
  def process_aeclasses(aeclasses, task)
    process_elements(aeclasses, MiqAeClass, task)
  end

  # Delete all selected or single displayed aeclasses(s)
  def deleteinstances
    assert_privileges("miq_ae_instance_delete")
    aeinstances = Array.new
    @sb[:row_selected] = find_checked_items
    if @sb[:row_selected]
      @sb[:row_selected].each do |items|
        item = items.split('-')
        aeinstances.push(from_cid(item[1]))
      end
    else
      node = x_node.split('-')
      aeinstances.push(from_cid(node[1]))
      inst = MiqAeInstance.find_by_id(from_cid(node[1]))
      self.x_node = "aec-#{to_cid(inst.class_id)}"
    end

    process_aeinstances(aeinstances, "destroy") unless aeinstances.empty?
    add_flash(I18n.t(flash.selected_records_deleted,:model=>ui_lookup(:models=>"MiqAeInstances"))) if @flash_array == nil
    replace_right_cell([:ae])
  end

  # Common aeclasses button handler routines
  def process_aeinstances(aeinstances, task)
    process_elements(aeinstances, MiqAeInstance, task)
  end

  # Delete all selected or single displayed aeclasses(s)
  def deletemethods
    assert_privileges("miq_ae_method_delete")
    aemethods = Array.new
    @sb[:row_selected] = find_checked_items
    if @sb[:row_selected]
      @sb[:row_selected].each do |items|
        item = items.split('-')
        aemethods.push(from_cid(item[1]))
      end
    else
      node = x_node.split('-')
      aemethods.push(from_cid(node[1]))
      inst = MiqAeMethod.find_by_id(from_cid(node[1]))
      self.x_node = "aec-#{to_cid(inst.class_id)}"
    end

    process_aemethods(aemethods, "destroy") unless aemethods.empty?
    add_flash(I18n.t(flash.selected_records_deleted,:model=>ui_lookup(:models=>"MiqAeMethod"))) if @flash_array == nil
    replace_right_cell([:ae])
  end

  # Common aeclasses button handler routines
  def process_aemethods(aemethods, task)
    process_elements(aemethods, MiqAeMethod, task)
  end

  # Delete all selected or single displayed aeclasses(s)
  def delete_domain
    assert_privileges("miq_ae_domain_delete")
    delete_domain_or_namespaces
  end

  # Delete all selected or single displayed aeclasses(s)
  def delete_ns
    assert_privileges("miq_ae_namespace_delete")
    delete_domain_or_namespaces
  end

  def delete_domain_or_namespaces
    @sb[:row_selected] = find_checked_items
    ae_ns = []
    ae_cs = []
    if params[:id] && params[:pressed] == "miq_ae_domain_delete"
      ae_ns.push(params[:id])
      self.x_node = "root"
    elsif @sb[:row_selected]
      ae_ns, ae_cs = items_to_delete
    else
      node = x_node.split('-')
      ae_cs.push(from_cid(node[1]))
      cls = MiqAeClass.find_by_id(from_cid(node[1]))
      self.x_node = "aen-#{cls.namespace_id}"
    end
    process_ae_ns(ae_ns, "destroy")     unless ae_ns.empty?
    process_aeclasses(ae_cs, "destroy") unless ae_cs.empty?
    replace_right_cell([:ae])
  end

  def items_to_delete
    ns_list = []
    cs_list = []
    @sb[:row_selected].each do |items|
      item = items.split('-')
      if item[0] == "aen"
        record = MiqAeNamespace.find_by_id(from_cid(item[1]))
        if record.editable?
          ns_list.push(from_cid(item[1]))
        else
          add_flash(I18n.t("flash.cannot_delete",
                           :model => ui_lookup(:model => "MiqAeDomain"),
                           :field => record.name),
                    :error)
        end
      else
        cs_list.push(from_cid(item[1]))
      end
    end
    return ns_list, cs_list
  end

  # Common aeclasses button handler routines
  def process_ae_ns(ae_ns, task)
    process_elements(ae_ns, MiqAeNamespace, task)
  end

  # Get variables from edit form
  def get_form_vars
    @ae_class = MiqAeClass.find_by_id(from_cid(@edit[:ae_class_id]))
    # for class add tab
    @edit[:new][:name] = params[:name].blank? ? nil : params[:name] if params[:name]
    @edit[:new][:description] = params[:description].blank? ? nil : params[:description] if params[:description]
    @edit[:new][:display_name] = params[:display_name].blank? ? nil : params[:display_name] if params[:display_name]
    @edit[:new][:namespace] = params[:namespace] if params[:namespace]
    @edit[:new][:inherits] = params[:inherits_from] if params[:inherits_from]

    # for class edit tab
    @edit[:new][:name] = params[:cls_name].blank? ? nil : params[:cls_name] if params[:cls_name]
    @edit[:new][:description] = params[:cls_description].blank? ? nil : params[:cls_description] if params[:cls_description]
    @edit[:new][:display_name] = params[:cls_display_name].blank? ? nil : params[:cls_display_name] if params[:cls_display_name]
    @edit[:new][:namespace] = params[:cls_namespace] if params[:cls_namespace]
    @edit[:new][:inherits] = params[:cls_inherits_from] if params[:cls_inherits_from]
  end

  # Common routine to find checked items on a page (checkbox ids are "check_xxx" where xxx is the item id or index)
  def find_checked_items(prefix = nil)
    if !params[:miq_grid_checks].blank?
      return params[:miq_grid_checks].split(",")
    elsif !params[:miq_grid_checks2].blank?
      return params[:miq_grid_checks2].split(",")
    end
  end

  def field_attributes
    [:aetype, :class_id, :collect, :datatype, :default_value, :description,
     :display_name, :max_retries, :max_time, :message, :name, :on_entry,
     :on_error, :on_exit, :priority, :substitute]
  end

  # Get variables from edit form
  def fields_get_form_vars
    @ae_class = MiqAeClass.find_by_id(from_cid(@edit[:ae_class_id]))
    @in_a_form = true
    @in_a_form_fields = true
    if params[:item].blank? && !%w(accept save).include?(params[:button])  && params["action"] != "field_delete"
      field_data = session[:field_data]
      new_field = @edit[:new_field]

      field_attributes.each do |field|
        field_name = "field_#{field}".to_sym
        if field == :substitute
          field_data[field] = new_field[field] = params[field_name].to_i == 1 if params[field_name]
        else
          field_data[field] = new_field[field] = params[field_name] if params[field_name]
        end
      end

      field_data[:default_value] = new_field[:default_value] =
          params[:field_password_value] if params[:field_password_value]
      new_field[:priority] = 1
      @edit[:new][:fields].sort_by { |a| [a.priority.to_i] }.each_with_index do |flds, i|
        if i == @edit[:new][:fields].length - 1
          if flds.priority.nil?
            new_field[:priority] = 1
          else
            new_field[:priority] = flds.priority.to_i + 1
          end
        end
      end
      new_field[:class_id] = @ae_class.id

      @edit[:new][:fields].each_with_index do |fld, i|
        field_attributes.each do |field|
          field_name = "fields_#{field}_#{i}".to_sym
          if field == :substitute
            fld[field] = params[field_name].to_i == 1 if params[field_name]
          elsif %w(aetype datatype).include?(field.to_s)
            var_name = "fields_#{field}#{i}"
            fld[field] = params[var_name.to_sym] if params[var_name.to_sym]
          else
            fld[field] = params[field_name] if params[field_name]
          end
        end
      end
    elsif params[:button] == "accept"
      if !session[:field_data][:name] || session[:field_data][:name] == ""
        add_flash(I18n.t("flash.edit.field_required", :field => "Name"), :error)
        return
      end
      new_fields = {}
      field_attributes.each_with_object({}) { |field| new_fields[field] = @edit[:new_field][field] }
      @edit[:new][:fields].push(MiqAeField.new(new_fields))
      @edit[:new_field] = session[:field_data] = {}
    end
  end

  # Get variables from edit form
  def get_method_form_vars
    @ae_method = @edit[:ae_method_id] ? MiqAeMethod.find_by_id(from_cid(@edit[:ae_method_id])) : MiqAeMethod.new
    @in_a_form = true
    if params[:item].blank? && params[:button] != "accept" && params["action"] != "field_delete"
      # for method_inputs view
      @edit[:new][:name] = params[:method_name].blank? ? nil : params[:method_name] if params[:method_name]
      @edit[:new][:display_name] = params[:method_display_name].blank? ? nil : params[:method_display_name] if params[:method_display_name]
      @edit[:new][:location] = params[:method_location] if params[:method_location]
      @edit[:new][:location] ||= "inline"
      @edit[:new][:data] = params[:method_data] if params[:method_data]
      @edit[:new][:fields].each_with_index do |flds,i|
        @edit[:new][:fields][i][:name] = params["fields_name_#{i}".to_sym] if params["fields_name_#{i}".to_sym]
        @edit[:new][:fields][i][:default_value] = params["fields_value_#{i}".to_sym] if params["fields_value_#{i}".to_sym]
        @edit[:new][:fields][i][:default_value] = params["fields_password_value_#{i}".to_sym] if params["fields_password_value_#{i}".to_sym]
        @edit[:new][:fields][i][:datatype] = params["fields_datatype_#{i}".to_sym] if params["fields_datatype_#{i}".to_sym]
      end
      session[:field_data][:name] = @edit[:new_field][:name] = params[:field_name] if params[:field_name]
      session[:field_data][:datatype] = @edit[:new_field][:datatype] = params[:field_datatype] if params[:field_datatype]
      session[:field_data][:default_value] = @edit[:new_field][:default_value] = params[:field_default_value] if params[:field_default_value]
      session[:field_data][:default_value] = @edit[:new_field][:default_value] = params[:field_password_value] if params[:field_password_value]

      # for class_methods view
      @edit[:new][:name] = params[:cls_method_name].blank? ? nil : params[:cls_method_name] if params[:cls_method_name]
      @edit[:new][:display_name] = params[:cls_method_display_name].blank? ? nil : params[:cls_method_display_name] if params[:cls_method_display_name]
      @edit[:new][:location] = params[:cls_method_location] if params[:cls_method_location]
      @edit[:new][:location] ||= "inline"
      @edit[:new][:data] = params[:cls_method_data] if params[:cls_method_data]
      @edit[:new][:data] += "..."   if params[:transOne] && params[:transOne] == "1"          # Update the new data to simulate a change
      @edit[:new][:fields].each_with_index do |flds,i|
        @edit[:new][:fields][i][:name] = params["cls_fields_name_#{i}".to_sym] if params["cls_fields_name_#{i}".to_sym]
        @edit[:new][:fields][i][:default_value] = params["cls_fields_value_#{i}".to_sym] if params["cls_fields_value_#{i}".to_sym]
        @edit[:new][:fields][i][:default_value] = params["cls_fields_password_value_#{i}".to_sym] if params["cls_fields_password_value_#{i}".to_sym]
        @edit[:new][:fields][i][:datatype] = params["cls_fields_datatype_#{i}".to_sym] if params["cls_fields_datatype_#{i}".to_sym]
      end
      session[:field_data][:name] = @edit[:new_field][:name] = params[:cls_field_name] if params[:cls_field_name]
      session[:field_data][:datatype] = @edit[:new_field][:datatype] = params[:cls_field_datatype] if params[:cls_field_datatype]
      session[:field_data][:default_value] = @edit[:new_field][:default_value] = params[:cls_field_default_value] if params[:cls_field_default_value]
      session[:field_data][:default_value] = @edit[:new_field][:default_value] = params[:cls_field_password_value] if params[:cls_field_password_value]

      @edit[:new_field][:method_id] = @ae_method.id
      session[:field_data] ||= Hash.new
    elsif params[:button] == "accept"
      if @edit[:new_field].blank? || @edit[:new_field][:name].nil? || @edit[:new_field][:name] == ""
        add_flash(I18n.t("flash.edit.field_required", :field=>"Name"), :error)
        return
      end
      new_field = MiqAeField.new
      new_field.name = @edit[:new_field][:name]
      new_field.datatype = @edit[:new_field][:datatype]
      new_field.default_value = @edit[:new_field][:default_value]
      new_field.method_id = @ae_method.id
      @edit[:new][:fields].push(new_field)
      @edit[:new_field][:name] = @edit[:new_field][:datatype] = @edit[:new_field][:default_value] = ""
    end
  end

  # Get variables from edit form
  def get_ns_form_vars
    @ae_ns = MiqAeNamespace.find_by_id(from_cid(@edit[:ae_ns_id]))
    [:ns_name, :ns_description, :enabled].each do |field|
      if field == :enabled
        @edit[:new][field] = params[:ns_enabled] == "1" if params[:ns_enabled]
      else
        @edit[:new][field] = params[field].blank? ? nil : params[field] if params[field]
      end
    end
    @in_a_form = true
  end

  def get_instances_form_vars_for(prefix = nil)
    instance_column_names.each do |key|
      @edit[:new][:ae_inst][key] =
        params["#{prefix}inst_#{key}"].blank? ? nil : params["#{prefix}inst_#{key}"] if params["#{prefix}inst_#{key}"]
    end

    @ae_class.ae_fields.sort_by{|a| [a.priority.to_i]}.each_with_index do |fld,i|

      ['value', 'collect', 'on_entry', 'on_exit', 'on_error', 'max_retries', 'max_time'].each do |key|
        @edit[:new][:ae_values][i][key] = params["#{prefix}inst_#{key}_#{i}".to_sym]  if params["#{prefix}inst_#{key}_#{i}".to_sym]
      end
      @edit[:new][:ae_values][i]["value"]    = params["#{prefix}inst_password_value_#{i}".to_sym] if params["#{prefix}inst_password_value_#{i}".to_sym]
    end
  end

  # Get variables from edit form
  def get_instances_form_vars
    #resetting inst/class/values from id stored in @edit.
    @ae_inst = @edit[:ae_inst_id] ? MiqAeInstance.find(@edit[:ae_inst_id]) : MiqAeInstance.new
    @ae_class = MiqAeClass.find_by_id(from_cid(@edit[:ae_class_id]))
    @ae_values = Array.new

    @ae_class.ae_fields.sort_by{|a| [a.priority.to_i]}.each do |fld|
      val = MiqAeValue.find_by_field_id_and_instance_id(fld.id.to_i,@ae_inst.id.to_i)
      if val.nil?
        val = MiqAeValue.new
        val.field_id = fld.id.to_i
        val.instance_id = @ae_inst.id.to_i
      end
      @ae_values.push(val)
    end

    if x_node.split('-').first == "aei"
      # for instance_fields view
      get_instances_form_vars_for
    else
      # for class_instances view
      get_instances_form_vars_for("cls_")
    end
  end

  # Set record variables to new values
  def set_record_vars(miqaeclass)
    miqaeclass.name = @edit[:new][:name].strip unless @edit[:new][:name].blank?
    miqaeclass.display_name = @edit[:new][:display_name]
    miqaeclass.description = @edit[:new][:description]
    miqaeclass.inherits = @edit[:new][:inherits]
    ns = x_node.split("-")
    if ns.first == "aen" && !miqaeclass.namespace_id
      rec = MiqAeNamespace.find(from_cid(ns[1]))
      miqaeclass.namespace_id = rec.id.to_i
      #miqaeclass.namespace = rec.name
    end
  end

  # Set record variables to new values
  def set_method_record_vars(miqaemethod)
    miqaemethod.name = @edit[:new][:name].strip unless @edit[:new][:name].blank?
    miqaemethod.display_name = @edit[:new][:display_name]
    miqaemethod.scope = @edit[:new][:scope]
    miqaemethod.location = @edit[:new][:location]
    miqaemethod.language = @edit[:new][:language]
    miqaemethod.data = @edit[:new][:data]
    miqaemethod.class_id = from_cid(@edit[:ae_class_id])
  end

  # Set record variables to new values
  def ns_set_record_vars(miqaens)
    miqaens.name        = @edit[:new][:ns_name].strip unless @edit[:new][:ns_name].blank?
    miqaens.description = @edit[:new][:ns_description]
    if @edit[:new][:domain]
      miqaens.enabled     = @edit[:new][:enabled]
      # set highest priority on new records.
      miqaens.priority    = MiqAeDomain.highest_priority + 1 unless miqaens.id
      miqaens.parent_id   = nil
    else
      miqaens.parent_id   = from_cid(x_node.split('-')[1]) unless miqaens.id
    end
  end

  # Set record variables to new values
  def set_field_vars(miqaefields)
    to_delete = Array.new     # id's of records to be deleted
    flds_flg = true
    @new_ids = Array.new
    miqaefields.each do |f|
      @new_ids.push(f.id) if !@new_ids.include?(f.id)
    end

    @edit[:new][:fields].each_with_index do |fld,i|
      if i <= miqaefields.length-1 && (@new_ids.include?(fld.id.to_i) || fld.id.to_s == "0" )   # until it reaches current fields length || if fld exists in current flds but was updated || if fld is marked for deletion
        if miqaefields[i].attributes != fld.attributes && fld.id.to_s != "0"
          miqaefields[i] = fld
        elsif fld.id.to_s == "0"        # delete any fields marked for deletion
          to_delete.push(miqaefields[i].id)
        end
      else
        if fld.id.blank?          # add new fields
          miqaefields.push(fld)
        end
      end
    end

    #reset priority to be in order 1..3
    i = 0
    miqaefields.sort_by{|a| [a.priority.to_i]}.each do |fld|
      if !to_delete.include?(fld.id) || fld.id.blank?
        i += 1
        fld.priority = i
      end
    end
    flds_flg = false if i <= 0

    return to_delete, flds_flg
  end
  alias_method :set_input_vars, :set_field_vars

  # Set record variables to new values
  def set_instances_record_vars(miqaeinst)
    instance_column_names.each do |attr|
      miqaeinst.send("#{attr}=", @edit[:new][:ae_inst][attr].strip)
    end
    miqaeinst.class_id = from_cid(@edit[:ae_class_id])
  end

  # Set record variables to new values
  def set_instances_value_vars(vals)
    vals.each_with_index do |v,i|
      value_column_names.each do |attr|
        v.send("#{attr}=", @edit[:new][:ae_values][i][attr]) if @edit[:new][:ae_values][i][attr]
      end
    end
  end

  def fields_seq_edit_screen(id)
    @edit = Hash.new
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @ae_class = MiqAeClass.find_by_id(from_cid(id))
    @edit[:rec_id] = @ae_class ? @ae_class.id : nil
    @edit[:ae_class_id] = @ae_class.id
    @edit[:new][:fields] = @ae_class.ae_fields.deep_clone
    @edit[:new][:fields_list] = Array.new
    @edit[:new][:fields].sort_by{|a| [a.priority.to_i]}.each do |f|
      @edit[:new][:fields_list].push("#{f.display_name} (#{f.name})")
    end
    @edit[:key] = "fields_edit__seq"
    @edit[:current] = copy_hash(@edit[:new])
    @right_cell_text = "Edit of Class Schema Sequence '#{@ae_class.name}'"
    session[:edit] = @edit
  end

  def move_selected_fields_up(available_fields, selected_fields, display_name)
    if no_items_selected?(selected_fields)
      add_flash(I18n.t("flash.edit.no_fields_to_move.up", :field => display_name), :error)
      return
    end
    consecutive, first_idx, last_idx = selected_consecutive?(available_fields, selected_fields)
    if consecutive
      if first_idx > 0
        available_fields[first_idx..last_idx].reverse.each do |field|
          pulled = available_fields.delete(field)
          available_fields.insert(first_idx - 1, pulled)
        end
      end
    else
      add_flash(I18n.t("flash.edit.select_fields_to_move.up", :field => display_name), :error)
    end
    @selected = selected_fields
  end

  def move_selected_fields_down(available_fields, selected_fields, display_name)
    if no_items_selected?(selected_fields)
      add_flash(I18n.t("flash.edit.no_fields_to_move.down", :field => display_name), :error)
      return
    end
    consecutive, first_idx, last_idx = selected_consecutive?(available_fields, selected_fields)
    if consecutive
      if last_idx < available_fields.length - 1
        insert_idx = last_idx + 1   # Insert before the element after the last one
        insert_idx = -1 if last_idx == available_fields.length - 2 # Insert at end if 1 away from end
        available_fields[first_idx..last_idx].each do |field|
          pulled = available_fields.delete(field)
          available_fields.insert(insert_idx, pulled)
        end
      end
    else
      add_flash(I18n.t("flash.edit.select_fields_to_move.down", :field => display_name), :error)
    end
    @selected = selected_fields
  end

  def no_items_selected?(field_name)
    !field_name || field_name.length == 0 || field_name[0] == ""
  end

  def selected_consecutive?(available_fields, selected_fields)
    first_idx = last_idx = 0
    available_fields.each_with_index do |nf, idx|
      first_idx = idx if nf == selected_fields.first
      if nf == selected_fields.last
        last_idx = idx
        break
      end
    end
    if last_idx - first_idx + 1 > selected_fields.length
      return [false, first_idx, last_idx]
    else
      return [true, first_idx, last_idx]
    end
  end

  def edit_domain_or_namespace
    obj = find_checked_items
    obj = [x_node] if obj.nil? && params[:id]
    @ae_ns = MiqAeNamespace.find(from_cid(obj[0].split('-')[1]))
    if @ae_ns.domain? && !@ae_ns.editable?
      add_flash(I18n.t("flash.cant_edit_read_only",
                       :model => ui_lookup(:model => "MiqAeDomain"),
                       :name  => @ae_ns.name),
                :error)
    else
      ns_set_form_vars(@ae_ns.domain? ? "MiqAeDomain" : "MiqAeNamespace")
      @in_a_form = true
      session[:changed] = @changed = false
    end
    replace_right_cell
  end

  def new_ns
    assert_privileges("miq_ae_namespace_new")
    new_domain_or_namespace("MiqAeNamespace")
  end

  def new_domain
    assert_privileges("miq_ae_domain_new")
    new_domain_or_namespace("MiqAeDomain")
  end

  def new_domain_or_namespace(typ)
    @ae_ns = MiqAeNamespace.new
    ns_set_form_vars(typ)
    @in_a_form = true
    replace_right_cell
  end

  # Set form variables for edit
  def ns_set_form_vars(typ)
    session[:field_data] = session[:edit] = {}
    @edit = {
      :ae_ns_id => @ae_ns.id,
      :current  => {},
      :key      => "aens_edit__#{@ae_ns.id || "new"}",
      :rec_id   => @ae_ns.id || nil
    }
    @edit[:new] = {
      :ns_name        => @ae_ns.name,
      :ns_description => @ae_ns.description
    }
    # set these field for a new domain or when existing record is a domain
    @edit[:new].merge!(:domain => true, :enabled => @ae_ns.enabled) if typ == "MiqAeDomain"
    @edit[:current] = @edit[:new].dup
    @right_cell_text = ns_right_cell_text
    session[:edit] = @edit
  end

  def ns_right_cell_text
    model = ui_lookup(:model => @edit[:new][:domain] ? "MiqAeDomain" : "MiqAeNamespace")
    name_for_msg = @edit[:rec_id].nil? ? "cell_header.adding_model_record" : "cell_header.editing_model_record"
    options = @edit[:rec_id].nil? ? {:model => model} : {:model => model, :name => @ae_ns.name}
    I18n.t(name_for_msg, options)
  end

  def priority_edit_screen
    @in_a_form = true
    @edit = {
      :key => "priority__edit"
    }
    @edit[:new] = {
      :domain_order => []
    }
    domains = MiqAeDomain.order('priority DESC')
    order = @edit[:new][:domain_order]
    domains.collect { |d| order.push("#{d.editable? ? d.name : add_read_only_suffix(d.name)}") unless d.priority == 0 }
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit]  = @edit
  end

  def priority_get_form_vars
    @in_a_form = true
    move_selected_fields_up(@edit[:new][:domain_order], params[:seq_fields], "Domains")   if params[:button] == "up"
    move_selected_fields_down(@edit[:new][:domain_order], params[:seq_fields], "Domains") if params[:button] == "down"
    unless @flash_array
      @refresh_div     = "domains_list"
      @refresh_partial = "domains_priority_form"
    end
  end

  def domain_toggle(locked)
    assert_privileges("miq_ae_domain_#{locked ? 'lock' : 'unlock'}")
    action = locked ? "Locked" : "Unlocked"
    if params[:id].nil?
      add_flash(I18n.t("flash.no_records_selected_to_be_marked",
                       :model  => ui_lookup(:model => "MiqAeDomain"),
                       :action => action),
                :error)
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    end
    domain_toggle_lock(params[:id], locked)
    add_flash(I18n.t("flash.selected_records_were_marked",
                     :model  => ui_lookup(:model => "MiqAeDomain"),
                     :action => action),
              :info, true) unless flash_errors?
    replace_right_cell([:ae])
  end

  def domain_lock
    domain_toggle(true)
  end

  def domain_unlock
    domain_toggle(false)
  end

  def domain_toggle_lock(domain_id, lock_value)
    domain        = MiqAeNamespace.find_by_id(domain_id)
    domain.system = lock_value
    domain.save!
  end

  def get_session_data
    @layout     = "miq_ae_class"
    @title      = "Datastore"
    @lastaction = session[:aeclass_lastaction]
    @record     = session[:record]
    @edit       = session[:edit]
  end

  def set_session_data
    session[:aeclass_lastaction] = @lastaction
    session[:record]             = @record
    session[:edit]               = @edit
  end
end
