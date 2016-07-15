class TreeBuilderAutomateSimulationResults < TreeBuilder
  has_kids_for Hash, [:x_get_tree_hash_kids]
  def initialize(name, type, sandbox, build = true, root = nil)
    @root = root
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {
      :full_ids => true,
      :add_root => false,
      :expand   => true,
      :lazy     => false
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix     => "aesimulation_",
                  :autoload      => false,
                  :cfme_no_click => true,
                  :onclick       => false)
  end

  def root_options
    []
  end

  def x_get_tree_roots(count_only = false, _options)
    objects = []
    idx = 1
    MiqXml.load(@root).root.each_element do |el|
      objects.push(get_root_elements(el, idx))
      idx += 1
    end
    objects
  end

  def get_root_elements(el, idx)
    if el.name == "MiqAeObject"
      title = "#{el.attributes["namespace"]} <b>/</b> #{el.attributes["class"]} <b>/</b> #{el.attributes["instance"]}"
      icon = "q"
    elsif el.name == "MiqAeAttribute"
      title = el.attributes["name"]
      icon = "attribute"
    elsif !el.text.blank?
      title = el.text
      icon = el.name.underscore
    else
      title = el.name
      icon = title.underscore.sub(/^miq_ae_service_/, '')
      el_attributes = el.attributes
    end
    e_kids = []
    el.each_element do |e|
      e_kids.push(e)
    end
    object = {:id => "e_#{idx}", :text => _(title).html_safe, :image => icon, :tip => _(title).html_safe, :elements => e_kids, :addClass => "cfme-no-cursor-node"}
    object[:attributes] = el_attributes if el_attributes
    object
  end

  def x_get_tree_hash_kids(parent, count_only)
    kids = []
    idx = 1
    if parent[:attributes]
      parent[:attributes].each_pair do |k, v|
        node = {}
        node[:id] = "a_#{idx}"
        idx += 1
        node[:text] = "#{k} <b>=</b> #{v}".html_safe
        node[:image] = "attribute"
        node[:addClass] = "cfme-no-cursor-node"
        kids.push(node)
      end
    end
    if parent[:elements]
      parent[:elements].each_with_index do |el, i|
        kids.push(get_root_elements(el, i))
      end
    end
    count_only_or_objects(count_only, kids)
  end
end
