class ManageIQ::Providers::Amazon::AeDatastore
  def self.seed
    dir = Rails.root.join("gems/manageiq-providers-amazon/db/fixtures/ae_datastore/")
    MiqAeDatastore.reset_domain(dir, 'Amazon', Tenant.root_tenant)
  end
end