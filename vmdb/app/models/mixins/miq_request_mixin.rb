module MiqRequestMixin

  def self.get_option(key, value, from)
    # Return value - Support array and non-array types
    data = value.nil? ? from[key] : value
    data.kind_of?(Array) ? data.first : data
  end

  def get_option(key, value=nil)
    MiqRequestMixin.get_option(key, value, self.options)
  end

  def display_message(default_msg = nil)
    MiqRequestMixin.get_option(:user_message, nil, options) || default_msg
  end

  def user_message=(msg)
    options[:user_message] = msg
    update_attribute(:options, options)
  end

  def self.get_option_last(key, from)
    # Return value - Support array and non-array types
    data = from[key]
    data.kind_of?(Array) ? data.last : data
  end

  def get_option_last(key)
    MiqRequestMixin.get_option_last(key, self.options)
  end

  def get_user
    @user ||= User.find_by_userid(self.userid)
  end

  def tags
    self.tag_ids.to_miq_a.each do |tag_id|
      tag = Classification.find(tag_id)
      yield(tag.name, tag.parent.name)  unless tag.nil?    # yield the tag's name and category
    end
  end

  def get_tag(category)
    self.get_tags[category.to_sym]
  end

  def get_tags
    vm_tags = {}
    self.tags do |tag, cat|
      cat = cat.to_sym
      if vm_tags.has_key?(cat)
        vm_tags[cat] = [ vm_tags[cat] ]   unless vm_tags[cat].kind_of?(Array)
        vm_tags[cat] << tag
      else
        vm_tags[cat] = tag
      end
    end
    vm_tags
  end

  def clear_tag(category=nil, tag_name=nil)
    if category.nil?
      self.tag_ids = nil
    else
      deletes = []
      self.tag_ids.to_miq_a.each do |tag_id|
        tag = Classification.find(tag_id)
        next if category.to_s.casecmp(tag.parent.name) != 0
        next if !tag_name.blank? && tag_name.to_s.casecmp(tag.name) != 0
        deletes << tag_id
      end
      unless deletes.blank?
        self.tag_ids -= deletes
        self.update_attribute(:options, self.options)
      end
    end
  end

  def add_tag(category, tag_name)
    cat = Classification.find_by_name(category.to_s)
    return if cat.nil?
    tag = cat.children.detect {|t| t.name.casecmp(tag_name.to_s) == 0}
    return if tag.nil?
    self.tag_ids ||= []
    unless self.tag_ids.include?(tag.id)
      self.tag_ids << tag.id
      self.update_attribute(:options, self.options)
    end
  end

  def classifications
    self.tag_ids.to_miq_a.each do |tag_id|
      classification = Classification.find(tag_id)
      yield(classification)  unless classification.nil?    # yield the whole classification
    end
  end

  def get_classification(category)
    self.get_classifications[category.to_sym]
  end

  def get_classifications
    vm_classifications = {}
    self.classifications do |classification|
      cat   = classification.parent.name.to_sym
      tuple = { :name => classification.name, :description => classification.description }
      if vm_classifications.has_key?(cat)
        vm_classifications[cat] = [ vm_classifications[cat] ]   unless vm_classifications[cat].kind_of?(Array)
        vm_classifications[cat] << tuple
      else
        vm_classifications[cat] = tuple
      end
    end
    vm_classifications
  end

  def tag_ids(key = :tag_ids)
    self.options[key]
  end

  def tag_ids=(value, key = :tag_ids)
    self.options[key] = value
  end

  # Web-Service helper method
  def request_tags
    ws_tag_data = []
    ns = '/managed'
    self.classifications do |c|
      tag_name = c.to_tag
      next unless tag_name.starts_with?(ns)
      tag_path = tag_name.split('/')[2..-1].join('/')
      parts = tag_path.split('/')
      cat = Classification.find_by_name(parts.first)
      next if cat.show? == false
      cat_descript = cat.description
      tag_descript = Classification.find_by_name(tag_path).description
      ws_tag_data << {:category => parts.first, :category_display_name => cat_descript,
                      :tag_name => parts.last,  :tag_display_name => tag_descript,
                      :tag_path =>  File.join(ns, tag_path), :display_name => "#{cat_descript}: #{tag_descript}"
                     }
    end
    return ws_tag_data
  end

end
