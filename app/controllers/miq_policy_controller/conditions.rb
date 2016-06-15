module MiqPolicyController::Conditions
  extend ActiveSupport::Concern

  def condition_edit
    case params[:button]
    when "cancel"
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("condition_edit__#{id}", "replace_cell__explorer")
      @condition = @edit[:condition_id] ? Condition.find_by_id(@edit[:condition_id]) : Condition.new
      if @condition && @condition.id
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => "#{ui_lookup(:model => @edit[:new][:towhat])} #{ui_lookup(:model => "Condition")}", :name => @condition.description})
      else
        add_flash(_("Add of new %{model} was cancelled by the user") %
          {:model => "#{ui_lookup(:model => @edit[:new][:towhat])} #{ui_lookup(:model => "Condition")}"})
      end
      @edit = nil
      get_node_info(x_node)
      replace_right_cell(@nodetype)
      return
    when "reset", nil # Reset or first time in
      condition_build_edit_screen
      @sb[:action] = "condition_edit"
      add_flash(_("Ruby scripts are no longer supported in expressions, please change or remove them."), :warning) if @edit[:current][:expression].key?('RUBY')
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("co")
      return
    end

    # Load @edit/vars for other buttons
    id = params[:id] || "new"
    return unless load_edit("condition_edit__#{params[:button] == "add" ? "new" : id}", "replace_cell__explorer")
    @condition = @edit[:condition_id] ? Condition.find_by_id(@edit[:condition_id]) : Condition.new

    case params[:button]
    when "save", "add"
      assert_privileges("condition_#{@condition.id ? "edit" : "new"}")
      policy = MiqPolicy.find(from_cid(@sb[:node_ids][x_active_tree]["p"])) unless x_active_tree == :condition_tree
      adding = @condition.id.blank?
      condition = adding ? Condition.new : Condition.find(@condition.id)  # Get new or existing record
      condition.description = @edit[:new][:description]
      condition.notes = @edit[:new][:notes]
      condition.modifier = @edit[:new][:modifier]
      condition.towhat = @edit[:new][:towhat] if adding # Set the proper model if adding a record
      exp_remove_tokens(@edit[:new][:expression])
      condition.expression = MiqExpression.new(@edit[:new][:expression])
      exp_remove_tokens(@edit[:new][:applies_to_exp])
      condition.applies_to_exp = @edit[:new][:applies_to_exp]["???"] ? nil : MiqExpression.new(@edit[:new][:applies_to_exp])
      if condition.expression.kind_of?(MiqExpression) &&
         condition.expression.exp["???"]
        add_flash(_("A valid expression must be present"), :error)
      end
      if condition.valid? && !@flash_array && condition.save
        if adding && x_active_tree != :condition_tree # If adding to a policy
          policy.conditions.push(condition)           #   add condition to the policy
          policy.save
        end
        AuditEvent.success(build_saved_audit(condition, params[:button] == "add"))
        flash_key = params[:button] == "save" ? _("%{model} \"%{name}\" was saved") :
                                                _("%{model} \"%{name}\" was added")
        add_flash(flash_key % {:model => ui_lookup(:model => "Condition"), :name => @edit[:new][:description]})
        @edit = nil
        @nodetype = "co"
        if adding # If add
          condition_get_info(condition)
          case x_active_tree
          when :condition_tree
            @new_condition_node = "xx-#{condition.towhat.downcase}_co-#{to_cid(condition.id)}"
            replace_right_cell("co", [:condition])
          when :policy_tree
            node_ids = @sb[:node_ids][x_active_tree]  # Get the selected node ids
            @new_policy_node = "xx-#{policy.mode.downcase}_xx-#{policy.mode.downcase}-#{policy.towhat.downcase}_p-#{node_ids["p"]}_co-#{to_cid(condition.id)}"
            replace_right_cell("co", [:policy_profile, :policy, :condition])
          when :policy_profile_tree
            node_ids = @sb[:node_ids][x_active_tree]  # Get the selected node ids
            @new_profile_node = "pp-#{node_ids["pp"]}_p-#{node_ids["p"]}_co-#{to_cid(condition.id)}"
            replace_right_cell("co", [:policy_profile, :policy, :condition])
          end
        else
          condition_get_info(Condition.find(condition.id))
          replace_right_cell("co", [:policy_profile, :policy, :condition])
        end
      else
        condition.errors.each do |field, msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        replace_right_cell("co")
      end
    when "expression", "applies_to_exp"
      session[:changed] = (@edit[:new] != @edit[:current])
      @expkey = params[:button].to_sym
      @edit[:expression_table] = @edit[:new][:expression] == {"???" => "???"} ? nil : exp_build_table(@edit[:new][:expression])
      @edit[:scope_table] = @edit[:new][:applies_to_exp] == {"???" => "???"} ? nil : exp_build_table(@edit[:new][:applies_to_exp])
      replace_right_cell("co")
    end
  end

  # Remove a condition from a policy
  def condition_remove
    assert_privileges("condition_remove")
    policy = MiqPolicy.find(params[:policy_id])
    condition = Condition.find(params[:id])
    cdesc = condition.description
    policy.conditions.delete(Condition.find(params[:id]))
    AuditEvent.success(:event        => "miqpolicy_condition_removed",
                       :target_id    => policy.id,
                       :target_class => "MiqPolicy",
                       :userid       => session[:userid],
                       :message      => _("Condition record ID %{param_id} was removed from Policy ID %{policy_id}") %
                                          {:param_id => params[:id], :policy_id => policy.id})
    add_flash(_("Condition \"%{cond_name}\" has been removed from Policy \"%{pol_name}\"") % {:cond_name => cdesc, :pol_name => policy.description})
    policy_get_info(policy)
    @nodetype = "p"
    nodes = x_node.split("_")
    nodes.pop
    @new_policy_node = self.x_node = nodes.join("_")
    replace_right_cell("p", [:policy_profile, :policy])
  end

  def condition_delete
    assert_privileges("condition_delete")
    conditions = []
    # showing 1 condition, delete it
    con = Condition.find_by_id(params[:id])
    if params[:id].nil? || con.nil?
      add_flash(_("%{models} no longer exists") % {:models => ui_lookup(:model => "Condition")},
                :error)
    else
      conditions.push(params[:id])
      @new_condition_node = "xx-#{con.towhat.camelize(:lower)}"
    end
    process_conditions(conditions, "destroy") unless conditions.empty?
    get_node_info(@new_condition_node)
    replace_right_cell("xx", [:condition])
  end

  def condition_field_changed
    return unless load_edit("condition_edit__#{params[:id]}", "replace_cell__explorer")
    @condition = @edit[:condition_id] ? Condition.find_by_id(@edit[:condition_id]) : Condition.new

    @edit[:new][:description] = params[:description].blank? ? nil : params[:description] if params[:description]
    @edit[:new][:notes] = params[:notes].blank? ? nil : params[:notes] if params[:notes]

    send_button_changes
  end

  private

  def process_conditions(conditions, task)
    process_elements(conditions, Condition, task)
  end

  def condition_build_edit_screen
    @edit = {}
    @edit[:new] = {}
    @edit[:current] = {}

    if params[:copy]  # If copying, create a new condition based on the original
      cond = Condition.find(params[:id])
      @condition = cond.dup.tap { |c| c.name = nil }
    else
      @condition = params[:id] && params[:typ] != "new" ? Condition.find(params[:id]) : Condition.new     # Get existing or new record
    end
    @edit[:key] = "condition_edit__#{@condition.id || "new"}"
    @edit[:rec_id] = @condition.id || nil

    if params[:id] && params[:typ] != "new"   # If editing existing condition, grab model
      @edit[:new][:towhat] = Condition.find(params[:id]).towhat
    else
      @edit[:new][:towhat] = x_active_tree == :condition_tree ? @sb[:folder].camelize : MiqPolicy.find(from_cid(@sb[:node_ids][x_active_tree]["p"])).towhat
    end

    @edit[:condition_id] = @condition.id
    @edit[:new][:description] = @condition.description
    @edit[:new][:notes] = @condition.notes
    @edit[:new][:modifier] = @condition.modifier.nil? ? "allow" : @condition.modifier

    @edit[:new][:expression] = @condition.expression.kind_of?(MiqExpression) ? @condition.expression.exp : nil
    @edit[:new][:applies_to_exp] = @condition.applies_to_exp.kind_of?(MiqExpression) ? @condition.applies_to_exp.exp : nil

    # Populate exp editor fields for the expression column
    @edit[:expression] ||= {}                                     # Create hash for this expression, if needed
    @edit[:expression][:expression] = []                         # Store exps in an array
    @edit[:expression][:exp_idx] = 0                                    # Start at first exp
    if @edit[:new][:expression].blank?
      @edit[:expression][:expression] = {"???" => "???"}                  # Set as new exp element
      @edit[:new][:expression] = copy_hash(@edit[:expression][:expression])   # Copy to new exp
    else
      @edit[:expression][:expression] = copy_hash(@edit[:new][:expression])
    end
    @edit[:expression_table] = @edit[:expression][:expression] == {"???" => "???"} ? nil : exp_build_table(@edit[:expression][:expression])

    @expkey = :expression                                               # Set expression key to expression
    exp_array(:init, @edit[:expression][:expression])                   # Initialize the exp array
    @edit[:expression][:exp_table] = exp_build_table(@edit[:expression][:expression])
    @edit[:expression][:exp_model] = @edit[:new][:towhat]               # Set model for the exp editor

    # Populate exp editor fields for the applies_to_exp column
    @edit[:applies_to_exp] ||= {}                                   # Create hash for this expression, if needed
    @edit[:applies_to_exp][:expression] = []                       # Store exps in an array
    @edit[:applies_to_exp][:exp_idx] = 0                                  # Start at first exp
    if @edit[:new][:applies_to_exp].blank?
      @edit[:applies_to_exp][:expression] = {"???" => "???"}                # Set as new exp element
      @edit[:new][:applies_to_exp] = copy_hash(@edit[:applies_to_exp][:expression]) # Copy to new exp
    else
      @edit[:applies_to_exp][:expression] = copy_hash(@edit[:new][:applies_to_exp])
    end
    @edit[:scope_table] = @edit[:applies_to_exp][:expression] == {"???" => "???"} ? nil : exp_build_table(@edit[:applies_to_exp][:expression])

    @expkey = :applies_to_exp                                             # Set temporarily while building applies_to_exp exp editor vars
    exp_array(:init, @edit[:applies_to_exp][:expression])                 # Initialize the exp array
    @edit[:applies_to_exp][:exp_table] = exp_build_table(@edit[:applies_to_exp][:expression])
    @expkey = :expression                                                 # Reset to default to editing the expression column
    @edit[:applies_to_exp][:exp_model] = @edit[:new][:towhat]             # Set model for the exp editor

    @edit[:current] = copy_hash(@edit[:new])

    @embedded = true
    @in_a_form = true
    @edit[:current][:add] = true if @edit[:condition_id].nil?         # Force changed to be true if adding a record
    session[:changed] = (@edit[:new] != @edit[:current])
  end

  def condition_get_all_folders
    @folders = MiqPolicy::UI_FOLDERS.collect(&:name)
    @right_cell_text = _("All %{models}") % {:models => ui_lookup(:models => "Condition")}
    @right_cell_div = "condition_folders"
  end

  def condition_get_all
    @conditions = Condition.all.sort_by { |c| c.description.downcase }
    set_search_text
    @conditions = apply_search_filter(@search_text, @conditions) unless @search_text.blank?
    @right_cell_text = _("All %{models}") % {:models => ui_lookup(:models => "Condition")}
    @right_cell_div = "condition_list"
  end

  # Get information for a condition
  def condition_get_info(condition)
    @record = @condition = condition
    @right_cell_text = _("%{model} \"%{name}\"") % {:model => ui_lookup(:model => "Condition"), :name => condition.description}
    @right_cell_div = "condition_details"
    @expression_table = @condition.expression.kind_of?(MiqExpression) ? exp_build_table(@condition.expression.exp) : nil
    @applies_to_exp_table = @condition.applies_to_exp.kind_of?(MiqExpression) ? exp_build_table(@condition.applies_to_exp.exp) : nil
    if x_active_tree == :condition_tree
      @condition_policies = @condition.miq_policies.sort_by { |p| p.description.downcase }
    else
      @condition_policy = MiqPolicy.find(from_cid(@sb[:node_ids][x_active_tree]["p"]))
    end
    add_flash(_("Ruby scripts are no longer supported in expressions, please change or remove them."), :warning) if @condition.expression.exp.key?('RUBY')
  end
end
