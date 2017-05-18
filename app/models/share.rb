class Share < ApplicationRecord
  has_many :miq_product_features_shares
  has_many :miq_product_features, :through => :miq_product_features_shares

  belongs_to :tenant
  belongs_to :user
  belongs_to :resource, :polymorphic => true

  validates :miq_product_features, :presence => true
  validates :resource,             :presence => true
  validates :tenant,               :presence => true
  validates :user,                 :presence => true

  default_value_for :allow_tenant_inheritance, false

  scope :by_tenant_inheritance, ->(tenant) do
    where(:tenant => tenant.accessible_tenant_ids(:ancestor_ids),
          :allow_tenant_inheritance => true)
      .or(where(:tenant => tenant))
  end
end
