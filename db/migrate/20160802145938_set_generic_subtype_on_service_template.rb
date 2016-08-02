class SetGenericSubtypeOnServiceTemplate < ActiveRecord::Migration[5.0]
  class ServiceTemplate < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time('Set generic_subtype to custom on ServiceTemplate') do
      ServiceTemplate.where(:prov_type => "generic").update_all(:generic_subtype => "custom")
    end
  end

  def down
    ServiceTemplate.where(:prov_type => "generic").update_all(:generic_subtype => nil)
  end
end
