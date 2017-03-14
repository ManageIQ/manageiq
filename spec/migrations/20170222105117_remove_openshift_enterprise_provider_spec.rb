require_migration

describe RemoveOpenshiftEnterpriseProvider do
  let(:ems_stub)  { migration_stub(:ExtManagementSystem) }
  let(:auth_stub) { migration_stub(:Authentication) }
  let(:workers_stub) { migration_stub(:MiqWorker) }
  let(:queue_stub) { migration_stub(:MiqQueue) }

  migration_context :up do
    it "Updates Atomic Provider to Openshift and Atomic Enterprise to Openshift Enterprise" do
      type_examples = [
        {:table          => ems_stub,
         :pre_migration  => "ManageIQ::Providers::OpenshiftEnterprise::ContainerManager",
         :post_migration => "ManageIQ::Providers::Openshift::ContainerManager",
         :record         => nil},
        {:table          => ems_stub,
         :pre_migration  => "EmsOther",
         :post_migration => "EmsOther",
         :record         => nil},
        {:table          => workers_stub,
         :pre_migration  => "ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::EventCatcher",
         :post_migration => "ManageIQ::Providers::Openshift::ContainerManager::EventCatcher",
         :record         => nil},
        {:table          => workers_stub,
         :pre_migration  => "ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::MetricsCollectorWorker",
         :post_migration => "ManageIQ::Providers::Openshift::ContainerManager::MetricsCollectorWorker",
         :record         => nil},
        {:table          => workers_stub,
         :pre_migration  => "ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::RefreshWorker",
         :post_migration => "ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker",
         :record         => nil},
        {:table          => workers_stub,
         :pre_migration  => "OtherWorker",
         :post_migration => "OtherWorker",
         :record         => nil}
      ].each do |ex|
        ex[:record] = ex[:table].create!(:type => ex[:pre_migration])
      end

      name_examples = [
        {:table          => auth_stub,
         :pre_migration  => "ManageIQ::Providers::OpenshiftEnterprise::ContainerManager Server1",
         :post_migration => "ManageIQ::Providers::Openshift::ContainerManager Server1",
         :record         => nil},
        {:table          => auth_stub,
         :pre_migration  => "EmsOther Server3",
         :post_migration => "EmsOther Server3",
         :record         => nil}
      ].each do |ex|
        ex[:record] = ex[:table].create!(:name => ex[:pre_migration])
      end

      args_examples = [
        {:table          => queue_stub,
         :pre_migration  => "[[[\"ManageIQ::Providers::OpenshiftEnterprise::ContainerManager\", 12]]]",
         :post_migration => "[[[\"ManageIQ::Providers::Openshift::ContainerManager\", 12]]]",
         :record         => nil},
        {:table          => queue_stub,
         :pre_migration  => "[[[\"EmsOther\", 21]]]",
         :post_migration => "[[[\"EmsOther\", 21]]]",
         :record         => nil},

        {:table          => queue_stub,
         :pre_migration  => "[]",
         :post_migration => "[]",
         :record         => nil}
      ].each do |ex|
        ex[:record] = ex[:table].create!(:args => ex[:pre_migration])
      end

      migrate

      type_examples.each do |ex|
        ex[:record].reload
        expect(ex[:record].type).to eq(ex[:post_migration])
      end

      name_examples.each do |ex|
        ex[:record].reload
        expect(ex[:record].name).to eq(ex[:post_migration])
      end

      args_examples.each do |ex|
        ex[:record].reload
        expect(ex[:record].args).to eq(ex[:post_migration])
      end
    end
  end
end
