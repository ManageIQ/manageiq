class AssignTenant < ActiveRecord::Migration
  class Tenant < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI

    # seed and return the current root_tenant
    def self.root_tenant
      Tenant.create_with(
        :name                      => "My Company",
        :description               => "Tenant for My Company",
        :divisible                 => true,
        :use_config_for_attributes => true,
      ).find_or_create_by(:ancestry => nil)
    end
  end

  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class MiqAeNamespace < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class MiqGroup < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Provider < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class TenantQuota < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Vm < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def change
    Tenant.connection.schema_cache.clear!
    Tenant.reset_column_information

    models = [ExtManagementSystem, MiqAeNamespace, MiqGroup,
              Provider, TenantQuota, Vm]

    # only create a root tenant if there are records in the db
    return unless MiqGroup.exists?

    say_with_time "assigning tenant to models" do
      root_tenant = Tenant.root_tenant
      models.each do |model|
        model.where(:tenant_id => nil).update_all(:tenant_id => root_tenant.id)
      end
    end
  end
end
