module ApplicationController::PolicySupport
  extend ActiveSupport::Concern

  # Assign/unassign policies to/from a set of objects
  def protect
    @display   = nil
    @edit      = session[:edit]
    profile_id = params[:id].to_i

    if params[:check]                            # Item was checked/unchecked
      @in_a_form = true
      if params[:check] == "0"
        @edit[:new].delete(profile_id)        # Unchecked, remove from new hash
      else
        @edit[:new][profile_id] = session[:pol_items].length # Added, set to all checked
      end
      changed = (@edit[:new] != @edit[:current])
      render :update do |page|
        page << javascript_prologue
        if @edit[:new][profile_id] == @edit[:current][profile_id]
          page << "miqDynatreeNodeAddClass('#{j_str(session[:tree_name])}', 'policy_profile_#{profile_id}','dynatree-title')"
        else
          page << "miqDynatreeNodeAddClass('#{j_str(session[:tree_name])}', 'policy_profile_#{profile_id}', 'cfme-blue-bold-node')"
        end
        if changed != session[:changed]
          session[:changed] = changed
          page << javascript_for_miq_button_visibility(changed)
        end
      end

    elsif params[:button]                           # Button was pressed
      session[:changed] = false
      if params[:button] == "cancel"
        add_flash(_("Edit policy assignments was cancelled by the user"))
        @sb[:action] = nil
      elsif params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
        @explorer = true if @edit && @edit[:explorer]       # resetting @explorer from @edit incase reset button was pressed with explorer
        protect_build_screen                                #    build the protect screen
        if @edit[:explorer]
          @sb[:action] = "protect"
          @in_a_form = true
          replace_right_cell
        else
          render "shared/views/protect"
        end
        return
      elsif params[:button] == "save"
        ppids = @edit[:new].keys + @edit[:current].keys # Get union of policy profile ids
        ppids.uniq.each do |ppid|
          unless @edit[:new][ppid] == @edit[:current][ppid] # Only process changes
            pp = MiqPolicySet.find(ppid)                    # Get the pol prof record
            if @edit[:new][ppid] == 0                   # Remove if new count is zero
              pp.remove_from(session[:pol_items], session[:pol_db])
              AuditEvent.success(protect_audit(pp, "remove_from", session[:pol_db], session[:pol_items]))
            else                                        # else add
              pp.add_to(session[:pol_items], session[:pol_db])
              AuditEvent.success(protect_audit(pp, "add_to", session[:pol_db], session[:pol_items]))
            end
          end
        end
        add_flash(_("Policy assignments successfully changed"))
        @sb[:action] = nil
      end
      session[:flash_msgs] = @flash_array
      if @edit[:explorer]
        replace_right_cell
      else
        @edit = nil                                       # Clear out the session :edit hash
        redirect_to(previous_breadcrumb_url)
      end
    else                                                  # First time in,
      protect_build_screen                                #    build the protect screen
      unless @edit[:explorer]
        render "shared/views/protect"
      end
    end
  end

  # Perform policy simulation for a set of objects
  def policy_sim
    if request.xml_http_request?  # Ajax request means in explorer
      @explorer = true
      @edit ||= {}
      @edit[:explorer] = true       # since there is no @edit, create @edit and save explorer to use while building url for vms in policy sim grid
      session[:edit] = @edit
    end
    @lastaction = "policy_sim"
    drop_breadcrumb(:name => _("Policy Simulation"),
                    :url  => "/#{request.parameters["controller"]}/policy_sim?continue=true")
    session[:policies] = {} unless params[:continue]  # Clear current policies, unless continuing previous simulation
    policy_sim_build_screen
    @tabs = [["polsim", nil], ["polsim", "Policy Simulation"]]
    if @explorer
      @record = @tagitems.first
      @in_a_form = true
      if params[:action] == "policy_sim"
        @refresh_partial = "layouts/policy_sim"
        replace_right_cell
      end
    end
  end

  # Add selected policy to the simulation
  def policy_sim_add
    @edit = session[:edit]
    # Profile was selected
    if params[:profile_id] != "<select>"
      prof = MiqPolicySet.find(params[:profile_id])               # Go thru all the profiles
      session[:policies][prof.id] = prof.description            # Add it to the list
    end
    policy_sim_build_screen
    render :update do |page|
      page << javascript_prologue
      page.replace_html("main_div", :partial => "layouts/policy_sim")
    end
  end

  # Remove selected policy from the simulation
  def policy_sim_remove
    @edit = session[:edit]
    session[:policies].delete(params[:del_pol].to_i)
    policy_sim_build_screen
    render :update do |page|
      page << javascript_prologue
      page.replace_html("main_div", :partial => "layouts/policy_sim")
    end
  end

  def profile_build
    @catinfo ||= {}
    session[:assignments] = session[:protect_item].get_policies
    session[:assignments].each do |policy|
      cat = policy["description"]
      @catinfo[cat] = true unless @catinfo.key?(cat)
    end
  end

  def profile_toggle
    if params[:pressed] == "tag_cat_toggle"
      policy_escaped = j(params[:policy])
      cat            = params[:cat]
      render :update do |page|
        page << javascript_prologue
        if @catinfo[cat]
          @catinfo[cat] = false
          page << javascript_show("cat_#{policy_escaped}_div")
          page << "$('#cat_#{policy_escaped}_icon').prop('src', #{ActionController::Base.helpers.image_path('tree/compress.png')});"
        else
          @catinfo[cat] = true # Set squashed = true
          page << javascript_hide("cat_#{policy_escaped}_div")
          page << "$('#cat_#{policy_escaped}_icon').prop('src', #{ActionController::Base.helpers.image_path('tree/expand.png')});"
        end
      end
    else
      add_flash(_("Button not yet implemented"), :error)
      render :update do |page|
        page << javascript_prologue
        page.replace(:flash_msg_div, :partial => "layouts/flash_msg")
      end
    end
  end

  private ############################

  # Assign policies to selected records of db
  def assign_policies(db = nil)
    assert_privileges(params[:pressed])
    session[:pol_db] = db                               # Remember the DB
    recs = []
    recs = find_checked_items
    if recs.blank?
      recs = [params[:id]]
    end
    if recs.length < 1
      add_flash(_("One or more %{model} must be selected to Policy assignment") % {
        :model => Dictionary.gettext(db.to_s, :type => :model, :notfound => :titleize, :plural => true)}, :error)
      @refresh_div = "flash_msg_div"
      @refresh_partial = "layouts/flash_msg"
      return
    else
      session[:pol_items] = recs    # Set the array of tag items
    end
    @in_a_form = true
    if @explorer
      protect
      @refresh_partial = "layouts/protect"
    else
      javascript_redirect :action => 'protect' # redirect to build policy screen
    end
  end
  %w(image instance vm miq_template container_image ems_container).each do |old_name|
    alias_method "#{old_name}_protect".to_sym, :assign_policies
  end

  # Build the policy assignment screen
  def protect_build_screen
    drop_breadcrumb(
      :name => _("'%{model}' Policy Assignment") % {:model => Dictionary.gettext(session[:pol_db].to_s,
                                                                                 :type     => :model,
                                                                                 :notfound => :titleize)},
      :url  => "/#{request.parameters["controller"]}/protecting"
    )
    # session[:pol_db] = session[:pol_db] == Vm ? VmOrTemplate : session[:pol_db]
    @politems = session[:pol_db].find(session[:pol_items]).sort_by(&:name)  # Get the db records
    @view = get_db_view(session[:pol_db])             # Instantiate the MIQ Report view object
    @view.table = MiqFilter.records2table(@politems, @view.cols + ['id'])

    @edit = {}
    @edit[:explorer] = true if @explorer
    @edit[:new] = Hash.new(0)                         # Hash to hold new policy assignment counts
    @politems.each do |i|
      i.get_policies.each do |p|
        @edit[:new][p.id] += 1                        # Add up the counts for each policy
      end
    end
    @edit[:current] = @edit[:new].dup                 # Save the existing counts
    session[:changed] = false
    @in_a_form = true
    protect_build_tree                                # Build the protect tree
    build_targets_hash(@politems)
  end

  # Create policy assignment audit record
  def protect_audit(pp, mode, db, recs)
    msg = _("[%{name}] Policy Profile %{mode} (db:[%{db}]") % {:name => pp.name, :mode => mode, :db => db}
    msg += ", ids:[#{recs.sort_by(&:to_i).join(',')}])"
    event = "policyset_" + mode
    audit = {:event => event, :target_id => pp.id, :target_class => pp.class.base_class.name, :userid => session[:userid], :message => msg}
  end

  def assigned_filters
    assigned_filters = []
    # adding assigned filters for a user into hash to display categories bold and gray out subcategory if checked
    @get_filters = [current_user.get_managed_filters].flatten
    h = Hash[*@get_filters.collect { |v| [@get_filters.index(v), v] }.flatten]
    @get_filters = h.invert
    h.invert.each do |val, _key|
      categories = Classification.categories.collect { |c| c if c.show }.compact
      categories.each do |category|
        entries = {}
        category.entries.each do |entry|
          entries[entry.description] = entry.tag.name # Get the fully qual tag name
          if val == entry.tag.name
            @get_filters[entry.tag.name] = "cats_#{category.description}:#{entry.description}"
            assigned_filters.push(category.description.downcase)
            session[category.description.downcase] = [] if session[category.description.downcase].nil?
            session[category.description.downcase].push(entry.description) unless session[category.description.downcase].include?(entry.description)
          end
        end
      end
    end
    assigned_filters
  end

  # Build the policy simulation screen
  def policy_sim_build_screen
    @tagitems = session[:tag_db].find(session[:tag_items]).sort_by(&:name)  # Get the db records that are being tagged
    @catinfo = {}
    @lastaction = "policy_sim"
    @pol_view = get_db_view(session[:tag_db])       # Instantiate the MIQ Report view object
    @pol_view.table = MiqFilter.records2table(@tagitems, @pol_view.cols + ['id'])

    # Build the profiles selection list
    @all_profs = {}
    MiqPolicySet.all.each do |ps|
      unless session[:policies].key?(ps.id)
        @all_profs[ps.id] = ps.description
      end
    end
    if @all_profs.length > 0
      @all_profs["<select>"] = ""
    else
      @all_profs["<select>"] = _("No Policy Profiles are available")
    end
    build_targets_hash(@tagitems)
  end
end
