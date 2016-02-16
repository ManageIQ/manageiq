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
    @layout = "deployment"
    if params["existing_vms"]
      provider = ExtManagementSystem.find(params['Provider']['provider_id'].to_i)
      vm_master = Vm.find(params['Vm']['master'].to_i)
      vm_slave1 = Vm.find(params['Vm']['vm1'].to_i)
      vm_slave2 = Vm.find(params['Vm']['vm2'].to_i)
      if provider.kind_of? ManageIQ::Providers::Google::CloudManager
        # extracting google vms ip
        ip_master = vm_master.provider_object.network_interfaces[0]['accessConfigs'][0]['natIP']
        ip_slave1 = vm_slave1.provider_object.network_interfaces[0]['accessConfigs'][0]['natIP']
        ip_slave2 = vm_slave2.provider_object.network_interfaces[0]['accessConfigs'][0]['natIP']
      else
        ip_master = vm_master.ipaddresses[0]
        ip_slave1 = vm_slave1.ipaddresses[0]
        ip_slave2 = vm_slave2.ipaddresses[0]

      end
      # to do
      add_ssh_key_to_known_hosts
      ssh_connection = check_ssh_connection(ip_master,
                                            params["providerMasterUsername"],
                                            params["providerMasterPassword"])
      if ssh_connection
        add_flash("Started deploying provider")
        ansible_deploy(params["providerMasterUsername"], ip_master, ip_slave1, ip_slave2)
      else
        add_flash("No ssh access", :erorr)
      end
    else
      # to do
      add_ssh_key_to_known_hosts
      ssh_connection = check_ssh_connection(params['masterIp'],
                                            params["masterUsername"],
                                            params["masterPassword"])
      if ssh_connection
        add_flash("Started deploying provider")
        ansible_deploy(params["masterUsername"],
                       params['masterIp'],
                       params['slave1Ip'],
                       params['slave2Ip'])
      else
        add_flash("No ssh access", :erorr)
      end
    end
  end

  private

  # can deploy by the rails server and (commented is on the master vm).
  def ansible_deploy(master_ssh_user, ip_master, ip_slave1, ip_slave2)
    make_deploy_playbook(master_ssh_user)
    make_ansible_inventory_file(ip_master, [ip_slave1, ip_slave2], master_ssh_user)
    # running it locally
    Thread.new do
      Dir.chdir('extras/openshift-ansible') do
        system "ansible-playbook playbooks/byo/config.yml -i ../../to_send_inventory.yaml "
      end
    end
    # in case we want to run the openshift-ansible on remote master
    # Thread.new do
    #   make_ansible_master_inventory_file(ip_master, params["providerMasterUsername"], params["providerMasterPassword"])
    #   system "ansible-playbook extras/playbooks/deploy_book.yaml -i master_inventory.yaml "
    # end
  end
end
