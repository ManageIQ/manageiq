class TreeBuilderProtect < TreeBuilder
  has_kids_for Hash, [:x_get_tree_hash_kids]

  def initialize(name, type, sandbox, build = true, data)
    @data = data
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => false, :add_root => false, :lazy => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:checkboxes        => true,
                  :oncheck           => "miqOnCheckProtect",
                  :highlight_changes => true,
                  :check_url         => "/#{@data[:controller_name]}/protect/")
  end

  def root_options
    []
  end

  def x_get_tree_roots(count_only = false, _options)
    nodes = MiqPolicySet.all.sort_by { |profile| profile.description.downcase }.map do |profile|
      { :id          => "policy_profile_#{profile.id}",
        :text        => profile.description,
        :image       => "100/policy_profile#{profile.active? ? "" : "_inactive"}.png",
        :tip         => profile.description,
        :select      => @data[:new][profile.id] == @data[:pol_items].length,
        :children    => profile.members,
        :cfmeNoClick => true
      }
    end
    count_only_or_objects(count_only, nodes)
  end

  def x_get_tree_hash_kids(parent, count_only)
    nodes = parent[:children].map do |policy|
      text = "<b>#{ui_lookup(:model => policy.towhat)} #{policy.mode.capitalize}:</b> #{policy.description}"
      {:id           => "policy_#{policy.id}",
       :text         => text.html_safe,
       :image        => "100/miq_policy_#{policy.towhat.downcase}#{policy.active ? "" : "_inactive"}.png",
       :tip          => policy.description,
       :hideCheckbox => true,
       :children     => [],
       :cfmeNoClick  => true
      }
    end
    count_only_or_objects(count_only, nodes)
  end
end
