module CustomAttributeMixin
  extend ActiveSupport::Concern

  included do
    has_many   :custom_attributes,     :as => :resource, :dependent => :destroy
    has_many   :miq_custom_attributes, :as => :resource, :dependent => :destroy, :class_name => "CustomAttribute", :conditions => {:source => 'EVM'}

    # This is a set of helper getter and setter methods to support the transition
    # between "custom_*" fields in the model and using the custom_attributes table.
    (1..9).each do |custom_id|
      custom_str = "custom_#{custom_id}"
      getter     = custom_str.to_sym
      setter     = "#{custom_str}=".to_sym

      define_method(getter) do
        miq_custom_get(custom_str)
      end
      virtual_column getter, :type => :string  # uses not set since miq_custom_get re-queries

      define_method(setter) do |value|
        miq_custom_set(custom_str, value)
      end
    end
  end

  def miq_custom_keys
    self.miq_custom_attributes.pluck(:name)
  end

  def miq_custom_get(key)
    self.miq_custom_attributes.where(:name => key.to_s).first.try(:value)
  end

  def miq_custom_set(key, value)
    return miq_custom_delete(key) if value.blank?

    record = self.miq_custom_attributes.where(:name => key.to_s).first
    if record.nil?
      self.miq_custom_attributes.create(:name => key.to_s, :value => value)
    else
      record.update_attributes(:value => value)
    end
  end

  def miq_custom_delete(key)
    self.miq_custom_attributes.where(:name => key.to_s).first.try(:delete)
  end

end
