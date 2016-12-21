class TreeBuilderOpsRbacMenu < TreeBuilder
  include CompressedIds

  has_kids_for Hash, [:x_get_tree_hash_kids]

  attr_reader :role, :features, :editable

  def initialize(name, type, sandbox, build, role:, editable: false)
    @role     = role
    @editable = editable
    @features = @role.miq_product_features.order(:identifier).pluck(:identifier)

    super(name, type, sandbox, build)
  end

  private

  def menu_tree
    recurse_menu_items(filtered_menus, root_select)
  end

  def filtered_menus
    menus = []

    Menu::Manager.each do |section|
      next if section.id == :cons && !Settings.product.consumption
      next if section.name.nil?
      next unless Vmdb::PermissionStores.instance.can?(section.id)

      menus.push(section)
    end

    menus
  end

  def recurse_menu_items(items, checked = false)
    items.map do |item|
      case item
      when Menu::Section
        menu_section_to_node(item)
      when Menu::Item
        if item.feature.nil? || !MiqProductFeature.feature_exists?(item.feature)
          next
        end
        menu_item_to_node(item, checked)
      when String
        feature_name_to_node(item, checked)
      else
        item
      end
    end
  end

  def menu_section_to_node(section)
    node = default_node.merge!(
      :id      => "#{node_id}___tab_#{section.id}",
      :text    => _(section.name),
      :tooltip => _("%{title} Main Tab") % {:title => section.name},
      :data    => {}
    )

    node[:data][:kids] = recurse_menu_items(section.items).compact
    select_if_kids_selected(node, node[:data][:kids])

    node
  end

  def menu_item_to_node(item, checked = false)
    details = MiqProductFeature.feature_details(item.feature)

    node = default_node.merge!(
      :id      => "#{node_id}__#{item.feature}",
      :text    => _(details[:name]),
      :tooltip => _(details[:description]) || _(details[:name]),
      :select  => checked,
      :data    => {}
    )

    node[:select] ||= features.include?(item.feature)

    kids = MiqProductFeature.feature_children(item.feature)
    node[:data][:kids] = recurse_menu_items(kids, node[:select])

    select_if_kids_selected(node, node[:data][:kids])

    node
  end

  def feature_name_to_node(feature, checked = false)
    details = MiqProductFeature.feature_details(feature)
    return if details[:hidden]

    checked ||= features.include?(remove_accords_suffix(feature))

    node = default_node.merge!(
      :id      => "#{node_id}__#{feature}",
      :image   => "feature_#{details[:feature_type]}",
      :text    => _(details[:name]),
      :tooltip => _(details[:description]) || _(details[:name]),
      :select  => checked,
      :data    => {}
    )

    children = MiqProductFeature.feature_children(feature).map do |child|
      name = remove_accords_suffix(child)
      name if MiqProductFeature.feature_exists?(name)
    end

    node[:data][:kids] = recurse_menu_items(children, checked)

    select_if_kids_selected(node, node[:data][:kids])

    node
  end

  def select_if_kids_selected(node, kids)
    return if kids.none?

    if all_checked?(kids)
      node[:select] = true
      return
    end

    if any_checked?(kids)
      node[:select] = 'undefined'
    end
  end

  def set_locals_for_render
    locals = {
      :checkboxes   => true,
      :three_checks => true,
      :check_url    => "/ops/rbac_role_field_changed/"
    }

    if editable
      locals[:oncheck] = "miqOnCheckHandler"
    end

    super.merge!(locals)
  end

  def x_get_tree_roots(count_only = false, _options)
    top_nodes = menu_tree
    top_nodes << all_vm_node

    select_if_kids_selected(root_node, top_nodes.first[:data][:kids])

    count_only_or_objects(count_only, top_nodes)
  end

  def x_get_tree_hash_kids(parent, count_only = false)
    count_only_or_objects(count_only, parent[:data][:kids])
  end

  def tree_init_options(_tree_name)
    { :lazy => false, :add_root => true }
  end

  def root_options
    [
      root_title,
      root_tooltip,
      "feature_node",
      @root_node
    ]
  end

  def root_node
    @root_node ||= {
      :key         => root_key,
      :expand      => true,
      :cfmeNoClick => true,
      :select      => root_select,
      :checkable   => editable
    }
  end

  def root_tooltip
    _(root[:description]) || _(root[:name])
  end

  def root_title
    _(root[:name])
  end

  def root_key
    "#{node_id}__#{root_feature}"
  end

  def root_select
    features.include?(root_feature)
  end

  def node_id
    role.id ? to_cid(role.id) : "new"
  end

  def remove_accords_suffix(name)
    name.sub(/_accords$/, '')
  end

  def root_feature
    @root_feature ||= MiqProductFeature.feature_root
  end

  def root
    @root ||= MiqProductFeature.feature_details(root_feature)
  end

  def all_vm_node
    @all_vm_node ||= begin
      text = _("Access Rules for all Virtual Machines")
      feat_kids = MiqProductFeature.feature_children("all_vm_rules")
      checked = root_select || features.include?("all_vm_rules")

      default_node.merge!(
        :id      => "#{node_id}___tab_all_vm_rules",
        :text    => text,
        :tooltip => text,
        :select  => checked,
        :data    => {
          :kids => recurse_menu_items(feat_kids, checked)
        }
      )
    end
  end

  def default_node
    {
      :id          => node_id,
      :image       => "feature_node",
      :text        => "",
      :cfmeNoClick => true,
      :select      => false,
      :checkable   => editable
    }
  end

  def all_checked?(kids)
    return false if kids.empty? # empty list is considered not checked
    kids.length == kids.collect { |k| k if k[:select] }.compact.length
  end

  def any_checked?(kids)
    return false if kids.empty?
    kids.any? { |k| k[:select] }
  end
end
