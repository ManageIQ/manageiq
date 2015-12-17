require "spec_helper"

describe Host do
  describe "#refresh_network_interfaces" do
    let(:network_interfaces_text) do
      <<-EOT
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast master ovs-system state UP qlen 1000
    link/ether 00:f9:e4:fe:20:68 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::2f9:e4ff:fefe:2068/64 scope link
       valid_lft forever preferred_lft forever
3: ovs-system: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN
    link/ether 86:01:66:77:49:a3 brd ff:ff:ff:ff:ff:ff
4: br-ex: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN
    link/ether 00:f9:e4:fe:20:68 brd ff:ff:ff:ff:ff:ff
    inet 192.0.2.6/24 brd 192.0.2.255 scope global dynamic br-ex
       valid_lft 86366sec preferred_lft 86366sec
    inet6 fe80::2f9:e4ff:fefe:2068/64 scope link
       valid_lft forever preferred_lft forever
5: vlan40: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN
    link/ether 66:57:ae:70:3d:2f brd ff:ff:ff:ff:ff:ff
    inet 172.16.19.11/24 brd 172.16.19.255 scope global vlan40
       valid_lft forever preferred_lft forever
    inet6 fe80::6457:aeff:fe70:3d2f/64 scope link
       valid_lft forever preferred_lft forever
6: vlan20: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN
    link/ether 86:57:dd:80:ad:35 brd ff:ff:ff:ff:ff:ff
    inet 172.16.20.13/24 brd 172.16.20.255 scope global vlan20
       valid_lft forever preferred_lft forever
    inet6 fe80::8457:ddff:fe80:ad35/64 scope link
       valid_lft forever preferred_lft forever
7: vlan50: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN
    link/ether 3a:2a:a1:fd:32:54 brd ff:ff:ff:ff:ff:ff
    inet 172.16.22.11/24 brd 172.16.22.255 scope global vlan50
       valid_lft forever preferred_lft forever
    inet6 fe80::382a:a1ff:fefd:3254/64 scope link
       valid_lft forever preferred_lft forever
8: vlan10: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN
    link/ether be:0b:0f:3d:3e:97 brd ff:ff:ff:ff:ff:ff
    inet 172.16.23.11/24 brd 172.16.23.255 scope global vlan10
       valid_lft forever preferred_lft forever
    inet6 fe80::bc0b:fff:fe3d:3e97/64 scope link
       valid_lft forever preferred_lft forever
9: vlan30: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN
    link/ether 76:a8:96:45:d8:25 brd ff:ff:ff:ff:ff:ff
    inet 172.16.21.11/24 brd 172.16.21.255 scope global vlan30
       valid_lft forever preferred_lft forever
    inet6 fe80::74a8:96ff:fe45:d825/64 scope link
       valid_lft forever preferred_lft forever
10: br-int: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN
    link/ether 06:bc:ae:d4:05:48 brd ff:ff:ff:ff:ff:ff
11: br-tun: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN
    link/ether c2:88:60:f8:76:47 brd ff:ff:ff:ff:ff:ff
      EOT
    end

    let(:ssu) do
      double('ssu').tap do |ssu|
        ssu.should_receive(:shell_exec).with("ip a").and_return(network_interfaces_text)
      end
    end

    let(:ems) { FactoryGirl.create(:ems_openstack_infra) }

    let(:vlan10) { FactoryGirl.create(:cloud_network_openstack_infra, :name => "vlan10") }
    let(:vlan20) { FactoryGirl.create(:cloud_network_openstack_infra, :name => "vlan20") }
    let(:vlan30) { FactoryGirl.create(:cloud_network_openstack_infra, :name => "vlan30") }
    let(:vlan40) { FactoryGirl.create(:cloud_network_openstack_infra, :name => "vlan40") }
    let(:vlan50) { FactoryGirl.create(:cloud_network_openstack_infra, :name => "vlan50") }

    let(:host) do
      FactoryGirl.create(:host_openstack_infra).tap do |host|
        host.stub(:connect_ssh).and_yield(ssu)
        # Define EMS
        host.ext_management_system = ems
        # Define networks
        host.ext_management_system.cloud_networks << vlan10
        host.ext_management_system.cloud_networks << vlan20
        host.ext_management_system.cloud_networks << vlan30
        host.ext_management_system.cloud_networks << vlan40
        host.ext_management_system.cloud_networks << vlan50
        # Define subnets
        FactoryGirl.create(
          :cloud_subnet_openstack_infra, :name => "vlan10", :cidr => "172.16.23.0/24", :cloud_network => vlan10,
          :ip_version => 4)
        FactoryGirl.create(
          :cloud_subnet_openstack_infra, :name => "vlan20", :cidr => "172.16.20.0/24", :cloud_network => vlan20,
          :ip_version => 4)
        FactoryGirl.create(
          :cloud_subnet_openstack_infra, :name => "vlan30", :cidr => "172.16.21.0/24", :cloud_network => vlan30,
          :ip_version => 4)
        FactoryGirl.create(
          :cloud_subnet_openstack_infra, :name => "vlan40", :cidr => "172.16.19.0/24", :cloud_network => vlan40,
          :ip_version => 4)
        FactoryGirl.create(
          :cloud_subnet_openstack_infra, :name => "vlan50", :cidr => "172.16.22.0/24", :cloud_network => vlan50,
          :ip_version => 4)
      end
    end

    describe "when refresh didn't store any interfaces" do
      before(:each) do
        host.refresh_network_interfaces(ssu)
      end

      it "should collect all network interfaces" do
        expected = ["br-tun", "br-int", "vlan30", "vlan10", "vlan50", "vlan20", "vlan40", "ovs-system", "br-ex,eth0",
                    "lo"]
        host.network_ports.map(&:name).should include(*expected)
      end

      it "should collect br-tun" do
        network_port = host.network_ports.where(:name => "br-tun").first
        network_port.attributes.should include({
          "type"                           => "ManageIQ::Providers::Openstack::InfraManager::NetworkPort",
          "name"                           => "br-tun",
          "ems_ref"                        => nil,
          "cloud_network_id"               => nil,
          "cloud_subnet_id"                => nil,
          "mac_address"                    => "c2:88:60:f8:76:47",
          "status"                         => nil,
          "admin_state_up"                 => nil,
          "device_owner"                   => nil,
          "device_ref"                     => nil,
          "cloud_tenant_id"                => nil,
          "binding_host_id"                => nil,
          "binding_virtual_interface_type" => nil,
          "extra_attributes"               => {:fixed_ips => {:subnet_id     => nil,
                                                              :ip_address    => nil,
                                                              :ip_address_v6 => nil}},
          "source"                         => "smartstate"})

        expect(network_port.device).to eq host
        expect(network_port.ext_management_system).to eq host.ext_management_system
      end

      it "should collect vlan10" do
        network_port = host.network_ports.where(:name => "vlan10").first

        network_port.attributes.should include({
          "type"                           => "ManageIQ::Providers::Openstack::InfraManager::NetworkPort",
          "name"                           => "vlan10",
          "ems_ref"                        => nil,
          "mac_address"                    => "be:0b:0f:3d:3e:97",
          "status"                         => nil,
          "admin_state_up"                 => nil,
          "device_owner"                   => nil,
          "device_ref"                     => nil,
          "cloud_tenant_id"                => nil,
          "binding_host_id"                => nil,
          "binding_virtual_interface_type" => nil,
          "extra_attributes"               => {:fixed_ips => {:subnet_id     => nil,
                                                              :ip_address    => "172.16.23.11",
                                                              :ip_address_v6 => "fe80::bc0b:fff:fe3d:3e97"}},
          "source"                         => "smartstate"})

        expect(network_port.device).to eq host
        expect(network_port.ext_management_system).to eq host.ext_management_system
        expect(network_port.cloud_subnet).to eq vlan10.cloud_subnets.first
        expect(network_port.cloud_network).to eq vlan10
      end

      it "should collect br-ex and eth0 and join the according to same mac address" do
        network_port = host.network_ports.where(:name => "br-ex,eth0").first

        network_port.attributes.should include({
          "type"                           => "ManageIQ::Providers::Openstack::InfraManager::NetworkPort",
          "name"                           => "br-ex,eth0",
          "ems_ref"                        => nil,
          "mac_address"                    => "00:f9:e4:fe:20:68",
          "status"                         => nil,
          "admin_state_up"                 => nil,
          "device_owner"                   => nil,
          "device_ref"                     => nil,
          "cloud_tenant_id"                => nil,
          "binding_host_id"                => nil,
          "binding_virtual_interface_type" => nil,
          "extra_attributes"               => {:fixed_ips => {:subnet_id     => nil,
                                                              :ip_address    => "192.0.2.6",
                                                              :ip_address_v6 => "fe80::2f9:e4ff:fefe:2068"}},
          "source"                         => "smartstate"})

        expect(network_port.device).to eq host
        expect(network_port.ext_management_system).to eq host.ext_management_system
        expect(network_port.cloud_subnet).to be_nil
        expect(network_port.cloud_network).to be_nil
      end

      it "should have network association of all vlans" do
        associated = ["vlan30", "vlan10", "vlan50", "vlan20", "vlan40"]
        not_associated = ["br-tun", "br-int", "ovs-system", "br-ex,eth0", "lo"]

        associated.each do |network_port_name|
          network_port = host.network_ports.where(:name => network_port_name).first
          expect(network_port.device).to eq host
          expect(network_port.ext_management_system).to eq host.ext_management_system
          expect(network_port.cloud_subnet).to eq self.send(network_port_name).cloud_subnets.first
          expect(network_port.cloud_network).to eq self.send(network_port_name)
        end

        not_associated.each do |network_port_name|
          network_port = host.network_ports.where(:name => network_port_name).first
          expect(network_port.device).to eq host
          expect(network_port.ext_management_system).to eq host.ext_management_system
          expect(network_port.cloud_subnet).to be_nil
          expect(network_port.cloud_network).to be_nil
        end
      end
    end

    describe "when there are existing records created by refresh" do
      it "updates existing record name when it's nil" do
        host.ext_management_system.network_ports <<
          FactoryGirl.create(:network_port_openstack_infra, :name => "", :mac_address => "be:0b:0f:3d:3e:97",
                             :source => :neutron, :device => host)

        host.refresh_network_interfaces(ssu)

        expected = ["vlan10", "br-tun", "br-int", "vlan30", "vlan50", "vlan20", "vlan40", "ovs-system", "br-ex,eth0",
                    "lo"]
        host.network_ports.map(&:name).should include(*expected)

        network_port = host.network_ports.where(:name => "vlan10").first
        expect(network_port.device).to eq host
        expect(network_port.ext_management_system).to eq host.ext_management_system
        # Subnets associations are not updated
        expect(network_port.cloud_subnet).to be_nil
        expect(network_port.cloud_network).to be_nil
      end

      it "do not change existing record name when it's not nil" do
        host.ext_management_system.network_ports <<
          FactoryGirl.create(:network_port_openstack_infra, :name => "vlan10_new", :mac_address => "be:0b:0f:3d:3e:97",
                             :source => :neutron, :device => host)

        host.refresh_network_interfaces(ssu)

        expected = ["vlan10_new", "br-tun", "br-int", "vlan30", "vlan50", "vlan20", "vlan40", "ovs-system", "br-ex,eth0",
                    "lo"]
        host.network_ports.map(&:name).should include(*expected)

        network_port = host.network_ports.where(:name => "vlan10_new").first
        expect(network_port.device).to eq host
        expect(network_port.ext_management_system).to eq host.ext_management_system
        # Subnets associations are not updated
        expect(network_port.cloud_subnet).to be_nil
        expect(network_port.cloud_network).to be_nil
      end
    end
  end
end
