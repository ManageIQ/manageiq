class DeploymentController < ApplicationController
  include ContainersCommonMixin
  include DeploymentHelper

  before_action :get_session_data
  after_action :set_session_data

  def new
    @layout = "deployment"
    @title = "Deploy new openshift provider"
    @vms = []
    @providers = ExtManagementSystem.all.select do |m|
      m.type.to_s.include?("CloudManager") || m.type.to_s.include?("InfraManager")
    end
    @providers.each do |p|
      @vms += p.vms
    end
    render "deployment"
  end

  def start_deployment
      # @layout = "deployment"
    # if params["existing_vms"]
    #   provider = ExtManagementSystem.find(params['Provider']['provider_id'].to_i)
    #   vm_master = Vm.find(params['Vm']['master'].to_i)
    #   vm_slave1 = Vm.find(params['Vm']['vm1'].to_i)
    #    vm_slave2 = Vm.find(params['Vm']['vm2'].to_i)
    #   if provider.kind_of? ManageIQ::Providers::Google::CloudManager
    #     # extracting google vms ip
    #     ip_master = vm_master.provider_object.network_interfaces[0]['accessConfigs'][0]['natIP']
    #     ip_slave1 = vm_slave1.provider_object.network_interfaces[0]['accessConfigs'][0]['natIP']
    #     ip_slave2 = vm_slave2.provider_object.network_interfaces[0]['accessConfigs'][0]['natIP']
    #   else
    #     ip_master = vm_master.ipaddresses[0]
    #     ip_slave1 = vm_slave1.ipaddresses[0]
    #     ip_slave2 = vm_slave2.ipaddresses[0]
    #
    #   end
    #   # to do
    #     add_flash("Started deploying provider")
    #     ansible_deploy(params["providerMasterUsername"], params["providerMasterPassword"], ip_master, ip_slave1, ip_slave2)
    # else
    #   # to do
    #     add_flash("Started deploying provider")
    #     ansible_deploy(params["masterUsername"],
    #                    params["masterPassword"],
    #                    params['masterIp'],
    #                    params['slave1Ip'],
    #                    params['slave2Ip'])
    #
    # end
    ansible_deploy('root',nil,"",[],['',""])
    render "start_deployment"

  end

  # can deploy by the rails server and (commented is on the master vm).
  def ansible_deploy(master_ssh_user, master_ssh_password, main_master_ip, masters_ips, nodes_ips)
    Thread.new do
      url = 'http://localhost:3000'
      query = '/api/automation_requests'

      post_params = {
        :version => '1.1',
        :uri_parts => {
          :namespace => 'Test/System',
          :class => 'Request',
          :instance => 'Deployment'
        },
        :requester => {
          :auto_approve => true
        },
        :parameters => {
          # need to add params
          :type     => "managed_provision", # managed_existing, managed_provision, not_managed
          :master   => {
            :templateFields => {
              'name'         => 'rhel7_vfio_full',
              'request_type' => 'template'
            },
            :vmFields => {
              'vm_name'   => 'alon-master3',
              'vlan'      => 'public',
              'vm_memory' => '1024',
            },
            :requester => {
              'owner_email'      => 'pemcg@bit63.com',
              'owner_first_name' => 'Peter',
              'owner_last_name'  => 'McGowan'
            },
            :tags => nil,
            :ws_values => {
              'disk_size_gb' => '50',
              'mountpoint' => '/opt',
              'skip_dialog_load' => true,

            }
          },
          :node     => {
            :templateFields => {
              'name'         => 'rhel7_vfio_full',
              'request_type' => 'template'
            },
            :vmFields => {
              'vm_name'   => 'alon-node3',
              'vlan'      => 'public',
              'vm_memory' => '1024',
            },
            :requester => {
              'owner_email'      => 'pemcg@bit63.com',
              'owner_first_name' => 'Peter',
              'owner_last_name'  => 'McGowan'
            },
            :tags => nil,
            :ws_values => {
              'disk_size_gb' => '50',
              'mountpoint' => '/opt',
              'skip_dialog_load' => true,
            }
          },
          # :connect_through_master_ip => main_master_ip,
          # :masters_ips  => masters_ips,
          # :nodes_ips    => nodes_ips,
          # :user     => master_ssh_user,
          # :password => master_ssh_password
        }
      }.to_json
      rest_return = RestClient::Request.execute(
        method: :post,
        url: url + query,
        :user => 'admin',
        :password => 'smartvm',
        :headers => {:accept => :json},
        :payload => post_params,
        verify_ssl: false)
    end
  end
end
