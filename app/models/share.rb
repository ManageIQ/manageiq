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

  def self.sweeper_timer
    all.each do |share|
      # It would be better and necessary to do a soft delete here. Perhaps we add a boolean col called "enabled"
      # so that we can flip it either way depending on whether it's valid or not.
      unless ResourceSharer.valid_share?(share)
        _log.info("Deleting share: [#{share.id}] owner: [#{share.user.name}] resource: [#{share.resource.name}] tenant [#{share.tenant.name}], due to invalid RBAC")
        share.destroy
      end
    end
  end
end
