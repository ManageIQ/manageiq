class OpsController
  class RbacTree
    include CompressedIds

    def self.build(role, role_features, editable)
      new(role, role_features, editable).build
    end

    attr_reader :role, :role_features, :editable

    def initialize(role, role_features, editable)
      @role = role
      @role_features = role_features
      @editable = editable

      @descendant_cache = {}
    end

    def build
      root_node[:children] = recurse_menu_objects(filtered_menus, root_select)

      select_if_kids_selected(root_node, root_node[:children])

      root_node[:children] << all_vm_node

      root_node
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

    def recurse_menu_objects(items, checked = false)
      items.map do |item|
        case item
        when Menu::Section
          build_section(item)
        when Menu::Item
          if item.feature.nil? || !MiqProductFeature.feature_exists?(item.feature)
            next
          end
          build_item(item, checked)
        when String
          build_feature(item, checked)
        else
          item
        end
      end
    end

    def build_section(section)
      node = default_node.merge(
        :key      => "#{node_id}___tab_#{section.id}",
        :title    => _(section.name),
        :tooltip  => _("%{title} Main Tab") % {:title => section.name},
        :children => {}
      )

      node[:children] = recurse_menu_objects(section.items).compact
      select_if_kids_selected(node, node[:children])

      node
    end

    def build_item(item, checked = false)
      details = MiqProductFeature.feature_details(item.feature)

      node = default_node.merge(
        :key      => "#{node_id}__#{item.feature}",
        :title    => _(details[:name]),
        :tooltip  => _(details[:description]) || _(details[:name]),
        :select   => checked,
        :children => {}
      )

      # selected by parent or self
      node[:select] ||= role_features.include?(item.feature)

      # selected by children (including hidden)
      node[:select] ||= select_by_child_states(feature_child_select_states(item.feature))

      # add visible children to tree
      kids = MiqProductFeature.feature_children(item.feature)
      node[:children] = recurse_menu_objects(kids, node[:select])

      node
    end

    def build_feature(feature, checked = false)
      details = MiqProductFeature.feature_details(feature)

      node = default_node.merge(
        :key      => "#{node_id}__#{feature}",
        :icon     => img("100/feature_#{details[:feature_type]}"),
        :title    => _(details[:name]),
        :tooltip  => _(details[:description]) || _(details[:name]),
        :children => {}
      )

      # Select if parent is true or role has feature
      # don't care if parent is 'undefined'
      if checked == true || role_features.include?(remove_accords_suffix(feature))
        node[:select] = true
      end

      # Select by children
      # Count hidden children but keep them out of the tree
      node[:select] ||= select_by_child_states(feature_child_select_states(feature))

      visible_children = MiqProductFeature.feature_children(feature).map do |child|
        name = remove_accords_suffix(child)
        name if MiqProductFeature.feature_exists?(name)
      end

      node[:children] = recurse_menu_objects(visible_children, node[:select])

      node unless details[:hidden]
    end

    def all_vm_node
      @all_vm_node ||= begin
        text = _("Access Rules for all Virtual Machines")
        feat_kids = MiqProductFeature.feature_children("all_vm_rules")
        checked = root_select || role_features.include?("all_vm_rules")

        node = default_node.merge(
          :key      => "#{node_id}___tab_all_vm_rules",
          :title    => text,
          :tooltip  => text,
          :select   => checked,
          :children => recurse_menu_objects(feat_kids, checked)
        )

        select_if_kids_selected(node, node[:children])

        node
      end
    end

    def feature_child_select_states(feature)
      all_children = feature_descendants(feature)
      all_children.map { |c| role_features.include?(c) }
    end

    def feature_descendants(feature)
      @descendant_cache[feature] ||= MiqProductFeature.find_by(:identifier => feature).descendants.pluck(:identifier)
    end

    def select_if_kids_selected(node, kids)
      # Do nothing if no kids
      return if kids.none?

      if all_checked?(kids)
        node[:select] = true
        return
      end

      if any_checked?(kids)
        node[:select] = 'undefined'
      end
    end

    def select_by_child_states(states)
      return false       if states.none?
      return true        if states.all? { |s| s == true } # True not just truthy
      return 'undefined' if states.any?

      false
    end

    def root_node
      @root_node ||= {
        :key         => root_key,
        :title       => root_title,
        :tooltip     => root_tooltip,
        :icon        => img("100/feature_node.png"),
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
      role_features.include?(root_feature)
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

    def default_node
      {
        :key         => node_id,
        :icon        => img("100/feature_node.png"),
        :title       => "",
        :cfmeNoClick => true,
        :select      => false,
        :checkable   => editable
      }
    end

    def all_checked?(kids)
      return false if kids.empty? # empty list is considered not checked
      kids.length == kids.collect { |k| k if k[:select] == true }.compact.length
    end

    def any_checked?(kids)
      return false if kids.empty?
      kids.any? { |k| k[:select] }
    end

    def img(name)
      ActionController::Base.helpers.image_path(name)
    end
  end
end
