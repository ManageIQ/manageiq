require_migration

describe SetCorrectStiTypeOnOpenstackInfraMiqTemplate do
  let(:ext_management_system_stub) { migration_stub(:ExtManagementSystem) }
  let(:miq_template_stub) { migration_stub(:Vm) }

  let(:ems_row_entries) do
    [
      {:type => "ManageIQ::Providers::Openstack::InfraManager"},
      {:type => "ManageIQ::Providers::Openstack::CloudManager"},
      {:type => "ManageIQ::Providers::AnotherManager"}
    ]
  end

  let(:row_entries) do
    [
      {
        :ems      => ems_row_entries[0],
        :name     => "template_1",
        :type_in  => 'ManageIQ::Providers::Openstack::CloudManager::Template',
        :type_out => 'ManageIQ::Providers::Openstack::InfraManager::Template'
      },
      {
        :ems      => ems_row_entries[0],
        :name     => "template_2",
        :type_in  => 'ManageIQ::Providers::Openstack::CloudManager::Template',
        :type_out => 'ManageIQ::Providers::Openstack::InfraManager::Template'
      },
      {
        :ems      => ems_row_entries[1],
        :name     => "template_3",
        :type_in  => 'ManageIQ::Providers::Openstack::CloudManager::Template',
        :type_out => 'ManageIQ::Providers::Openstack::CloudManager::Template'
      },
      {
        :ems      => ems_row_entries[2],
        :name     => "template_4",
        :type_in  => 'ManageIQ::Providers::AnyManager::Template',
        :type_out => 'ManageIQ::Providers::AnyManager::Template'
      },
    ]
  end

  migration_context :up do
    it "migrates a series of representative row" do
      ems_row_entries.each do |x|
        x[:ems] = ext_management_system_stub.create!(:type => x[:type])
      end

      row_entries.each do |x|
        x[:miq_template] = miq_template_stub.create!(:type => x[:type_in], :ems_id => x[:ems][:ems].id, :name => x[:name])
      end

      migrate

      row_entries.each do |x|
        expect(x[:miq_template].reload).to have_attributes(
                                      :type   => x[:type_out],
                                      :name   => x[:name],
                                      :ems_id => x[:ems][:ems].id
                                    )
      end
    end
  end

  migration_context :down do
    it "migrates a series of representative row" do
      ems_row_entries.each do |x|
        x[:ems] = ext_management_system_stub.create!(:type => x[:type])
      end

      row_entries.each do |x|
        x[:miq_template] = miq_template_stub.create!(:type => x[:type_out], :ems_id => x[:ems][:ems].id, :name => x[:name])
      end

      migrate

      row_entries.each do |x|
        expect(x[:miq_template].reload).to have_attributes(
                                             :type   => x[:type_in],
                                             :name   => x[:name],
                                             :ems_id => x[:ems][:ems].id
        )
      end
    end
  end
end
