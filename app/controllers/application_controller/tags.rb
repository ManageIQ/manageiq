module ApplicationController::Tags
  extend ActiveSupport::Concern

  # Edit user, group or tenant tags
  def tagging_edit(db = nil, assert = true)
    assert_privileges("#{controller_for_common_methods}_tag") if assert
    @explorer = true if request.xml_http_request? # Ajax request means in explorer
    case params[:button]
    when "cancel"
      tagging_edit_tags_cancel
    when "save", "add"
      tagging_edit_tags_save
    when "reset", nil # Reset or first time in
      @tagging = session[:tag_db] = params[:db] ? params[:db] : db if params[:db] || db
      tagging_edit_tags_reset
    end
  end

  def service_tag
    tagging_edit('Service')
  end

  def container_tag
    tagging_edit('Container')
  end

  alias_method :image_tag, :tagging_edit
  alias_method :instance_tag, :tagging_edit
  alias_method :vm_tag, :tagging_edit
  alias_method :miq_template_tag, :tagging_edit
  alias_method :storage_tag, :tagging_edit
  alias_method :infra_networking_tag, :tagging_edit

  # New classification category chosen on the classify screen
  def classify_new_cat
    session[:cat] = Classification.find_by_name(params["classification"]["name"])
    classify_build_entries_pulldown

    render :update do |page|
      page << javascript_prologue
      page.replace("value_div", :partial => "layouts/classify_value")
    end
  end

  # Handle tag edit field changes
  def tag_edit_form_field_changed
    id = params[:id]
    return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}", "replace_cell__explorer")

    if params[:tag_cat]
      @edit[:cat] = Classification.find_by_id(params[:tag_cat])
      tag_edit_build_entries_pulldown
    elsif params[:tag_add]
      @edit[:new][:assignments].push(params[:tag_add].to_i)
      @assignments ||= Classification.find(@edit.fetch_path(:new, :assignments))
      @assignments.each_with_index do |a, a_idx|
        if a.parent.name == @edit[:cat].name && # If same category
           a.parent.single_value && #    single value category
           a.id != params[:tag_add].to_i           #    different tag
          @edit[:new][:assignments].delete(a.id)  # Remove prev tag from new
          @assignments.delete_at(a_idx)           # Remove prev tag from display
          break
        end
      end
    elsif params[:tag_remove]
      @edit[:new][:assignments].delete(params[:tag_remove].to_i)
    end
    @edit[:new][:assignments].sort!
    @assignments ||= Classification.find(@edit.fetch_path(:new, :assignments))

    tag_edit_build_entries_pulldown
    render :update do |page|
      page << javascript_prologue
      changed = (@edit[:new] != @edit[:current])
      if changed != session[:changed]
        session[:changed] = changed
        page << javascript_for_miq_button_visibility(changed)
      end
      page.replace("cat_tags_div", :partial => "layouts/tag_edit_cat_tags")
      page.replace("assignments_div", :partial => "layouts/tag_edit_assignments") unless params[:tag_cat]
      if params[:tag_add]
        page << jquery_pulsate_element("#{j_str(params[:tag_add])}_tr")
      end
    end
  end

  # Assign a classification entry to a set of objects
  def classify_assign
    entry = Classification.find_by_id(params["entry"]["id"])
    session[:tag_items].each do |item|
      entry.assign_entry_to(session[:tag_db].find(item))
    end
    classify_build_screen
    render :update do |page|
      page << javascript_prologue
      page.replace("value_div", :partial => "layouts/classify_value")
      page.replace("table_div", :partial => "layouts/classify_table")
      page << jquery_pulsate_element("#{entry.id}_tr")
    end
  end

  # Remove a classification entry from a set of objects
  def classify_remove
    entry = Classification.find_by_id(params["id"])
    session[:tag_items].each do |item|
      entry.remove_entry_from(session[:tag_db].find(item))
    end
    classify_build_screen
    render :update do |page|
      page << javascript_prologue
      page.replace("value_div", :partial => "layouts/classify_value")
      page.replace("table_div", :partial => "layouts/classify_table")
    end
  end

  def filters
    @in_a_form = true
    session[:filter_object] = Host.find(1)
    session[:cat] = nil
    classify_build_screen
  end

  private ############################

  def get_tag_items
    recs = []
    if !session[:checked_items].nil? && @lastaction == "set_checked_items"
      recs = session[:checked_items]
    else
      recs = find_checked_items
    end
    if recs.blank?
      recs = [params[:id]]
    end
    if recs.length < 1
      add_flash(_("One or more %{model} must be selected to Smart Tagging") %
        {:model => Dictionary.gettext(db.to_s, :type => :model, :notfound => :titleize, :plural => true)}, :error)
      @refresh_div = "flash_msg_div"
      @refresh_partial = "layouts/flash_msg"
      return
    else
      session[:tag_items] = recs    # Set the array of tag items
      session[:assigned_filters] = assigned_filters
    end
  end

  def tagging_edit_tags_reset
    get_tag_items if @explorer
    @object_ids = session[:tag_items]
    @sb[:rec_id] = params[:id] ? params[:id] : session[:tag_items][0]
    @tagging = session[:tag_db].to_s
    if params[:button] == "reset"
      id = params[:id] if params[:id]
      return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}")
      @object_ids = @edit[:object_ids]
    end
    tagging_tags_set_form_vars
    @display   = nil
    @in_a_form = true
    session[:changed] = false
    add_flash(_("All changes have been reset"), :warning) if params[:button] == "reset"
    @title = _('Tag Assignment')
    if tagging_explorer_controller?
      @refresh_partial = "layouts/tagging"
      replace_right_cell(:action => @sb[:action]) if params[:button]
    else
      render "shared/views/tagging_edit"
    end
  end

  # Set form vars for tag editor
  def tagging_tags_set_form_vars
    @edit = {}
    @edit[:new] = {}
    @edit[:key] = "#{@tagging}_edit_tags__#{@sb[:rec_id]}"
    @edit[:object_ids] = @object_ids
    @edit[:tagging] = @tagging
    tag_edit_build_screen
    build_targets_hash(@tagitems)

    @edit[:current] = copy_hash(@edit[:new])
  end

  def tagging_edit_tags_cancel
    id = params[:id]
    return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}")
    add_flash(_("Tag Edit was cancelled by the user"))
    session[:tag_items] = nil                                 # reset tag_items in session
    if tagging_explorer_controller?
      @edit = nil # clean out the saved info
      @sb[:action] = nil
      replace_right_cell
    else
      @edit = nil                               # clean out the saved info
      session[:flash_msgs] = @flash_array.dup   # Put msg in session for next transaction to display
      javascript_redirect previous_breadcrumb_url
    end
  end

  def tagging_edit_tags_save
    id = params[:id]
    return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}")

    tagging_save_tags

    if tagging_explorer_controller?
      @edit = nil # clean out the saved info
      @sb[:action] = nil
      replace_right_cell
    else
      @edit = nil
      session[:flash_msgs] = @flash_array.dup   # Put msg in session for next transaction to display
      javascript_redirect previous_breadcrumb_url
    end
  end

  def tagging_edit_tags_save_and_replace_right_cell
    id = params[:id]
    return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}", "replace_cell__explorer")

    tagging_save_tags

    get_node_info(x_node)
    @edit = nil
    replace_right_cell(:nodetype => @nodetype)
  end

  # Add/remove tags in a single transaction
  def tagging_save_tags
    Classification.bulk_reassignment({:model      => @edit[:tagging],
                                      :object_ids => @edit[:object_ids],
                                      :add_ids    => @edit[:new][:assignments] - @edit[:current][:assignments],
                                      :delete_ids => @edit[:current][:assignments] - @edit[:new][:assignments]
                                    })
  rescue => bang
    add_flash(_("Error during 'Save Tags': %{error_message}") % {:error_message => bang.message}, :error)
  else
    add_flash(_("Tag edits were successfully saved"))
  end

  # Build the tagging assignment screen
  def tagging_build_screen
    @tagitems = session[:tag_db].find(session[:tag_items]).sort_by(&:name)  # Get the db records that are being tagged
    @view = get_db_view(session[:tag_db])       # Instantiate the MIQ Report view object
    @view.table = MiqFilter.records2table(@tagitems, @view.cols + ['id'])

    session[:mytags] = @tagitems[0].tagged_with(:cat => session[:userid])   # Start with the first items tags
    @tagitems.each do |item|
      itemassign = item.tagged_with(:cat => session[:userid])               # Get each items tags
      session[:mytags].delete_if { |t| !itemassign.include?(t) }           # Remove any tags that are not in the new items tags
      break if session[:mytags].length == 0                               # Stop looking if no tags are left
    end
    tagging_build_tags_pulldown
    build_targets_hash(@tagitems)
  end

  # Build the pulldown containing the tags
  def tagging_build_tags_pulldown
    @mytags = Tag.all_tags(:cat => session[:userid]).sort     # Get all of the users tags
    unless session[:mytags].blank?
      session[:mytags].each do |t|                                    # Look thru the common tags
        @mytags.delete(t.name.split("/")[-1])                     # Remove any tags from the pulldown that are in the common tags
      end
    end
  end

  # Build the classification assignment screen
  def classify_build_screen
    cats = Classification.categories.select(&:show).sort_by(&:name) # Get the categories, sort by name
    @categories = {}    # Classifications array for first chooser
    cats.delete_if { |c| c.read_only? || c.entries.length == 0 }  # Remove categories that are read only or have no entries
    cats.each do |c|
      if c.single_value?
        @categories[c.description + " *"] = c.name
      else
        @categories[c.description] = c.name
      end
    end
    cats.each do |cat_key|
      if session[:assigned_filters].include?(cat_key.name.downcase)
        cats.delete(cat_key)
      end
    end
    session[:cat] ||= cats.first                                    # Set to first category, if not already set

    @tagitems = session[:tag_db].find(session[:tag_items]).sort_by(&:name)  # Get the db records that are being tagged

    @view = get_db_view(session[:tag_db])       # Instantiate the MIQ Report view object
    @view.table = MiqFilter.records2table(@tagitems, @view.cols + ['id'])

    session[:assignments] = Classification.find_assigned_entries(@tagitems[0])    # Start with the first items assignments
    @tagitems.each do |item|
      itemassign = Classification.find_assigned_entries(item)             # Get each items assignments
      session[:assignments].delete_if { |a| !itemassign.include?(a) } # Remove any assignments that are not in the new items assignments
      break if session[:assignments].length == 0                          # Stop looking if no assignments are left
    end
    if session[:assignments].length > 0                                             # if any assignments left
      session[:assignments].delete_if { |a| a.parent.read_only? }    # remove the ones from read only categories
    end
    classify_build_entries_pulldown
    build_targets_hash(@tagitems)
  end

  # Build the second pulldown containing the entries for the selected category
  def classify_build_entries_pulldown
    @entries = {}                   # Create new entries hash (2nd pulldown)
    session[:cat].entries.each do |e|     # Get all of the entries for the current category
      @entries[e.description] = e.id        # Add it to the hash
    end

    session[:assignments].each do |a|                           # Look thru the assignments
      if a.parent.description == session[:cat].description      # If they match the category
        @entries.delete(a.description)                          # Remove them from the selection list
      end
    end
  end

  # Build the @edit elements for the tag edit screen
  def tag_edit_build_screen
    cats = Classification.categories.select(&:show).sort_by(&:name) # Get the categories, sort by name
    @categories = {}    # Classifications array for first chooser
    cats.delete_if { |c| c.read_only? || c.entries.length == 0 }  # Remove categories that are read only or have no entries
    cats.each do |c|
      if c.single_value?
        @categories[c.description + " *"] = c.id
      else
        @categories[c.description] = c.id
      end
    end

    if ["User", "MiqGroup", "Tenant"].include?(@tagging)
      session[:assigned_filters] = []  # No view filters used for user/groups/tenants, set as empty for later methods
    else
      cats.each do |cat_key|  # not needed for user/group tags since they are not filtered for viewing
        if session[:assigned_filters].include?(cat_key.name.downcase)
          cats.delete(cat_key)
        end
      end
    end

    # Set to first category, if not already set
    @edit[:cat] ||= cats.min_by(&:description)

    unless @object_ids.blank?
      @tagitems = @tagging.constantize.where(:id => @object_ids).sort_by { |t| t.name.try(:downcase).to_s }
    end

    @view = get_db_view(@tagging)               # Instantiate the MIQ Report view object
    @view.table = MiqFilter.records2table(@tagitems, @view.cols + ['id'])

    # Start with the first items assignments
    @edit[:new][:assignments] =
      Classification.find_assigned_entries(@tagitems[0]).collect { |e| e.id unless e.parent.read_only? }
    @tagitems.each do |item|
      itemassign = Classification.find_assigned_entries(item).collect(&:id) # Get each items assignments
      @edit[:new][:assignments].delete_if { |a| !itemassign.include?(a) } # Remove any assignments that are not in the new items assignments
      break if @edit[:new][:assignments].length == 0                      # Stop looking if no assignments are left
    end
    @edit[:new][:assignments].sort!
    @assignments = Classification.find(@edit.fetch_path(:new, :assignments))
    tag_edit_build_entries_pulldown
  end

  # Build the second pulldown containing the entries for the selected category
  def tag_edit_build_entries_pulldown
    @entries = {}                   # Create new entries hash (2nd pulldown)
    @edit[:cat].entries.each do |e|       # Get all of the entries for the current category
      @entries[e.description] = e.id      # Add it to the hash
    end

    assignments = Classification.find(@edit.fetch_path(:new, :assignments))
    assignments.each do |a|                               # Look thru the assignments
      if a.parent.description == @edit[:cat].description  # If they match the category
        @entries.delete(a.description)                    # Remove them from the selection list
      end
    end
  end

  # Tag selected db records
  def tag(db = nil)
    assert_privileges(params[:pressed])
    @tagging = session[:tag_db] = db        # Remember the DB
    get_tag_items
    drop_breadcrumb(:name => _("Tag Assignment"), :url => "/#{session[:controller]}/tagging_edit")
    javascript_redirect :action => 'tagging_edit',
                         :id     => params[:id],
                         :db     => db,
                         :escape => false
  end

  # Getting my company tags and my tags to display on summary screen
  def get_tagdata(rec)
    session[:assigned_filters] = {}
    filters = Classification.find_assigned_entries(rec)
    filters.each do |a|
      path    = [:assigned_filters, a.parent.description]
      array   = session.fetch_path(path)
      array ||= session.store_path(path, [])
      array << a.description
    end
    session[:mytags] = rec.tagged_with(:cat => session[:userid])    # Start with the first items tags
  end

  def locals_for_tagging
    {:action_url   => 'tagging',
     :multi_record => true,
     :record_id    => @sb[:rec_id] || @edit[:object_ids] && @edit[:object_ids][0]
    }
  end

  def update_tagging_partials(presenter, r)
    presenter.update(:main_div, r[:partial => 'layouts/tagging',
                                  :locals  => locals_for_tagging])
    presenter.update(:form_buttons_div, r[:partial => 'layouts/x_edit_buttons',
                                          :locals  => locals_for_tagging])
  end
end
