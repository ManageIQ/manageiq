module MiqProvisionDialogs
  def self.dialogs
    {
      :dialog_order => [:requester,:purpose,:service,:environment,:hardware,:network,:customize,:schedule],
      :buttons => [:submit, :cancel],     # :continue
      :dialogs      => {
    :requester => {
          :description => "Requester",
          :display     => :show, # :hide || :show || :ignore
          :field_order => nil,   # future
          :fields      => { # :display => :hide || :ignore || :show || :edit
      :owner_email          => {:data_type => :string, :display => :edit, :required => true, :description => "E-Mail"},
      :owner_first_name     => {:data_type => :string, :display => :edit, :required => true, :description => "First Name"},
      :owner_last_name      => {:data_type => :string, :display => :edit, :required => true, :description => "Last Name"},
      :owner_load_ldap      => {:data_type => :button, :display => :show, :required => false, :description => "Look Up LDAP Email",:pressed => {:method => :retrieve_ldap} },
      :owner_address        => {:data_type => :string, :display => :edit, :required => false, :description => "Address"},
      :owner_city           => {:data_type => :string, :display => :edit, :required => false, :description => "City"},
      :owner_state          => {:data_type => :string, :display => :edit, :required => false, :description => "State"},
      :owner_zip            => {:data_type => :string, :display => :edit, :required => false, :description => "Zip code"},
      :owner_country        => {:data_type => :string, :display => :edit, :required => false, :description => "Country/Region"},
      :owner_title          => {:data_type => :string, :display => :edit, :required => false, :description => "Title"},
      :owner_company        => {:data_type => :string, :display => :edit, :required => false, :description => "Company"},
      :owner_department     => {:data_type => :string, :display => :edit, :required => false, :description => "Department"},
      :owner_office         => {:data_type => :string, :display => :edit, :required => false, :description => "Office"},
      :owner_phone          => {:data_type => :string, :display => :edit, :required => false, :description => "Phone"},
      :owner_phone_mobile   => {:data_type => :string, :display => :edit, :required => false, :description => "Mobile"},
      :owner_manager        => {:data_type => :string, :display => :edit, :required => false, :description => "Name"},
      :owner_manager_mail   => {:data_type => :string, :display => :edit, :required => false, :description => "E-Mail"},
      :owner_manager_phone  => {:data_type => :string, :display => :edit, :required => false, :description => "Phone"}
          }
        },
    :purpose => {
          :description => "Purpose",
          :display     => :show, # :hide || :show || :ignore
          :field_order => nil,   # future
          :fields      => {
      :vm_tags => {:data_type => :integer, :display => :edit, :required => false, :description => "Tags",:required_method=>:validate_tags, :required_tags=>[], :options => {:exclude => [], :include => [], :single_select=>[], :order=>[]}},
          }
        },
    :service => {
          :description => "Catalog",
          :display     => :show,
          :fields      => {
      :vm_filter       => {:data_type => :integer, :display => :edit, :required => false, :description => "Filter",:values_from => {:method => :allowed_filters, :options => {:category => :Vm}} },
      :src_vm_id       => {:data_type => :integer, :display => :edit, :required => true, :description => "Name",:values_from => {:method => :allowed_templates, :options => {:tag_filters => []} }, :notes=>nil, :notes_display=>:show},
      :provision_type  => {:data_type => :string, :display => :edit, :required => true, :description => "Provision Type",:default => "vmware",:values_from => {:method => :allowed_provision_types} },
      :linked_clone    => {:data_type => :boolean, :display => :edit, :required => false, :description => "Linked Clone",:default => false,:values => { false => 0,true => 1}, :notes=>'VM requires a snapshot', :notes_display=>:show},
      :snapshot        => {:data_type => :string,  :display => :edit, :required => false, :description => "Snapshot", :values_from => {:method => :allowed_snapshots}, :auto_select_single => false },
      :number_of_vms   => {:data_type => :integer, :display => :edit, :required => false, :description => "Count", :default => 1,:values_from => {:method => :allowed_number_of_vms, :options => {:max => 50}} },
      :vm_name         => {:data_type => :string, :display => :edit, :required => true, :required_method=>:validate_vm_name, :min_length => nil, :max_length => nil, :description => "VM Name",:notes=>nil, :notes_display=>:show },
      :vm_description  => {:data_type => :string, :display => :edit, :required => false, :min_length => nil, :max_length => 100, :description => "VM Description"},
      :vm_prefix       => {:data_type => :string, :display => :hide, :required => false, :required_method=>:validate_vm_name, :description => "VM Name Prefix/Suffix"},
      :host_name       => {:data_type => :string, :display => :hide, :required => false, :description => "Host Name"}
          }
        },
    :environment => {
          :description => "Environment",
          :display     => :show,
          :fields      => {
      :placement_auto                   => {:data_type => :boolean, :display => :edit, :required => false, :description => "Choose Automatically",:default => false,:values  => { false		=> 0,true    => 1}},
      :placement_folder_name            => {:data_type => :integer, :display => :edit, :required => false, :description => "Name",:values_from => {:method => :allowed_folders}, :auto_select_single => false },
      :cluster_filter                   => {:data_type => :integer, :display => :edit, :required => false, :description => "Filter",:values_from => {:method => :allowed_filters, :options => {:category => :EmsCluster}}, :auto_select_single => false },
      :placement_cluster_name           => {:data_type => :integer, :display => :edit, :required => false, :description => "Name",:values_from => {:method => :allowed_clusters}, :auto_select_single => false},
      :rp_filter                        => {:data_type => :integer, :display => :edit, :required => false, :description => "Filter",:values_from => {:method => :allowed_filters, :options => {:category => :ResourcePool}}, :auto_select_single => false },
      :placement_rp_name                => {:data_type => :integer, :display => :edit, :required => false, :description => "Name",:values_from => {:method => :allowed_respools}, :auto_select_single => false },
      :host_filter                      => {:data_type => :integer, :display => :edit, :required => false, :description => "Filter",:values_from => {:method => :allowed_filters, :options => {:category => :Host}}, :auto_select_single => false },
      :placement_host_name              => {:data_type => :integer, :display => :edit, :required => true, :required_method=>:validate_placement, :description => "Name",:values_from => {:method => :allowed_hosts}, :auto_select_single => false, :required_description => "Host Name" },
      :new_datastore_create             => {:data_type => :boolean, :display => :hide, :required => false, :description => "Create Datastore",:default => false,:values  => {false => 0,true => 1}},
      :new_datastore_storage_controller => {:data_type => :string, :display => :edit, :required => false, :description => "Controller",:values_from => {:method => :allowed_datastore_storage_controller}  },
      :new_datastore_fs_type            => {:data_type => :string, :display => :hide, :required => false, :description => "FS Type",:default => "NFS",:values  => {"NFS"		=> "NFS","VMFS"    => "VMFS"}},
      :new_datastore_size               => {:data_type => :integer, :display => :hide, :required => false, :description => "Size (GB)"},
      :new_datastore_name               => {:data_type => :string, :display => :hide, :required => false, :description => "Name"},
      :new_datastore_aggregate          => {:data_type => :string, :display => :edit, :required => false, :description => "Aggregate",:values_from => {:method => :allowed_datastore_aggregate} },
      :new_datastore_volume             => {:data_type => :string, :display => :hide, :required => false, :description => "Volume",:values_from => {:method => :allowed_datastore_aggregate}  },
      :new_datastore_thin_provision     => {:data_type => :string, :display => :hide, :required => false, :description => "Thin Provision"},
      :new_datastore_autogrow           => {:data_type => :string, :display => :hide, :required => false, :description => "Autogrow",:default => false,:values => {false => 0,true => 1}},
      :new_datastore_grow_increment     => {:data_type => :integer, :display => :hide, :required => false, :description => "Grow Increment (GB)"},
      :new_datastore_max_size           => {:data_type => :integer, :display => :hide, :required => false, :description => "Max Size (GB)"},
      :ds_filter                        => {:data_type => :integer, :display => :edit, :required => false, :description => "Filter",:values_from => {:method => :allowed_filters, :options => {:category => :Storage}}, :auto_select_single => false },
      :placement_ds_name                => {:data_type => :integer, :display => :edit, :required => true, :required_method=>:validate_placement, :description => "Name",:values_from => {:method => :allowed_storages}, :auto_select_single => false,  :required_description => "Datastore Name" },
          }
        },
    :hardware => {
          :description => "Hardware",
          :display     => :show,
          :fields      => {
      :number_of_cpus     => {:data_type => :integer, :display => :edit, :required =>false, :description => "Number of CPUs",:default => 1,:values  => {1    => "1",2		=> "2",4		=> "4",8    => "8"}},
#      :number_of_sockets  => {:data_type => :integer, :display => :edit, :required =>false, :description => "Number of Sockets",:default => 1,:values  => {1    => "1",2   => "2",4    => "4",8    => "8"}},
#      :cores_per_socket   => {:data_type => :integer, :display => :edit, :required =>false, :description => "Cores per Socket",:default => 1,:values  => {1    => "1",2   => "2",4    => "4",8    => "8"}},
      :vm_memory          => {:data_type => :string, :display => :edit, :required => false, :description => "Memory (MB)",:default => "1024",:values  => {"1024"  => "1024","2048"  => "2048","4096"  => "4096",}},
      :network_adapters   => {:data_type => :integer, :display => :hide, :required => false, :description => "Network Adapters",:default => 1,:values  => {1    => "1",2		=> "2",3		=> "3",4		=> "4"}},
      :disk_format        => {:data_type => :string, :display => :edit, :required => false, :description => "Disk Format",:default => "unchanged",:values  => {"unchanged"    => "Default","thin"		=> "Thin","thick"		=> "Thick"}},
      :cpu_limit          => {:data_type => :integer, :display => :edit, :required => false, :description => "CPU (MHz)", :notes=>"(-1 = Unlimited)", :notes_display=>:show},
      :memory_limit       => {:data_type => :integer, :display => :edit, :required => false, :description => "Memory (MB)", :notes=>"(-1 = Unlimited)", :notes_display=>:show},
      :cpu_reserve        => {:data_type => :integer, :display => :edit, :required => false, :description => "CPU (MHz)"},
      :memory_reserve     => {:data_type => :integer, :display => :edit, :required => false, :description => "Memory (MB)"}
          }
        },
    :network => {
          :description => "Network",
          :display     => :show,
          :fields      => {
      :vlan            => {:data_type => :string, :display => :edit, :required => true, :description => "vLan",:values_from => {:method => :allowed_vlans, :options => {:dvs => true, :vlans => true} } },
      :mac_address     => {:data_type => :string, :display => :hide, :required => false, :description => "MAC Address"},
          }
        },
    :customize => {
          :description => "Customize",
          :display     => :show,
          :fields      => {
      :sysprep_enabled                    => {:data_type => :string, :display => :edit, :required => false, :description => "Customize", :default => "disabled",:values_from => {:method => :allowed_customization } },
      :sysprep_custom_spec                => {:data_type => :string, :display => :edit, :required => false, :description => "Name",:values_from => {:method => :allowed_customization_specs}, :auto_select_single => false },
      :sysprep_spec_override              => {:data_type => :boolean, :display => :edit, :required => false, :description => "Override Specification Values",:default => false,:values  => {false	=> 0,true    => 1}},
      :sysprep_upload_file                => {:data_type => :string, :display => :edit, :required => false, :description => "Upload"},
      :sysprep_upload_text                => {:data_type => :string, :display => :edit, :required => true, :required_method=>:validate_sysprep_upload, :description => "Sysprep Text"},
      :sysprep_timezone                   => {:data_type => :string, :display => :edit, :required => true, :required_method=>:validate_sysprep_field, :description => "Timezone",:values_from => {:method => :get_timezones } },
      :sysprep_auto_logon                 => {:data_type => :boolean, :display => :edit, :required => false, :description => "Auto Logon",:default => true,:values  => {false	=> 0,true    => 1}},
      :sysprep_auto_logon_count           => {:data_type => :integer, :display => :edit, :required => false, :description => "Auto Logon Count",:default => 1,:values  => {1    => "1",2		=> "2",3		=> "3"}},
      :sysprep_password                   => {:data_type => :string, :display => :edit, :required => false, :description => "New Administrator Password"},
      :sysprep_identification             => {:data_type => :string, :display => :edit, :required => false, :description => "Identification",:default => "domain",:values  => {"workgroup"    => "Workgroup","domain"				=> "Domain"}},
      :sysprep_workgroup_name             => {:data_type => :string, :display => :edit, :required => false, :description => "Workgroup Name", :default => "WORKGROUP"},
      #:sysprep_domain_name               => {:data_type => :string, :display => :edit, :required => false, :description => "Domain Name"},
      :sysprep_domain_name                => {:data_type => :string, :display => :edit, :required => false, :description => "Domain Name",:values_from => {:method => :allowed_domains, :options => {:platform => nil, :active_proxy=> nil}}, :auto_select_single => false },
      :ldap_ous                           => {:data_type => :string, :display => :edit, :required => false, :description => "LDAP Group",:values_from => {:method => :allowed_ous_tree}, :auto_select_single => false },
      :sysprep_domain_admin               => {:data_type => :string, :display => :edit, :required => false, :description => "Domain Admin"},
      :sysprep_domain_password            => {:data_type => :string, :display => :edit, :required => false, :description => "Domain Password"},
      :sysprep_full_name                  => {:data_type => :string, :display => :edit, :required => true, :required_method=>:validate_sysprep_field, :description => "Full Name"},
      :sysprep_organization               => {:data_type => :string, :display => :edit, :required => true, :required_method=>:validate_sysprep_field, :description => "Organization"},
      :sysprep_product_id                 => {:data_type => :string, :display => :edit, :required => true, :required_method=>:validate_sysprep_field, :description => "ProductID"},
      :sysprep_computer_name              => {:data_type => :string, :display => :edit, :required => false, :description => "Computer Name"},
      :sysprep_change_sid                 => {:data_type => :boolean, :display => :edit, :required => false, :description => "Change SID",:default => true,:values  => {false		=> 0,true    => 1}},
      :sysprep_delete_accounts            => {:data_type => :boolean, :display => :hide, :display_override=>:hide, :required => false, :description => "Delete Accounts",:default => false,:values  => {false		=> 0,true    => 1}},
      :sysprep_server_license_mode        => {:data_type => :string, :display => :edit, :required => false, :description => "Identification",:default => "perServer",:values  => {"perSeat"    => "Per seat","perServer"	=> "Per server"}},
      :sysprep_per_server_max_connections => {:data_type => :string, :display => :edit, :required => false, :description => "Maximum Connections", :default => "5"},
      :linux_host_name                    => {:data_type => :string, :display => :edit, :required => false, :description => "Computer Name"},
      :linux_domain_name                  => {:data_type => :string, :display => :edit, :required => false, :description => "Domain Name"},
      :addr_mode                          => {:data_type => :string, :display => :edit, :required => false, :description => "Address Mode",:default => "dhcp",:values  => {"dhcp"    => "DHCP","static"  => "Static"}},
      :ip_addr                            => {:data_type => :string, :display => :edit, :required => false, :description => "IP Address",:notes=>"(Enter starting IP address)", :notes_display=>:hide},
      :subnet_mask                        => {:data_type => :string, :display => :edit, :required => false, :description => "Subnet Mask"},
      :gateway                            => {:data_type => :string, :display => :edit, :required => false, :description => "Gateway"},
      :dns_servers                        => {:data_type => :string, :display => :edit, :required => false, :description => "DNS Server list"},
      :dns_suffixes                       => {:data_type => :string, :display => :edit, :required => false, :description => "DNS Suffix List"},
      :wins_servers                       => {:data_type => :string, :display => :edit, :required => false, :description => "WINS Server list"}
          }
        },
    :schedule => {
          :description => "Schedule",
          :display     => :show,
          :fields      => {
      :schedule_type   => {:data_type => :string, :display => :edit, :required => false, :description => "When to Provision",:default => "immediately",:values  => {"immediately"    => "Immediately on Approval","schedule"				=> "Schedule"}},
      :schedule_time   => {:data_type => :time, :display => :edit, :required => false, :description => "Provision on",:values_from => {:method => :default_schedule_time, :options => {:offset => 86400}} },
      :vm_auto_start   => {:data_type => :boolean, :display => :edit, :required => false, :description => "Power on virtual machines after creation",:default => false,:values  => {false		=> 0,true    => 1}},
      :retirement      => {:data_type => :integer,:display => :edit, :required => false, :description => "Time until Retirement",:default => 0,:values  => {0 => "Indefinite",1.month.to_i  => "1 Month",3.months.to_i => "3 Months",6.months.to_i => "6 Months"}},
      :retirement_warn => {:data_type => :integer,:display => :edit, :required => true, :description => "Retirement Warning",:default => 1.week.to_i,:values_from => {:method => :values_less_then, :options => {:field => :retirement, :include_equals => false,:values => {1.week.to_i  => "1 Week",2.weeks.to_i => "2 Weeks",30.days.to_i => "30 Days"}}},
            },
          }
        }
      }
    }
  end
end

