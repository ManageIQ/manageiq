class Share < ApplicationRecord
  has_many :share_receivers
  has_many :tenants, :through => :share_receivers
  has_many :share_members
  has_many :shared_miq_templates,     :through => :share_members,
           :source => :shareable,      :source_type => "MiqTemplate"
  has_many :shared_service_templates, :through => :share_members,
           :source => :shareable,      :source_type => "ServiceTemplate"

  belongs_to :sharer,  :class_name => "User"

  has_and_belongs_to_many :miq_product_features

  validates_presence_of :share_receivers, :share_members, :sharer, :miq_product_features

  # Remember, this is eager-loaded
  def shareables
    shared_miq_templates + shared_service_templates
  end
end
