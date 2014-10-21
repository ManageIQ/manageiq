module MiqAeCustomizationController::CustomButtons
  extend ActiveSupport::Concern

  def automate_button
    @in_a_form = true
    @resolve = Hash.new if params[:button] == "reset"
    if params[:button] == "cancel_simulate"
      #resetting changed, when coming back from simulate screen.
      @changed = session[:changed]
      session[:changed] =~ session[:changed]
      @edit = session[:edit] = nil
      @custom_button = @edit[:custom_button] if @edit && @edit[:custom_button]
    else
      @edit = nil
    end
    explorer
  end

  private ###########

  def buttons_node_image(node)
    case node
    when "ExtManagementSystem"
      return "ext_management_system"
    when "MiqTemplate"
      return "vm"
    else
      return node.downcase
    end
  end

  def ab_get_node_info(node)
    @nodetype = node.split("_")
    nodeid = node.split("-")

    #initializing variables to hold data for selected node
    @sb[:obj_list] = nil
    @temp[:custom_button] = nil
    @sb[:button_groups] = nil
    @sb[:buttons] = nil

    if @nodetype[0] == "root"
      @right_cell_text = _("All %s") % "Object Types"
      @sb[:obj_list] = Hash.new
      if session[:resolve]
        @resolve = session[:resolve]
      else
        build_resolve_screen
      end
      @resolve[:target_classes].each do |node|
        @sb[:obj_list][node[0]] = "ab_#{node[0]}"
      end
    elsif @nodetype[0] == "xx-ab" && nodeid.length == 2   # one of the CI's node selected
      @right_cell_text = _("%{typ} %{model}") % {:typ=>@sb[:target_classes].invert[@nodetype[2]], :model=>"Button Groups"}
      @sb[:applies_to_class] = x_node.split('-').last.split('_').last
      asets = CustomButtonSet.find_all_by_class_name(@nodetype[1])
      @sb[:button_groups] = Array.new
      @sb[:button_groups].push("[Unassigned Buttons]")
      if !asets.blank?
        asets.each do |aset|
          group = Hash.new
          group[:id] = aset.id
          group[:name] = aset.name
          group[:description] = aset.description
          group[:button_image] = aset.set_data[:button_image]
          @sb[:button_groups].push(group) if !@sb[:button_groups].include?(group)
        end
      end
    elsif @nodetype.length == 1 && nodeid[1] == "ub"        #Unassigned buttons group selected
      @sb[:buttons] = Array.new
      @right_cell_text = _("%{typ} %{model} \"%{name}\"") % {:typ=>@sb[:target_classes].invert[nodeid[2]], :model=>"Button Group", :name=>"Unassigned Buttons"}
      uri = CustomButton.buttons_for(nodeid[2]).sort{|a,b| a.name <=> b.name }
      if !uri.blank?
        uri.each do |b|
          if b.parent.nil?
            button = Hash.new
            button[:name] = b.name
            button[:id] = b.id
            button[:description] = b.description
            button[:button_image] = b.options[:button_image]
            @sb[:buttons].push(button)
          end
        end
      end
    elsif (@nodetype[0] == "xx-ab"  && nodeid.length == 4) || (nodeid.length == 4 && nodeid[1] == "ub")       # button selected
      @record = @temp[:custom_button] = CustomButton.find(from_cid(nodeid.last))
      build_resolve_screen
      @resolve[:new][:attrs] = Array.new
      if @temp[:custom_button].uri_attributes
        @temp[:custom_button].uri_attributes.each do |attr|
          if attr[0] != "object_name" && attr[0] != "request"
            @resolve[:new][:attrs].push(attr) unless @resolve[:new][:attrs].include?(attr)
          end
        end
        @resolve[:new][:object_request] = @temp[:custom_button].uri_attributes["request"]
      end
      @sb[:user_roles] = Array.new
      if @temp[:custom_button].visibility && @temp[:custom_button].visibility[:roles] && @temp[:custom_button].visibility[:roles][0] != "_ALL_"
#         User.roles.sort{|a,b| a.name <=> b.name}.each do |r|
#           @sb[:user_roles].push(r.description) if @temp[:custom_button].visibility[:roles].include?(r.name) && !@sb[:user_roles].include?(r.description)
        MiqUserRole.all.sort{|a,b| a.name <=> b.name}.each do |r|
          @sb[:user_roles].push(r.name) if @temp[:custom_button].visibility[:roles].include?(r.name)
        end
      end
      dialog_id = @temp[:custom_button].resource_action.dialog_id
      @sb[:dialog_label] = dialog_id ? Dialog.find_by_id(dialog_id).label : ""
#       @sb[:user_roles].sort!
      if @nodetype[0].starts_with?("-ub-")
        #selected button is under unassigned folder
        @resolve[:new][:target_class] = @sb[:target_classes].invert[@nodetype[0].split('-').last]
      else
        #selected button is under assigned folder
        @resolve[:new][:target_class] = @sb[:target_classes].invert[@nodetype[1]]
      end
      @right_cell_text = _("%{model} \"%{name}\"") % {:model=>"Button", :name=>@temp[:custom_button].name}
    else                # assigned buttons node/folder
      @sb[:applies_to_class] = @nodetype[1]
      @record = CustomButtonSet.find(from_cid(nodeid.last))
      @right_cell_text = _("%{typ} %{model} \"%{name}\"") % {:typ=>@sb[:target_classes].invert[@nodetype[2]], :model=>"Button Group", :name=>@record.name.split("|").first}
      @sb[:button_group] = Hash.new
      @sb[:button_group][:text] =
          @sb[:button_group][:hover_text] =
              @sb[:button_group][:display]
      @sb[:buttons] = Array.new
      button_order = @record[:set_data] && @record[:set_data][:button_order] ? @record[:set_data][:button_order] : nil
      if button_order     # show assigned buttons in order they were saved
        button_order.each do |bidx|
          @record.members.each do |b|
            if bidx == b.id
              button = Hash.new
              button[:name] = b.name
              button[:id] = b.id
              button[:description] = b.description
              button[:button_image] = b.options[:button_image]
              @sb[:buttons].push(button) if !@sb[:buttons].include?(button)
            end
          end
        end
      end
    end
    @right_cell_div  = "ab_list"
  end
end
