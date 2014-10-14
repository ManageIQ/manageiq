module OpsController::Settings::Tags
  extend ActiveSupport::Concern

  # AJAX routine for user selected
  def category_select
    render :update do |page|
      if params[:id] == "new"
        page.redirect_to :action => 'category_new'    # redirect to new
      else
        page.redirect_to :action => 'category_edit', :id=>params[:id], :field=>params[:field]   # redirect to edit
      end
    end
  end

  # AJAX driven routine to delete a category
  def category_delete
    category = Classification.find(params[:id])
    c_name = category.name
    audit = {:event=>"category_record_delete", :message=>"[#{c_name}] Record deleted", :target_id=>category.id, :target_class=>"Classification", :userid => session[:userid]}
    if category.destroy
      AuditEvent.success(audit)
      add_flash(I18n.t("flash.record.deleted",
                      :model=>ui_lookup(:model=>"Classification"),
                      :name=>c_name))
      category_get_all
      render :update do |page|                    # Use JS to update the display
        page.replace_html 'settings_co_categories', :partial => 'settings_co_categories_tab'
      end
    else
      category.errors.each { |field,msg| add_flash("#{field.to_s.capitalize} #{msg}", :error) }
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  def category_edit
    case params[:button]
    when "cancel"
      @category = session[:edit][:category] if session[:edit] && session[:edit][:category]
      if !@category || @category.id.blank?
        add_flash(I18n.t("flash.add.cancelled",
                      :model=>ui_lookup(:model=>"Classification")))
      else
        add_flash(I18n.t("flash.edit.cancelled",
                      :model=>ui_lookup(:model=>"Classification"),
                      :name=>@category.name))
      end
      get_node_info(x_node)
      @category = @edit = session[:edit] = nil    # clean out the saved info
      replace_right_cell(@nodetype)
    when "save", "add"
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("category_edit__#{id}","replace_cell__explorer")
      @ldap_group = @edit[:ldap_group] if @edit && @edit[:ldap_group]
      @category = @edit[:category] if @edit && @edit[:category]
      if @edit[:new][:name].blank?
        add_flash(I18n.t("flash.edit.field_required", :field=>"Name"), :error)
      end
      if @edit[:new][:description].blank?
        add_flash(I18n.t("flash.edit.field_required", :field=>"Display Name"), :error)
      end
      if @edit[:new][:example_text].blank?
        add_flash(I18n.t("flash.edit.field_required", :field=>"Description"), :error)
      end
      if @flash_array != nil
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
        return
      end
      if params[:button] == "add"
        begin
          Classification.create_category!(:name=>@edit[:new][:name],
                                :description=>@edit[:new][:description],
                                :single_value=>@edit[:new][:single_value],
                                :perf_by_tag=>@edit[:new][:perf_by_tag],
                                :example_text=>@edit[:new][:example_text],
                                :show=>@edit[:new][:show])
        rescue StandardError => bang
          add_flash(I18n.t("flash.error_during", :task=>"add") << bang.message, :error)
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
        else
          @category = Classification.find_by_description(@edit[:new][:description])
          AuditEvent.success(build_created_audit(@category, @edit))
          add_flash(I18n.t("flash.add.added",
                          :model=>ui_lookup(:model=>"Classification"),
                          :name=>@category.description))
          get_node_info(x_node)
          @category = @edit = session[:edit] = nil    # clean out the saved info
          replace_right_cell("root")
        end
      else
        update_category = Classification.find(@category.id)
        category_set_record_vars(update_category)
        begin
          update_category.save!
        rescue StandardError => bang
          update_category.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          @in_a_form = true
          session[:changed] = @changed
          @changed = true
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
        else
          add_flash(I18n.t("flash.edit.saved",
                          :model=>ui_lookup(:model=>"Classification"),
                          :name=>update_category.name))
          AuditEvent.success(build_saved_audit(update_category, params[:button] == "add"))
          session[:edit] = nil  # clean out the saved info
          get_node_info(x_node)
          @category = @edit = session[:edit] = nil    # clean out the saved info
          replace_right_cell("root")
        end
      end
    when "reset", nil # Reset or first time in
      if params[:id]
        @category = Classification.find(params[:id])
        category_set_form_vars
      else
        category_set_new_form_vars
      end
      @in_a_form = true
      session[:changed] = false
      if params[:button] == "reset"
        add_flash(I18n.t("flash.edit.reset"), :warning)
      end
      replace_right_cell("ce")
    end
  end

  # AJAX driven routine to check for changes in ANY field on the user form
  def category_field_changed
    return unless load_edit("category_edit__#{params[:id]}","replace_cell__explorer")
    category_get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page.replace(@refresh_div, :partial=>@refresh_partial,
                  :locals=>{:type=>"classifications", :action_url=>'category_field_changed'}) if @refresh_div
      page << javascript_for_miq_button_visibility_changed(@changed)
    end
  end

    # A new classificiation category was selected
  def ce_new_cat
    ce_get_form_vars
    if params[:classification_name]
      @cat = Classification.find_by_name(params["classification_name"])
      ce_build_screen                                         # Build the Classification Edit screen
      render :update do |page|                    # Use JS to update the display
        page.replace(:tab_div, :partial=>"settings_co_tags_tab")
      end
    end
  end

  # AJAX driven routine to select a classification entry
  def ce_select
    ce_get_form_vars
    if params[:id] == "new"
      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page.replace("classification_entries_div", :partial=>"classification_entries", :locals=>{:entry=>"new", :edit=>true})
        page << javascript_focus('entry_name')
        page << "$('entry_name').select();"
      end
      session[:entry] = "new"
    else
      entry = Classification.find(params[:id])
      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page.replace("classification_entries_div", :partial=>"classification_entries", :locals=>{:entry=>entry, :edit=>true})
        page << javascript_focus("entry_#{j_str(params[:field])}")
        page << "$('entry_#{j_str(params[:field])}').select();"
      end
      session[:entry] = entry
    end
  end

  # AJAX driven routine to add/update a classification entry
  def ce_accept
    ce_get_form_vars
    if session[:entry] == "new"
      entry = @cat.entries.create(:name        => params["entry"]["name"],
                                  :description => params["entry"]["description"])
    else
      entry = @cat.entries.find(session[:entry].id)
      if entry.name == params["entry"]["name"] && entry.description == params["entry"]["description"]
        no_changes = true
      else
        entry.name        = params["entry"]["name"]
        entry.description = params["entry"]["description"]
        entry.save
      end
    end
    if ! entry.errors.empty?
      entry.errors.each { |field,msg| add_flash("#{field.to_s.capitalize} #{msg}", :error) }
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page << javascript_focus('entry_name')
      end
      return
    end
    if session[:entry] == "new"
      AuditEvent.success(ce_created_audit(entry))
    else
      AuditEvent.success(ce_saved_audit(entry)) unless no_changes
    end
    ce_build_screen # Build the Classification Edit screen
    render :update do |page|
      page.replace(:tab_div, :partial => "settings_co_tags_tab")
      page << "$('#{entry.id}_tr').visualEffect('pulsate');" unless no_changes
    end
  end

  # AJAX driven routine to delete a classification entry
  def ce_delete
    ce_get_form_vars
    entry = @cat.entries.find(params[:id])
    audit = {:event=>"classification_entry_delete", :message=>"Category #{@cat.description} [#{entry.name}] record deleted", :target_id=>entry.id, :target_class=>"Classification", :userid => session[:userid]}
    if entry.destroy
      AuditEvent.success(audit)
      ce_build_screen                               # Build the Classification Edit screen
      render :update do |page|                      # Use JS to update the display
        page.replace(:tab_div, :partial=>"settings_co_tags_tab")
      end
    else
      entry.errors.each { |field,msg| add_flash("#{field.to_s.capitalize} #{msg}", :error) }
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page << javascript_focus('entry_name')
      end
    end
  end

  def ce_get_form_vars
    @edit = session[:edit]
    @cats = session[:config_cats]
    @cat = Classification.find_by_name(session[:config_cat])
    return
  end

  private

  # Build the classification edit screen from the category record in @cat
  def ce_build_screen
    session[:config_cats] = @cats
    session[:config_cat] = @cat.name
    session[:entry] = nil
  end

  # Build the audit object when a record is created, including all of the new fields
  def ce_created_audit(entry)
    msg = "Category #{@cat.description} [#{entry.name}] record created ("
    event = "classification_entry_add"
    i = 0
    params["entry"].each_key do |k|
      msg = msg + ", " if i > 0
      i += 1
      msg = msg +  k.to_s + ":[" + params["entry"][k].to_s + "]"
    end
    msg = msg + ")"
    audit = {:event=>event, :target_id=>entry.id, :target_class=>entry.class.base_class.name, :userid => session[:userid], :message=>msg}
  end

  # Build the audit object when a record is saved, including all of the changed fields
  def ce_saved_audit(entry)
    msg = "Category #{@cat.description} [#{entry.name}] record updated ("
    event = "classification_entry_update"
    i = 0
    if entry.name != session[:entry].name
      i += 1
      msg = msg +  "name:[" + session[:entry].name + "] to [" + entry.name + "]"
    end
    if entry.description != session[:entry].description
      msg = msg + ", " if i > 0
      i += 1
      msg = msg +  "description:[" + session[:entry].description + "] to [" + entry.description + "]"
    end
    msg = msg + ")"
    audit = {:event=>event, :target_id=>entry.id, :target_class=>entry.class.base_class.name, :userid => session[:userid], :message=>msg}
  end

  # Get variables from category edit form
  def category_get_form_vars
    @category = @edit[:category]
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:description] = params[:description] if params[:description]
#   if params[:show] == "1"
#     @edit[:new][:show] = true
#   elsif params[:show] == "null"
#     @edit[:new][:show] = false
#   end
    @edit[:new][:show] = (params[:show] == "1") if params[:show]
    @edit[:new][:perf_by_tag] = (params[:perf_by_tag] == "1") if params[:perf_by_tag]
    @edit[:new][:example_text] = params[:example_text] if params[:example_text]
#   if !@edit[:new][:name].blank? && !Classification.find_by_name(@edit[:new][:name]) && params[:button] != "add" && params[:single_value]
#     @edit[:new][:single_value] = (params[:single_value] == "1")
#   end
    @edit[:new][:single_value] = (params[:single_value] == "1") if params[:single_value]
  end

  def category_get_all
    cats = Classification.categories.sort{|a,b| a.name <=> b.name}  # Get the categories, sort by name
    @categories = Array.new                                       # Classifications array for first chooser
    cats.each do |c|
      if !c.read_only?    # Show the non-read_only categories
        cat = Hash.new
        cat[:id] = c.id
        cat[:description] = c.description
        cat[:name] = c.name
        cat[:show] = c.show
        cat[:single_value] = c.single_value
        cat[:perf_by_tag] = c.perf_by_tag
        cat[:default] = c.default
        @categories.push(cat)
      end
    end
  end

  # Set form variables for category add/edit
  def category_set_form_vars
    @edit = Hash.new
    @edit[:category] = @category
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "category_edit__#{@category.id || "new"}"
    @edit[:new][:name] = @category.name
    @edit[:new][:description] = @category.description
    @edit[:new][:show] = @category.show
    @edit[:new][:perf_by_tag] = @category.perf_by_tag
    @edit[:new][:default] = @category.default
    @edit[:new][:single_value] = @category.single_value
    @edit[:new][:example_text] = @category.example_text
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  # Set form variables for category add/edit
  def category_set_new_form_vars
    @edit = Hash.new
    @edit[:user] = @user
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "category_edit__new"
    @edit[:new][:name] = nil
    @edit[:new][:description] = nil
    @edit[:new][:show] = true
    @edit[:new][:perf_by_tag] = false
    @edit[:new][:default] = false
    @edit[:new][:single_value] = true
    @edit[:new][:example_text] = nil
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  # Set category record variables to new values
  def category_set_record_vars(category)
    category.description = @edit[:new][:description]
    category.example_text = @edit[:new][:example_text]
    category.show = @edit[:new][:show]
    category.perf_by_tag = @edit[:new][:perf_by_tag]
  end

end
