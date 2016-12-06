require 'shared/presenters/tree_node/common'

describe TreeNode::ExtManagementSystem do
  subject { described_class.new(object, nil, {}) }

  describe 'ManageIQ::Providers::Redhat::InfraManager' do
    let(:object) { FactoryGirl.create(:ems_redhat) }

    context 'has no name' do
      describe '#title' do
        before { object.name = nil }
        it 'returns with nil' do
          expect(subject.title).to be_nil
        end
      end
    end
  end

  {
    # Infrastructure providers
    :ems_microsoft                       => { :tip_prefix => 'Ems Infra' },
    :ems_openstack_infra                 => { :tip_prefix => 'Ems Infra' },
    :ems_redhat                          => { :tip_prefix => 'Ems Infra' },
    :ems_vmware                          => { :tip_prefix => 'Ems Infra' },
    # Cloud providers
    :ems_amazon                          => { :tip_prefix => 'Ems Cloud' },
    :ems_azure                           => { :tip_prefix => 'Ems Cloud' },
    :ems_google                          => { :tip_prefix => 'Ems Cloud' },
    :ems_openstack                       => { :tip_prefix => 'Ems Cloud' },
    :ems_vmware_cloud                    => { :tip_prefix => 'Ems Cloud' },
    # Other remaining providers
    :configuration_manager_ansible_tower => { :key_prefix => 'at-' },
    :configuration_manager_foreman       => { :key_prefix => 'fr-' },
    :provisioning_manager_foreman        => {},
    :ems_physical_infra                  => {},
    :ems_openshift_enterprise            => {},
    :ems_hawkular                        => {},
    :ems_azure_network                   => {},
    :ems_amazon_network                  => {},
    :ems_google_network                  => {},
    :ems_nuage_network                   => {},
    :ems_openstack_network               => { :suppress_callback => true },
    :ems_vmware_cloud_network            => {},
    :ems_cinder                          => {},
    :ems_swift                           => {},
    # :configuration_manager             => {},
    # :provisioning_manager              => {},
    # :ems_cloud                         => {},
    # :ems_container                     => {},
    # :ems_infra                         => {},
    # :ems_middleware                    => {},
    # :ems_network                       => {},
    # :ems_storage                       => {}
  }.each do |factory, spec|
    klass = FactoryGirl.factory_by_name(factory).instance_variable_get(:@class_name)
    context(klass) do
      before(:all) { klass.constantize.skip_callback(:save, :after, :stop_event_monitor_queue_on_change) if spec[:suppress_callback] }

      let(:object) { FactoryGirl.create(factory) }

      include_examples 'TreeNode::Node#key prefix', spec.fetch(:key_prefix, 'e-')
      include_examples 'TreeNode::Node#tooltip prefix', spec.fetch(:tip_prefix, 'Provider')

      describe '#image' do
        it 'returns with the image' do
          expect(subject.image).to eq("100/vendor-#{object.image_name}.png")
        end
      end
    end
  end
end
