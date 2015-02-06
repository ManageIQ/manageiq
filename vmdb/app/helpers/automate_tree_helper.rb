module AutomateTreeHelper
  def at_tree_select_toggle(edit_key)
    build_ae_tree(:automate, :automate_tree)
    render :update do |page|
      tree_close = proc do
        @edit[:ae_tree_select] = false
        @changed = (@edit[:new] != @edit[:current])
        @changed = @edit[:new][:override_source] if params[:controller] == "miq_ae_class" &&
                                                    @edit[:new][:namespace].nil?
        page << javascript_hide("ae_tree_select_div")
        page << javascript_hide("blocker_div")
        page << javascript_for_miq_button_visibility(@changed)
        page << "miqSparkle(false);"
      end

      case params[:button]
      when 'submit'
        @edit[:new][@edit[:ae_field_typ]] = @edit[:active_id]
        page << set_element_visible("#{edit_key}_div", true)
        @edit[:new][edit_key] = @edit[:automate_tree_selected_path]
        if @edit[:new][edit_key]
          page << "$('##{edit_key}').val('#{@edit[:new][edit_key]}');"
          page << "$('##{edit_key}').prop('title', '#{@edit[:new][edit_key]}');"
        end
        page.replace("form_div", :partial => "copy_objects_form") if params[:controller] == "miq_ae_class"
        tree_close.call

      when 'cancel'
        @changed = @edit[:new] != @edit[:current]
        tree_close.call

      else
        @edit[:ae_field_typ] = params[:typ]
        @changed = @edit[:new][edit_key] != @edit[:automate_tree_selected_path]
        self.x_active_tree = :automate_tree
        page << javascript_show("ae_tree_select_div")
        page << javascript_show("blocker_div")
        @edit[:ae_tree_select] = true
        type =  @edit[:ae_field_typ] || params[:typ]
        validnode = true
        @edit[:current][:selected] = @edit[:new][:selected].nil? ? "" : @edit[:new][:selected]
        if @edit[:new][type].nil?
          @edit[:new][:selected] = "root"
          validnode = false
        else
          @edit[:new][:selected] = @edit[:new][type]
        end
        if x_node(:automate_tree)
          page << javascript_for_ae_node_selection(@edit[:new][:selected], @edit[:current][:selected], validnode)
          page << "cfmeDynatree_activateNodeSilently('automate_tree', '#{@edit[:new][:selected]}');"
        end
      end
    end
  end

  def at_tree_select(edit_key)
    id = from_cid(params[:id].split('_').last.split('-').last)
    if params[:id].start_with?("aei-")
      record = MiqAeInstance.find_by_id(id)
    elsif params[:id].start_with?("aen-") && controller_name == "miq_ae_class"
      record = MiqAeNamespace.find_by_id(id)
      record = nil if record.domain?
    end

    @edit[:new][edit_key] = @edit[edit_key] if @edit[:new][edit_key].nil?
    validnode = false
    @edit[:current][:selected] = @edit[:new][:selected].nil? ? "" : @edit[:new][:selected]
    @edit[:new][:selected] = params[:id]

    if record
      validnode = true
      @edit[:automate_tree_selected_path] =
          controller_name == "miq_ae_class" ? record.fqname_sans_domain : record.fqname
      # save selected id in edit until save button is pressed
      @edit[:active_id] = params[:id]
      @changed = @edit[:new][edit_key] != @edit[:automate_tree_selected_path]
    end
    render :update do |page|
      page << javascript_for_miq_button_visibility(@changed, 'automate')
      page << javascript_for_ae_node_selection(@edit[:new][:selected], @edit[:current][:selected], validnode)
    end
  end
end
