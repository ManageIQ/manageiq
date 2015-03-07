module ApplicationController::Tags
  extend ActiveSupport::Concern

  # Assign/unassign classifications to a set of objects
  def tagging
    @in_a_form = true
    drop_breadcrumb( {:name=>"Tag Assignment", :url=>"/#{session[:controller]}/tagging"} )
    session[:cat] = nil                 # Clear current category
    tagging_build_screen
    area = request.parameters["controller"]
    if role_allows(:feature=>"#{area}_tag")
      @tabs = [ ["tagging", nil], ["classifying","#{session[:customer_name]} Tags"], ["tagging", "MyTags"] ]
    else
      @tabs = [ ["tagging", nil], ["tagging", "MyTags"] ]
    end
    render(:action=>"show")
  end

  # Assign a tag to a set of objects
  def mytag_assign
    if ! params[:mytag][:value].blank?        # Did user pulldown a tag
      newtags = params[:mytag][:value]        # Yes, use it
    else
      newtags = params[:newtags]              # No, grab entered tags
      invalid_chars = newtags.gsub(/[\w\s]/, "")
      if invalid_chars != ""
        invalid_chars = invalid_chars.split(//).uniq.join # Get the unique invalid characters
        if invalid_chars.length > 1
          msg = "Invalid characters"
        else
          msg = "Invalid character"
        end
        add_flash(msg + " #{invalid_chars} found in entered tags, only letters, numbers, and underscores are allowed.", :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end
    end

    session[:tag_items].each do |item|
      session[:tag_db].find(item).tag_add(newtags, :cat=>session[:userid])
    end
    tagging_build_screen

    render :update do |page|
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      page.replace("tab_div", :partial=>"layouts/mytags")
      newtags.split.each do |tag|
        page << jquery_pulsate_element("mytag_#{j_str(tag.downcase)}")
      end
    end
  end

  # Remove a tag from a set of objects
  def mytag_remove
    session[:tag_items].each do |item|
      session[:tag_db].find(item).tag_remove(params[:tag], :cat=>session[:userid])
    end
    tagging_build_screen
    render :update do |page|
      page.replace("tab_div", :partial=>"layouts/mytags")
    end
  end

  # Edit user or group tags
  def tagging_edit(db=nil)
    assert_privileges("#{controller_for_common_methods}_tag")
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
  alias image_tag tagging_edit
  alias instance_tag tagging_edit
  alias vm_tag tagging_edit
  alias miq_template_tag tagging_edit
  alias service_tag tagging_edit

  # Assign/unassign classifications to a set of objects
  def classifying
    drop_breadcrumb( {:name=>"Tag Assignment", :url=>"/#{request.parameters["controller"]}/tagging"} )
    session[:cat] = nil                 # Clear current category
    classify_build_screen
    @tabs = [ ["classifying", nil], ["classifying","#{session[:customer_name]} Tags"], ["tagging", "MyTags"] ]
    @in_a_form = true
    render :action=>"show"
  end

  # New classification category chosen on the classify screen
  def classify_new_cat
    session[:cat] = Classification.find_by_name(params["classification"]["name"])
    classify_build_entries_pulldown

    render :update do |page|
      page.replace("value_div", :partial=>"layouts/classify_value")
    end
  end

  # Handle tag edit field changes
  def tag_edit_form_field_changed
    id = params[:id]
    return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}","replace_cell__explorer")

    if params[:tag_cat]
      @edit[:cat] = Classification.find_by_name(params[:tag_cat])
      tag_edit_build_entries_pulldown
    elsif params[:tag_add]
      @edit[:new][:assignments].push(params[:tag_add].to_i)
      @assignments ||= Classification.find(@edit.fetch_path(:new, :assignments))
      @assignments.each_with_index do |a, a_idx|
        if a.parent.name == @edit[:cat].name &&     # If same category
            a.parent.single_value &&                #    single value category
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
      changed = (@edit[:new] != @edit[:current])
      if changed != session[:changed]
        session[:changed] = changed
        page << javascript_for_miq_button_visibility(changed)
      end
      page.replace("cat_tags_div", :partial=>"layouts/tag_edit_cat_tags")
      page.replace("assignments_div", :partial=>"layouts/tag_edit_assignments") unless params[:tag_cat]
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
      page.replace("value_div", :partial=>"layouts/classify_value")
      page.replace("table_div", :partial=>"layouts/classify_table")
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
      page.replace("value_div", :partial=>"layouts/classify_value")
      page.replace("table_div", :partial=>"layouts/classify_table")
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
    recs = Array.new
    if !session[:checked_items].nil? && @lastaction == "set_checked_items"
      recs = session[:checked_items]
    else
      recs = find_checked_items
    end
    if recs.blank?
      recs = [params[:id]]
    end
    if recs.length < 1
      add_flash(_("One or more %{model} must be selected to %{task}") % {:model=>Dictionary::gettext(db.to_s, :type=>:model, :notfound=>:titleize).pluralize, :task=>"Smart Tagging"}, :error)
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
    if params[:button] == "reset"
      @tagging = session[:tag_db].to_s
      id = params[:id] if params[:id]
      return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}")
      @object_ids = @edit[:object_ids]
    else
      #@object_ids[0] = params[:id] if @object_ids.blank? && params[:id]
      @tagging = session[:tag_db].to_s
    end
    tagging_tags_set_form_vars
    @display   = nil
    @in_a_form = true
    session[:changed] = false
    add_flash(_("All changes have been reset"), :warning) if params[:button] == "reset"
    if @explorer && ["service","vm_cloud","vm_infra","vm_or_template"].include?(request.parameters[:controller])
      @refresh_partial = "layouts/tagging"
      replace_right_cell(@sb[:action]) if params[:button]
    else
      render "shared/views/tagging_edit"
    end
  end

  # Set form vars for tag editor
  def tagging_tags_set_form_vars
    @edit = Hash.new
    @edit[:new] = Hash.new
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
    add_flash(_("%s was cancelled by the user") % "Tag Edit")
    session[:flash_msgs] = @flash_array.dup                   # Put msg in session for next transaction to display
    session[:tag_items] = nil                                 # reset tag_items in session
    if @explorer && ["vm_infra","vm_cloud","service","vm_or_template"].include?(request.parameters[:controller])
      @edit = nil # clean out the saved info
      @sb[:action] = nil
      replace_right_cell
    else
      @edit = nil # clean out the saved info
      render :update do |page|
        page.redirect_to(@breadcrumbs[-2][:url])                # Go to previous breadcrumb
      end
    end
  end

  def tagging_edit_tags_save
    id = params[:id]
    return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}")

    tagging_save_tags

    session[:flash_msgs] = @flash_array.dup                   # Put msg in session for next transaction to display
    if @explorer && ["service","vm_cloud","vm_infra","vm_or_template"].include?(request.parameters[:controller])
      @edit = nil # clean out the saved info
      @sb[:action] = nil
      replace_right_cell
    else
      @edit = nil
      render :update do |page|
        page.redirect_to(@breadcrumbs[-2][:url])                # Go to previous breadcrumb
      end
    end
  end

  def tagging_edit_tags_save_and_replace_right_cell
    id = params[:id]
    return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}","replace_cell__explorer")

    tagging_save_tags

    get_node_info(x_node)
    @edit = nil
    replace_right_cell(@nodetype)
  end

  # Add/remove tags in a single transaction
  def tagging_save_tags
    Classification.bulk_reassignment({:model=>@edit[:tagging],
                                      :object_ids=>@edit[:object_ids],
                                      :add_ids=>@edit[:new][:assignments] - @edit[:current][:assignments],
                                      :delete_ids=>@edit[:current][:assignments] - @edit[:new][:assignments]
                                    })
  rescue StandardError => bang
    add_flash(_("Error during '%s': ") % "Save Tags" << bang.message, :error) # Push msg and error flag
  else
    add_flash(_("Tag edits were successfully saved"))
  end
  private :tagging_save_tags

  # Build the tagging assignment screen
  def tagging_build_screen
    @tagitems = session[:tag_db].find(session[:tag_items]).sort{|a,b| a.name <=> b.name}  # Get the db records that are being tagged
    @view = get_db_view(session[:tag_db])       # Instantiate the MIQ Report view object
    @view.table = MiqFilter.records2table(@tagitems, :only=>@view.cols + ['id'])

    session[:mytags] = @tagitems[0].tagged_with(:cat=>session[:userid])   # Start with the first items tags
    @tagitems.each do |item|
      itemassign = item.tagged_with(:cat=>session[:userid])               # Get each items tags
      session[:mytags].delete_if {|t| !itemassign.include?(t) }           # Remove any tags that are not in the new items tags
      break if session[:mytags].length == 0                               # Stop looking if no tags are left
    end
    tagging_build_tags_pulldown
    build_targets_hash(@tagitems)
  end

  # Build the pulldown containing the tags
  def tagging_build_tags_pulldown
    @mytags = Tag.all_tags(:cat=>session[:userid]).sort     # Get all of the users tags
    unless session[:mytags].blank?
      session[:mytags].each do |t|                                    # Look thru the common tags
        @mytags.delete(t.name.split("/")[-1])                     # Remove any tags from the pulldown that are in the common tags
      end
    end
  end

  # Build the classification assignment screen
  def classify_build_screen
    cats = Classification.categories.collect {|c| c unless !c.show}.compact.sort{|a,b| a.name <=> b.name} # Get the categories, sort by name
    @categories = Hash.new    # Classifications array for first chooser
    cats.delete_if{ |c| c.read_only? || c.entries.length == 0}  # Remove categories that are read only or have no entries
    cats.each do |c|
        if c.single_value?
          @categories[c.description + " *"] = c.name
        else
          @categories[c.description] = c.name
        end
    end
    cats.each do | cat_key |
      if session[:assigned_filters].include?(cat_key.name.downcase)
        cats.delete(cat_key)
      end
    end
    session[:cat] ||= cats.first                                    # Set to first category, if not already set

    @tagitems = session[:tag_db].find(session[:tag_items]).sort{|a,b| a.name <=> b.name}  # Get the db records that are being tagged

    @view = get_db_view(session[:tag_db])       # Instantiate the MIQ Report view object
    @view.table = MiqFilter.records2table(@tagitems, :only=>@view.cols + ['id'])

    session[:assignments] = Classification.find_assigned_entries(@tagitems[0])    # Start with the first items assignments
    @tagitems.each do |item|
      itemassign = Classification.find_assigned_entries(item)             # Get each items assignments
      session[:assignments].delete_if { |a| !itemassign.include?(a) } # Remove any assignments that are not in the new items assignments
      break if session[:assignments].length == 0                          # Stop looking if no assignments are left
    end
    if session[:assignments].length > 0                                             # if any assignments left
      session[:assignments].delete_if { |a| a.parent.read_only?}    # remove the ones from read only categories
    end
    classify_build_entries_pulldown
    build_targets_hash(@tagitems)
  end

  # Build the second pulldown containing the entries for the selected category
  def classify_build_entries_pulldown
    @entries = Hash.new                   # Create new entries hash (2nd pulldown)
    session[:cat].entries.each do |e|     # Get all of the entries for the current category
      @entries[e.description] = e.id        # Add it to the hash
    end

    session[:assignments].each do |a|                           # Look thru the assignments
      if a.parent.description == session[:cat].description      # If they match the category
        @entries.delete(a.description)                          # Remove them from the selection list
      end
    end

    if @entries.length == 0                             # No entries left to choose from
      @entries["<All values are assigned>"] = "select"
    else
      @entries["<Select a value to assign>"] = "select"
    end
  end

  # Build the @edit elements for the tag edit screen
  def tag_edit_build_screen
    cats = Classification.categories.collect {|c| c unless !c.show}.compact.sort{|a,b| a.name <=> b.name} # Get the categories, sort by name
    @categories = Hash.new    # Classifications array for first chooser
    cats.delete_if{ |c| c.read_only? || c.entries.length == 0}  # Remove categories that are read only or have no entries
    cats.each do |c|
        if c.single_value?
          @categories[c.description + " *"] = c.name
        else
          @categories[c.description] = c.name
        end
    end

    if ["User", "MiqGroup"].include?(@tagging)
      session[:assigned_filters] = Array.new  # No view filters used for user/groups, set as empty for later methods
    else
      cats.each do | cat_key |  # not needed for user/group tags since they are not filtered for viewing
        if session[:assigned_filters].include?(cat_key.name.downcase)
          cats.delete(cat_key)
        end
      end
    end

    @edit[:cat] ||= cats.first                                    # Set to first category, if not already set

    @tagitems = @tagging.constantize.find(@object_ids).sort_by { |t| t.name.downcase } unless @object_ids.blank?

    @view = get_db_view(@tagging)               # Instantiate the MIQ Report view object
    @view.table = MiqFilter.records2table(@tagitems, :only=>@view.cols + ['id'])

    # Start with the first items assignments
    @edit[:new][:assignments] =
      Classification.find_assigned_entries(@tagitems[0]).collect{|e| e.id unless e.parent.read_only?}
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
    @entries = Hash.new                   # Create new entries hash (2nd pulldown)
    @edit[:cat].entries.each do |e|       # Get all of the entries for the current category
      @entries[e.description] = e.id      # Add it to the hash
    end

    assignments = Classification.find(@edit.fetch_path(:new, :assignments))
    assignments.each do |a|                               # Look thru the assignments
      if a.parent.description == @edit[:cat].description  # If they match the category
        @entries.delete(a.description)                    # Remove them from the selection list
      end
    end

    if @entries.length == 0                             # No entries left to choose from
      @entries["<All values are assigned>"] = "select"
    else
      @entries["<Select a value to assign>"] = "select"
    end
  end

  # Tag selected db records
  def tag(db=nil)
    assert_privileges(params[:pressed])
    @tagging = session[:tag_db] = db        # Remember the DB
    get_tag_items
    drop_breadcrumb( {:name=>"Tag Assignment", :url=>"/#{session[:controller]}/tagging_edit"} )
    render :update do |page|
      area = request.parameters["controller"]
      if role_allows(:feature=>"#{area}_tag")
        if false    #commenting older code that had old way of tagging along with MyTags tab
          page.redirect_to :action => 'classifying'             # redirect to build the tagging screen
        else
          page.redirect_to :action => 'tagging_edit', :id=>params[:id], :db=>db, :escape=>false             # redirect to build the tagging screen
        end
      else
        page.redirect_to :action => 'tagging'             # redirect to build the tagging screen
      end
    end
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

end
