module CiFeatureMixin
  extend ActiveSupport::Concern

  def retireable?
    resource.present? && resource.respond_to?(:retire_now) && resource.type.present?
  end
end
