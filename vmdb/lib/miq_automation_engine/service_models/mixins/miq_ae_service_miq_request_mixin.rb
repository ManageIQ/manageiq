module MiqAeServiceMiqRequestMixin

  def options
    object_send(:options)
  end

  def get_option(key)
    object_send(:get_option, key)
  end

  def get_option_last(key)
    object_send(:get_option_last, key)
  end

  def user_message=(msg)
    object_send('user_message=', msg)
  end

  def set_option(key, value)
    ar_method do
      @object.options[key] = value
      @object.update_attribute(:options, @object.options)
    end
  end

  def get_tag(category)
    object_send(:get_tag, category)
  end

  def get_tags
    object_send(:get_tags)
  end

  def clear_tag(category=nil, tag_name=nil)
    object_send(:clear_tag, category, tag_name)
  end

  def add_tag(category, tag_name)
    object_send(:add_tag, category, tag_name)
  end

  def get_classification(category)
    object_send(:get_classification, category)
  end

  def get_classifications
    object_send(:get_classifications)
  end

end
