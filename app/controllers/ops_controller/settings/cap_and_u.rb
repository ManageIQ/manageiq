module OpsController::Settings::CapAndU
  extend ActiveSupport::Concern

  def cu_collection_update
    return unless load_edit("cu_edit__collection", "replace_cell__explorer")
    if params[:button] == "save"
      # C & U collection settings
      if @edit[:new][:all_clusters] != @edit[:current][:all_clusters]
        Metric::Targets.perf_capture_always = {
          :host_and_cluster => @edit[:new][:all_clusters]
        }
      end

      if @edit[:new][:all_storages] != @edit[:current][:all_storages]
        Metric::Targets.perf_capture_always = {
          :storage => @edit[:new][:all_storages]
        }
      end

      set_perf_collection_for_clusters if @edit[:new] != @edit[:current]

      unless @edit[:current][:non_cl_hosts].blank?   # if there are any hosts without clusters
        @edit[:current][:non_cl_hosts].each do |h_id|
          h = Host.find_by_id(h_id[:id])
          h.perf_capture_enabled = @edit[:new][:non_cluster_host_enabled][h.id.to_s] == true
        end
      end

      unless @edit[:new][:storages] == @edit[:current][:storages] # Check for storage changes
        @st_recs = Storage.all.inject({}) { |h, st| h[st.id] = st; h }
        @edit[:new][:storages].each_with_index do |s, si|
          if s[:capture] != @edit[:current][:storages][si][:capture]
            ds = @st_recs[s[:id]]
            ds.perf_capture_enabled = s[:capture] if ds
          end
        end
      end

      add_flash(_("Capacity and Utilization Collection settings saved"))
      get_node_info(x_node)
      replace_right_cell(@nodetype)
    elsif params[:button] == "reset"
      @changed = false
      add_flash(_("All changes have been reset"), :warning)
      get_node_info(x_node)
      replace_right_cell(@nodetype)
    end
  end

  def set_perf_collection_for_clusters
    cluster_ids = @edit[:new][:clusters].collect { |c| c[:id] }.uniq
    clusters = EmsCluster.where(:id => cluster_ids).includes(:hosts)

    clusters.each do |cl|
      enabled_hosts = @edit[:new][cl.name.to_sym].select { |h| h[:capture] }
      enabled_host_ids = enabled_hosts.collect { |h| h[:id] }.uniq
      cl.perf_capture_enabled_host_ids = enabled_host_ids
    end
  end

  def cu_collection_field_changed
    return unless load_edit("cu_edit__collection", "replace_cell__explorer")
    cu_collection_get_form_vars
    @changed = (@edit[:new] != @edit[:current]) # UI edit form, C&U collection form
    # C&U tab
    # need to create an array of items, if their or their children's capture has been changed then make the changed one blue.
    render :update do |page|
      page << javascript_prologue
      page.replace_html(@refresh_div, :partial => @refresh_partial) if @refresh_div
      page << "$('#clusters_div').#{params[:all_clusters] == 'true' ? "hide" : "show"}()" if params[:all_clusters]
      page << "$('#storages_div').#{params[:all_storages] == 'true' ? "hide" : "show"}()" if params[:all_storages]
      if params[:id] || params[:check_all]
        if params[:tree_name] == "datastore"
          # change nodes to blue if they were changed during current edit session
          @changed_id_list   = []
          # change ids back to black if change during current session is reverted back
          @unchanged_id_list = []
          @edit[:new][:storages].each_with_index do |s, i|
            datastore_id = "xx-#{s[:id]}"
            if @edit[:new][:storages][i][:capture] != @edit[:current][:storages][i][:capture]
              @changed_id_list.push(datastore_id)
            elsif datastore_id == params[:id] || params[:check_all]
              @unchanged_id_list.push(datastore_id)
            end
          end
          @changed_id_list.each do |item|
            page << "miqDynatreeNodeAddClass('#{j_str(params[:tree_name])}',
                                                  '#{j_str(item)}',
                                                  'cfme-blue-bold-node');"
          end
          @unchanged_id_list.each do |item|
            page << "miqDynatreeNodeAddClass('#{j_str(params[:tree_name])}',
                                                  '#{j_str(item)}',
                                                  'dynatree-title');"
          end
        else
          @changed_id_list   = []
          @unchanged_id_list = []
          @edit[:new][:clusters].each_with_index do |c, i|
            cname = c[:name]
            cluster_id = "xx-#{c[:id]}"
            if @edit[:new][:clusters][i][:capture] != @edit[:current][:clusters][i][:capture]
              @changed_id_list.push([cluster_id, @edit[:new][:clusters][i][:capture]])
            else
              @unchanged_id_list.push(cluster_id)
            end
            @edit[:new][cname.to_sym].each_with_index do |host, j|
              host_id = "#{cluster_id}_#{host[:id]}"
              if @edit[:new][cname.to_sym][j][:capture] != @edit[:current][cname.to_sym][j][:capture]
                @changed_id_list.push([host_id, @edit[:new][cname.to_sym][j][:capture]])
              elsif cluster_id == params[:id] || host_id == params[:id] || params[:check_all]
                @unchanged_id_list.push(host_id)
              end
            end
          end
          @changed_id_list.each do |item|
            page << "miqDynatreeNodeAddClass('#{j_str(params[:tree_name])}',
                                                  '#{j_str(item[0])}',
                                                  'cfme-blue-bold-node');"
            if params.key?('check')
              page << "miqDynatreeSelectNode('#{j_str(params[:tree_name])}', '#{j_str(item[0])}', '#{j_str(item[1])}')"
            end
          end
          @unchanged_id_list.each do |item|
            page << "miqDynatreeNodeAddClass('#{j_str(params[:tree_name])}',
                                                  '#{j_str(item)}',
                                                  'dynatree-title');"

          end
        end
      end
      page << javascript_for_miq_button_visibility(@changed)
    end
  end

  private

  def cu_build_edit_screen
    @edit = {}
    @edit[:new] = {}
    @edit[:current] = {}
    @edit[:key] = "cu_edit__collection"
    @edit[:current][:all_clusters] = Metric::Targets.perf_capture_always[:host_and_cluster]
    @edit[:current][:all_storages] = Metric::Targets.perf_capture_always[:storage]
    @edit[:current][:clusters] = []
    @cl_hash = EmsCluster.get_perf_collection_object_list
    @cl_hash.each_with_index do |h, j|
      cid, cl_hash = h
      c = cl_hash[:cl_rec]
      enabled = cl_hash[:ho_enabled]
      enabled_host_ids = enabled.collect(&:id)
      hosts = (cl_hash[:ho_enabled] + cl_hash[:ho_disabled]).sort_by { |ho| ho.name.downcase }
      cl_enabled = enabled_host_ids.length == hosts.length
      if cl_enabled && !enabled.empty?
        en_flg = true
      else
        en_flg = false
      end
      # cname = "#{c.ext_management_system.name} : " +
      #         (c.parent_datacenter != nil ? "#{c.parent_datacenter.name} : " : "") +
      #         "#{c.name}"
      cname = c.name
      @edit[:current][:clusters].push(:name    => cname,
                                      :id      => c.id,
                                      :capture => en_flg) # grab name, id, and capture setting
      @edit[:current][cname.to_sym] = []
      hosts.each do |h|
        host_capture = enabled_host_ids.include?(h.id.to_i)
        @edit[:current][cname.to_sym].push(:name    => h.name,
                                           :id      => h.id,
                                           :capture => host_capture)
      end
      flg = true
      count = 0
      @edit[:current][cname.to_sym].each do |h|
        unless h[:capture]
          count += 1          # checking if all hosts are unchecked then cluster capture will be false else unsure
          flg = (count == @edit[:current][cname.to_sym].length) ? false : "unsure"
        end
        @edit[:current][:clusters][j][:capture] = flg
      end
    end
    @edit[:current][:clusters].sort_by! { |c| c[:name] }
    @cluster_tree = TreeBuilderClusters.new(:cluster, :cluster_tree, @sb, true, @edit[:current][:clusters])
    @edit[:current][:storages] = []
    @st_recs = {}
    Storage.in_my_region.includes(:taggings, :tags, :hosts).select(:id, :name, :store_type, :location)
      .sort_by { |s| s.name.downcase }.each do |s|
      @st_recs[s.id] = s
      @edit[:current][:storages].push(:name       => s.name,
                                      :id         => s.id,
                                      :capture    => s.perf_capture_enabled?,
                                      :store_type => s.store_type,
                                      :location   => s.location) # fields we need
    end
    @datastore_tree  = TreeBuilderDatastores.new(:datastore, :datastore_tree, @sb, true, @edit[:current][:storages])
    @edit[:new] = copy_hash(@edit[:current])
    session[:edit] = @edit
  end

  def cu_collection_get_form_vars
    if params[:id]
      nodetype = params[:id].split('_')
      node_type = if params[:tree_name] == 'cluster'
                    nodetype.length >= 2 ? ["Host", nodetype[1]] : ["Cluster", nodetype[0].split('-')[1]]
                  else
                    ["Datastore", nodetype[0].split('-')[1]]
                  end
    end
    @edit[:new][:all_clusters] = params[:all_clusters] == 'true' if params[:all_clusters]
    @edit[:new][:all_storages] = params[:all_storages] == 'true' if params[:all_storages]
    if params[:tree_name] == "datastore"
      datastore_tree_settings(node_type)
    else
      cluster_tree_settings(node_type)
    end
  end

  def cluster_tree_settings(node_type)
    if params[:check_all]                         # to handle check/uncheck cluster all checkbox
      @edit[:new][:clusters].each do |c|                                  # Check each clustered host
        c[:capture] = params[:check_all] == "true" # if cluster checked/unchecked Set C&U flag for all hosts under it as well
        @edit[:new][c[:name].to_sym].each do |h|
          h[:capture] = params[:check_all] == "true" # Set C&U flag depending on if checkbox parm is present
        end
      end
    else
      @edit[:new][:clusters].each do |c|                                  # Check each cluster
        if node_type[0] == "Cluster" && node_type[1].to_s == c[:id].to_s
          c[:capture] = params[:check] == "true" # if cluster checked/unchecked Set C&U flag for all hosts under it as well
          @edit[:new][c[:name].to_sym].each do |h|
            h[:capture] = params[:check] == "true" # Set C&U flag depending on if checkbox parm is present
          end
        elsif node_type[0] == "Host"
          @edit[:new][c[:name].to_sym].each do |h|
            if node_type[1].to_i == h[:id].to_i
              h[:capture] = params[:check] == "true" # Set C&U flag depending on if checkbox parm is present
              c[:capture] = false if params[:check] == "0"
            end
          end
        end

        if node_type[0] == "Host"
          flg = true
          count = 0
          @edit[:new][c[:name].to_sym].each do |h|
            unless h[:capture]
              count += 1          # checking if all hosts are unchecked then cluster capture will be false else unsure
              flg = (count == @edit[:new][c[:name].to_sym].length) ? false : "unsure"
            end
            c[:capture] = flg
          end
        end
      end
      # if there are no clusters, handle non-clustered hosts here
      if @edit[:new][:clusters].blank?
        @edit[:new][:non_cluster_host_enabled].each do |_h|
          if nodetype[0] == "NonCluster_0"
            process_form_vars_for_non_clustered(node_type)
          end
        end
      end
    end
  end

  def datastore_tree_settings(node_type)
    if params[:check_all]          # to handle check/uncheck storage all checkbox
      @edit[:new][:storages].each do |s|                                        # Check each storage
        s[:capture] = params[:check_all] == "true" # Set C&U flag depending on if checkbox parm is present
      end
    else
      @edit[:new][:storages].find{ |x| x[:id].to_s == params[:id].split('-').last}[:capture] = params[:check] == "true"
    end
  end

  def process_form_vars_for_non_clustered(node_type)
    if node_type[1].to_i == 0     # dont add if non-clustered node was checked/unchecked
      if params[:check] == "1"
        @edit[:new][:non_cluster_host_enabled].each do |h|
          @edit[:new][:non_cluster_host_enabled][h[0]] = true
        end
      else
        @edit[:new][:non_cluster_host_enabled].each do |h|
          @edit[:new][:non_cluster_host_enabled][h[0]] = false
        end
      end
    else
      if params[:check] == "1"
        @edit[:new][:non_cluster_host_enabled][node_type[1].to_s] = true
      else
        @edit[:new][:non_cluster_host_enabled].each do |h|
          if h[0].to_s == node_type[1].to_s
            @edit[:new][:non_cluster_host_enabled][node_type[1].to_s] = false
          end
        end
      end
    end
  end
end
