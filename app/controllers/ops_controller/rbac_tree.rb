class OpsController
  class RbacTree
    include CompressedIds

    def self.build(role, role_features)
      new(role, role_features).build
    end

    def initialize(role, role_features)
      @role = role
      @role_features = role_features
    end

    def build
      root_feature = MiqProductFeature.feature_root
      root = MiqProductFeature.feature_details(root_feature)
      root_node = {
        :key      => "#{@role.id ? to_cid(@role.id) : "new"}__#{root_feature}",
        :icon     => ActionController::Base.helpers.image_path('100/feature_node.png'),
        :title    => root[:name],
        :tooltip  => root[:description] || root[:name],
        :addClass => "cfme-cursor-default",
        :expand   => true,
        :select   => @role_features.include?(root_feature)
      }

      top_nodes = []
      @all_vm_node = { # FIXME: handle the below special name!
        :key      => "#{@role.id ? to_cid(@role.id) : "new"}___tab_all_vm_rules",
        :icon     => ActionController::Base.helpers.image_path('100/feature_node.png'),
        :title    => t = _("Access Rules for all Virtual Machines"),
        :tooltip  => t,
        :children => [],
        :select   => root_node[:select]
      }
      rbac_features_tree_add_node("all_vm_rules", root_node[:key], @all_vm_node[:select])

      Menu::Manager.each_feature_title_with_subitems do |feature_title, subitems|
        t_kids = []
        t_node = {
          :key     => "#{@role.id ? to_cid(@role.id) : "new"}___tab_#{feature_title}",
          :icon    => ActionController::Base.helpers.image_path('100/feature_node.png'),
          :title   => feature_title,
          :tooltip => _("%{title} Main Tab") % {:title => feature_title}
        }

        subitems.each do |f| # Go thru the features of this tab
          f_tab = f.ends_with?("_accords") ? f.split("_accords").first : f  # Remove _accords suffix if present, to get tab feature name
          next unless MiqProductFeature.feature_exists?(f_tab)
          feature = rbac_features_tree_add_node(f_tab, t_node[:key], root_node[:select])
          t_kids.push(feature) unless feature.nil?
        end

        if root_node[:select]                 # Root node is checked
          t_node[:select] = true
        elsif !t_kids.empty?                  # If kids are present
          full_chk = (t_kids.collect { |k| k if k[:select] }.compact).length
          part_chk = (t_kids.collect { |k| k unless k[:select] }.compact).length
          if full_chk == t_kids.length
            t_node[:select] = true            # All kids are checked
          elsif full_chk > 0 || part_chk > 0
            t_node[:select] = false           # Some kids are checked or partially checked
          end
        end

        t_node[:children] = t_kids unless t_kids.empty?
        # only show storage node if product setting is set to show the nodes
        case feature_title.downcase
        when "storage" then top_nodes.push(t_node) if VMDB::Config.new("vmdb").config[:product][:storage]
        else            top_nodes.push(t_node)
        end
      end
      top_nodes << @all_vm_node
      root_node[:children] = top_nodes unless top_nodes.empty?
      root_node
    end

    def rbac_features_tree_add_node(feature, _pid, parent_checked = false)
      details = MiqProductFeature.feature_details(feature)

      unless details[:hidden]
        f_kids = [] # Array to hold node children
        f_node = {
          :key     => "#{@role.id ? to_cid(@role.id) : "new"}__#{feature}",
          :icon    => ActionController::Base.helpers.image_path("100/feature_#{details[:feature_type]}.png"),
          :title   => details[:name],
          :tooltip => details[:description] || details[:name]
        }
        f_node[:hideCheckbox] = true if details[:protected]

        # Go thru the features children
        MiqProductFeature.feature_children(feature).each do |f|
          feat = rbac_features_tree_add_node(f,
                                             f_node[:key],
                                             parent_checked || @role_features.include?(feature)) if f
          next unless feat

          # exceptional handling for named features
          if %w(image instance miq_template vm).index(f)
            @all_vm_node[:children].push(feat)
          else
            f_kids.push(feat)
          end
        end
        f_node[:children] = f_kids unless f_kids.empty? # Add in the node's children, if any

        if parent_checked || # Parent is checked
           @role_features.include?(feature)  # This feature is checked
          f_node[:select] = true
        elsif !f_kids.empty?                  # If kids are present
          full_chk = (f_kids.collect { |k| k if k[:select] }.compact).length
          part_chk = (f_kids.collect { |k| k unless k[:select] }.compact).length
          if full_chk == f_kids.length
            f_node[:select] = true            # All kids are checked
          elsif full_chk > 0 || part_chk > 0
            f_node[:select] = false # Some kids are checked
          end
        end
        f_node
      end
    end
  end
end
