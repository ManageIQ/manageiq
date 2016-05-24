class TreeBuilderDefaultFilters < TreeBuilder
  has_kids_for Hash, [:x_get_tree_hash_kids]

  NAV_TAB_PATH =  {
      :container        => %w(Containers Containers),
      :containergroup   => %w(Containers Containers\ Groups),
      :containerservice => %w(Containers Services),
      :host             => %w(Infrastructure Hosts),
      :miqtemplate      => %w(Services Workloads Templates\ &\ Images),
      :storage          => %w(Infrastructure Datastores),
      :vm               => %w(Services Workloads VMs\ &\ Instances),
      :"manageiq::providers::cloudmanager::template" => %w(Cloud Instances Images),
      :"manageiq::providers::inframanager::template" => %w(Infrastructure Virtual\ Machines Templates),
      :"manageiq::providers::cloudmanager::vm"       => %w(Cloud Instances Instances),
      :"manageiq::providers::inframanager::vm"       => %w(Infrastructure Virtual\ Machines VMs)
  }

  def prepare_data(data)
    nodes = {}
    data.sort_by { |s| [NAV_TAB_PATH[s.db.downcase.to_sym], s.description.downcase] }.collect do |search|
      folder_nodes = NAV_TAB_PATH[search[:db].downcase.to_sym]
      if nodes.fetch_path(folder_nodes)
        path = nodes.fetch_path(folder_nodes)
        path.push(search)
      else
        path = nodes.store_path(folder_nodes, [])
        path.push(search)
       # nodes.store_path(folder_nodes[0], "id", search.id)
      end
    end
    nodes
  end

  def initialize(name, type, sandbox, build = true, data = nil)
    @data = prepare_data(data)
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids                    => false,
     :add_root                    => false,
     :lazy                        => false,
     :open_close_all_on_dbl_click => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix => 'df_',
                  :open_close_all_on_dbl_click => true,
                  :onclick => false,:check_url => "/configuration/filters_field_changed/",
                  :onselect                    => "miqOnCheckSections",
                  :checkboxes                  => true,)
  end

  def root_options
    []
  end

  def x_get_tree_roots(count_only = false, _options)
    roots = []
    folders = @data.keys
    folders.each do |folder|
      node = {:id    => "#{folder}",
              :text  => folder,
              :image => "folder",
              :tip   => folder,
              :style_class  => "cfme-no-cursor-node",
              :hideCheckbox => true,}
      roots.push(node)
    end
    count_only_or_objects(count_only, roots)
  end

  def x_get_tree_hash_kids(parent, count_only)
    nodes = []
    unless parent[:id].kind_of?(Fixnum)
      path = parent[:id].split('_')
      kids = @data.fetch_path(path)

      if kids.kind_of?(Hash)
        folders = kids.keys
        folders.each do |folder|
          nodes.push({:id    => "#{parent[:id]}_#{folder}",
                      :text  => folder,
                      :image => "folder",
                      :tip   => folder,
                      :style_class  => "cfme-no-cursor-node",
                      :hideCheckbox => true,})
        end
      else
        kids.each do |kid|
          nodes.push({:id => kid[:id],
                      :text => kid[:description],
                      :image => 'filter',
                      :tip => kid[:description],
                      :select => kid[:search_key] != "_hidden_"
                     })
        end
      end
    end
    count_only_or_objects(count_only, nodes)
  end

end