module MiqRequestMixin
  def self.get_option(key, value, from)
    # Return value - Support array and non-array types
    data = value.nil? ? from[key] : value
    data.kind_of?(Array) ? data.first : data
  end

  def get_option(key, value = nil)
    MiqRequestMixin.get_option(key, value, options)
  end

  def display_message(default_msg = nil)
    MiqRequestMixin.get_option(:user_message, nil, options) || default_msg
  end

  def user_message=(msg)
    msg = msg.truncate(255)
    options[:user_message] = msg
    update_attribute(:options, options)
    update(:message => msg) if msg.present?
  end

  def self.get_option_last(key, from)
    # Return value - Support array and non-array types
    data = from[key]
    data.kind_of?(Array) ? data.last : data
  end

  def get_option_last(key)
    MiqRequestMixin.get_option_last(key, options)
  end

  def get_user
    if @user || User.in_my_region.find_by(:userid => userid)
      @user ||= User.in_my_region.find_by(:userid => userid).tap do |u|
        u.current_group_by_description = options[:requester_group] if options[:requester_group]
      end
    else
      @user = User.super_admin
    end
  end
  alias_method :tenant_identity, :get_user

  def tags
    Array.wrap(tag_ids).each do |tag_id|
      tag = Classification.find(tag_id)
      yield(tag.name, tag.parent.name)  unless tag.nil?    # yield the tag's name and category
    end
  end

  def get_tag(category)
    get_tags[category.to_sym]
  end

  def get_tags
    vm_tags = {}
    tags do |tag, cat|
      cat = cat.to_sym
      if vm_tags.key?(cat)
        vm_tags[cat] = [vm_tags[cat]]   unless vm_tags[cat].kind_of?(Array)
        vm_tags[cat] << tag
      else
        vm_tags[cat] = tag
      end
    end
    vm_tags
  end

  def clear_tag(category = nil, tag_name = nil)
    if category.nil?
      self.tag_ids = nil
    else
      deletes = []
      Array.wrap(tag_ids).each do |tag_id|
        tag = Classification.find(tag_id)
        next if category.to_s.casecmp(tag.parent.name) != 0
        next if !tag_name.blank? && tag_name.to_s.casecmp(tag.name) != 0
        deletes << tag_id
      end
      unless deletes.blank?
        self.tag_ids -= deletes
        update_attribute(:options, options)
      end
    end
  end

  def add_tag(category, tag_name)
    cat = Classification.lookup_by_name(category.to_s)
    return if cat.nil?
    tag = cat.children.detect { |t| t.name.casecmp(tag_name.to_s) == 0 }
    return if tag.nil?
    self.tag_ids ||= []
    unless self.tag_ids.include?(tag.id)
      self.tag_ids << tag.id
      update_attribute(:options, options)
    end
  end

  def classifications
    Array.wrap(self.tag_ids).each do |tag_id|
      classification = Classification.find(tag_id)
      yield(classification)  unless classification.nil?    # yield the whole classification
    end
  end

  def get_classification(category)
    get_classifications[category.to_sym]
  end

  def get_classifications
    vm_classifications = {}
    classifications do |classification|
      cat   = classification.parent.name.to_sym
      tuple = {:name => classification.name, :description => classification.description}
      if vm_classifications.key?(cat)
        vm_classifications[cat] = [vm_classifications[cat]]   unless vm_classifications[cat].kind_of?(Array)
        vm_classifications[cat] << tuple
      else
        vm_classifications[cat] = tuple
      end
    end
    vm_classifications
  end

  def tag_ids(key = :tag_ids)
    options[key]
  end

  def tag_ids=(value, key = :tag_ids)
    options[key] = value
  end

  # Web-Service helper method
  def request_tags
    ws_tag_data = []
    ns = '/managed'
    classifications do |c|
      tag_name = c.to_tag
      next unless tag_name.starts_with?(ns)
      tag_path = tag_name.split('/')[2..-1].join('/')
      parts = tag_path.split('/')
      cat = Classification.lookup_by_name(parts.first)
      next if cat.show? == false
      cat_descript = cat.description
      tag_descript = Classification.lookup_by_name(tag_path).description
      ws_tag_data << {:category => parts.first, :category_display_name => cat_descript,
                      :tag_name => parts.last,  :tag_display_name => tag_descript,
                      :tag_path =>  File.join(ns, tag_path), :display_name => "#{cat_descript}: #{tag_descript}"}
    end
    ws_tag_data
  end

  def workflow(request_options = options, flags = {})
    if workflow_class
      current_workflow = workflow_class.new(request_options, get_user, flags)
      if block_given?
        begin
          yield(current_workflow)
        ensure
          current_workflow.password_helper
        end
      end
      current_workflow
    end
  end

  def request_dialog(action_name)
    st = service_template
    return {} if st.blank?
    ra = st.resource_actions.find_by(:action => action_name)
    values = options[:dialog]
    dialog = ResourceActionWorkflow.new(values, get_user, ra, {}).dialog
    DialogSerializer.new.serialize(Array[dialog]).first
  end

  def dialog_zone
    zone = options.fetch_path(:dialog, "dialog_zone")
    return nil if zone.blank?

    unless Zone.where(:name => zone).exists?
      _log.warn("unknown zone #{zone} specified in dialog, ignored.")
      return nil
    end

    zone
  end

  def mark_execution_servers
    options[:executed_on_servers] ||= []
    # remove duplicates and ensure that last element of array is the last server
    (options[:executed_on_servers] -= [MiqServer.my_server.id]) << MiqServer.my_server.id
    update(:options => options)
  end
end
