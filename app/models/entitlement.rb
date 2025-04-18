class Entitlement < ApplicationRecord
  belongs_to :miq_group
  belongs_to :miq_user_role

  serialize :filters
  serialize :filter_expression

  validate :one_kind_of_managed_filter

  virtual_delegate :name, :to => :miq_user_role, :allow_nil => true, :prefix => true, :type => :string

  def self.valid_filters?(filters_hash)
    return true  unless filters_hash                  # nil ok
    return false unless filters_hash.kind_of?(Hash)   # must be Hash
    return true  if filters_hash.blank?               # {} ok

    filters_hash["managed"].present? || filters_hash["belongsto"].present?
  end

  def self.update_managed_filters_on_name_change(old_tag, new_tag)
    where.not(:filters => nil).find_each do |entitlement|
      entitlement.update_managed_filters_on_name_change(old_tag, new_tag)
      entitlement.save if entitlement.filters_changed?
    end
  end

  def self.remove_tag_from_all_managed_filters(tag)
    where.not(:filters => nil).find_each do |entitlement|
      entitlement.remove_tag_from_managed_filter(tag)
      entitlement.save if entitlement.filters_changed?
    end
  end

  def has_filters?
    get_managed_filters.present? || get_belongsto_filters.present?
  end

  def get_filters(type = nil)
    if type
      (filters.respond_to?(:key?) && filters[type.to_s]) || []
    else
      filters || {"managed" => [], "belongsto" => []}
    end
  end

  def get_managed_filters
    get_filters("managed")
  end

  def get_belongsto_filters
    get_filters("belongsto")
  end

  def set_filters(type, filter)
    self.filters ||= {}
    filters[type.to_s] = filter
  end

  def set_managed_filters(filter)
    set_filters("managed", filter)
  end
  alias managed_filters= set_managed_filters

  def set_belongsto_filters(filter)
    set_filters("belongsto", filter)
  end
  alias belongsto_filter= set_belongsto_filters

  def update_managed_filters_on_name_change(old_tag, new_tag)
    return if filters.blank? || filters["managed"].blank?

    filters["managed"].each do |filter|
      if filter.include?(old_tag)
        filter.delete(old_tag)
        filter.append(new_tag)
      end
    end
  end

  def remove_tag_from_managed_filter(filter_to_remove)
    if get_managed_filters.present?
      self.filters["managed"].each do |filter|
        next unless filter.include?(filter_to_remove)

        filter.delete(filter_to_remove)
      end
      self.filters["managed"].reject!(&:empty?)
    end
  end

  def one_kind_of_managed_filter
    if get_managed_filters.any? && filter_expression
      errors.add(:base, "cannot have both managed filters and a filter expression")
    end
  end
end
