class AssignVmGroup < ActiveRecord::Migration
  class Tenant < ActiveRecord::Base
    def self.root_tenant
      where(:ancestry => nil).first
    end
  end

  class VmOrTemplate < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    self.table_name = 'vms'
  end

  class Service < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    group_id = Tenant.root_tenant.try(:default_miq_group_id)

    return unless group_id

    say_with_time "assign default vm groups" do
      VmOrTemplate.where(:miq_group_id => nil).update_all(:miq_group_id => group_id)
    end

    say_with_time "assign default service miq_groups" do
      Service.where(:miq_group_id => nil).update_all(:miq_group_id => group_id)
    end
  end
end
