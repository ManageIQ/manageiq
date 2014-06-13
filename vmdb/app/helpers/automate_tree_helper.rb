module AutomateTreeHelper
  def at_tree_select_toggle(edit_key)
    render :update do |page|
      tree_close = proc do
        @edit[:ae_tree_select] = false
        @changed = (@edit[:new] != @edit[:current])
        page << "$('ae_tree_select_div').hide();"
        page << "$('blocker_div').hide();"
        page << javascript_for_miq_button_visibility(@changed)
        page << "miqSparkle(false);"
      end

      case params[:button]
      when 'submit'
        el = "#{edit_key}_div"
        page << "if ($('#{el}')) $('#{el}').show();"
        # FIXME: replace with set_element_visible after 5.2
        @edit[:new][edit_key] = @edit[:automate_tree_fqname]
        if @edit[:new][edit_key]
          page << "$('#{edit_key}').value = '#{@edit[:new][edit_key]}';"
          page << "$('#{edit_key}').title = '#{@edit[:new][edit_key]}';"
        end
        tree_close.call

      when 'cancel'
        @changed = @edit[:new] != @edit[:current]
        tree_close.call

      else
        @edit[:ae_field_typ] = params[:typ]
        @changed = @edit[:new][edit_key] != @edit[:automate_tree_fqname]
        self.x_active_tree = :automate_tree
        page << "$('ae_tree_select_div').show();"
        page << "$('blocker_div').show();"
        @edit[:ae_tree_select] = true
        if x_node(:automate_tree)
          page << "cfmeDynatree_activateNodeSilently('#{x_node(:automate_tree)}', '#{x_node}');"
        end
      end
    end
  end

  def at_tree_select(edit_key)
    instance =
      MiqAeInstance.find_by_id(from_cid(params[:id].split('_').last.split('-').last)) if params[:id].start_with?("aei-")
    if instance
      @edit[:automate_tree_fqname] = instance.fqname
      # save selected id in edit until save button is pressed
      @edit[:active_id] = params[:id]
      @changed = @edit[:new][edit_key] != @edit[:automate_tree_fqname]
    end
    render :update do |page|
      page << javascript_for_miq_button_visibility(@changed)
    end
  end
end
