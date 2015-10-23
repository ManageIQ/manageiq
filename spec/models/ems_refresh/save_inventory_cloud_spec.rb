require 'spec_helper'

describe ManageIQ::Providers::Amazon::CloudManager::Refresher do
  let(:hashes) do
    [
      {:type                => 'ManageIQ::Providers::Amazon::CloudManager::SecurityGroup',
       :ems_ref             => 'sg-e94055ac',
       :name                => 'default',
       :description         => 'default group',
       :cloud_network       => nil,
       :orchestration_stack => nil,
       :firewall_rules      => [
         {:direction             => nil,
          :host_protocol         => nil,
          :port                  => nil,
          :end_port              => nil,
          :source_security_group => nil
         },
         {:direction             => nil,
          :host_protocol         => nil,
          :port                  => nil,
          :end_port              => nil,
          :source_security_group => nil
         },
         {:direction             => 'inbound',
          :host_protocol         => 'ICMP',
          :port                  => -1,
          :end_port              => -1,
          :source_security_group => nil
         }]
      },
      {:type                => 'ManageIQ::Providers::Amazon::CloudManager::SecurityGroup',
       :ems_ref             => 'sg-2b87746f',
       :name                => 'EmsRefreshSpec-SecurityGroup-OtherRegion',
       :description         => 'EmsRefreshSpec-SecurityGroup-OtherRegion',
       :cloud_network       => nil,
       :orchestration_stack => nil,
       :firewall_rules      => [
         {:direction       => 'inbound',
          :host_protocol   => 'TCP',
          :port            => 0,
          :end_port        => 65_535,
          :source_ip_range => '0.0.0.0/0'
         }]
      }
    ]
  end

  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_amazon, :zone => zone)
  end

  context '.save_security_groups_inventory' do
    it 'should handle empty firewall rules' do
      expect(EmsRefresh.save_security_groups_inventory(@ems, hashes).uniq(&:id).count).to eq(4)
    end
  end
end
