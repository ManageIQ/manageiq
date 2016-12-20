class TreeBuilderDefaultFilters < TreeBuilder
  has_kids_for Hash, [:x_get_tree_hash_kids]

  NAV_TAB_PATH = {
    :container                                     => %w(Containers Containers),
    :containergroup                                => %w(Containers Containers\ Groups),
    :containerservice                              => %w(Containers Services),
    :host                                          => %w(Infrastructure Hosts),
    :miqtemplate                                   => %w(Services Workloads Templates\ &\ Images),
    :storage                                       => %w(Infrastructure Datastores),
    :vm                                            => %w(Services Workloads VMs\ &\ Instances),
    :"manageiq::providers::cloudmanager::template" => %w(Cloud Instances Images),
    :"manageiq::providers::inframanager::template" => %w(Infrastructure Virtual\ Machines Templates),
    :"manageiq::providers::cloudmanager::vm"       => %w(Cloud Instances Instances),
    :"manageiq::providers::inframanager::vm"       => %w(Infrastructure Virtual\ Machines VMs)
  }.freeze

  def prepare_data(data)
    data.sort_by { |s| [NAV_TAB_PATH[s.db.downcase.to_sym], s.description.downcase] }
        .each_with_object({}) do |search, nodes|
      folder_nodes = NAV_TAB_PATH[search[:db].downcase.to_sym]
      path = nodes.fetch_path(folder_nodes) ? nodes.fetch_path(folder_nodes) : nodes.store_path(folder_nodes, [])
      path.push(search)
    end
  end

  def initialize(name, type, sandbox, build = true, data = nil)
    @data = prepare_data(data)
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true,
     :add_root => false,
     :lazy     => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:check_url         => "/configuration/filters_field_changed/",
                  :onselect          => "miqOnCheckSections",
                  :checkboxes        => true,
                  :highlight_changes => true)
  end

  def root_options
    []
  end

  def x_get_tree_roots(count_only = false, _options)
    roots = @data.keys.map do |folder|
      {:id           => folder,
       :text         => folder,
       :image        => "100/folder.png",
       :tip          => folder,
       :cfmeNoClick  => true,
       :hideCheckbox => true}
    end
    count_only_or_objects(count_only, roots)
  end

  def x_get_tree_hash_kids(parent, count_only)
    unless parent[:id].kind_of?(Fixnum)
      path = parent[:id].split('_')
      kids = @data.fetch_path(path)
      nodes = if kids.kind_of?(Hash)
                folders = kids.keys
                folders.map do |folder|
                  {:id           => "#{parent[:id]}_#{folder}",
                   :text         => folder,
                   :image        => "100/folder.png",
                   :tip          => folder,
                   :cfmeNoClick  => true,
                   :hideCheckbox => true}
                end
              else
                kids.map do |kid|
                  {:id          => kid[:id],
                   :text        => kid[:description],
                   :image       => '100/filter.png',
                   :tip         => kid[:description],
                   :cfmeNoClick => true,
                   :select      => kid[:search_key] != "_hidden_"}
                end
              end
    end
    count_only_or_objects(count_only, nodes)
  end
end
