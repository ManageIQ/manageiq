class ChangeNilProvisionIndexToZero < ActiveRecord::Migration
  class ServiceResource < ActiveRecord::Base
  end

  def up
    say_with_time("Change service_resource provision_index from nil to zero") do
      ServiceResource.where(:provision_index => nil).update_all(:provision_index => 0)
    end
  end
end
