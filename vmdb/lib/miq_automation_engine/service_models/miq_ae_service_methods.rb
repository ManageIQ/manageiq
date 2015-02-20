$:.push("#{File.dirname(__FILE__)}/../../../../lib/ServiceNowWebService")
$:.push("#{File.dirname(__FILE__)}/../../../../lib/RcuWebService")

#####################################################
# This is for $evm.execute from an Automate method
#####################################################
module MiqAeMethodService
  class MiqAeServiceMethods
    include DRbUndumped

    SYNCHRONOUS = Rails.env.test?

    def self.send_email(to, from, subject, body, content_type = nil)
      ar_method do
        meth = SYNCHRONOUS ? :deliver : :deliver_queue
        options = {
          :to           => to,
          :from         => from,
          :subject      => subject,
          :content_type => content_type,
          :body         => body
        }
        GenericMailer.send(meth, :automation_notification, options)
        true
      end
    end

    def self.snmp_trap_v1(inputs)
      ar_method do
        if SYNCHRONOUS
          MiqSnmp.trap_v1(inputs)
        else
          MiqQueue.put(
            :class_name  => "MiqSnmp",
            :method_name => "trap_v1",
            :args        => [inputs],
            :role        => "notifier",
            :zone        => nil
          )
        end
        true
      end
    end

    def self.snmp_trap_v2(inputs)
      ar_method do
        if SYNCHRONOUS
          MiqSnmp.trap_v2(inputs)
        else
          MiqQueue.put(
            :class_name  => "MiqSnmp",
            :method_name => "trap_v2",
            :args        => [inputs],
            :role        => "notifier",
            :zone        => nil
          )
        end
        true
      end
    end

    def self.vm_templates
      ar_method do
        condition = ["template = ? AND vendor = 'vmware' AND ems_id is not NULL", true]
        #vms = Rbac.search(:class => Vm, :conditions => condition, :results_format => :objects, :userid => @userid).first
        vms = VmOrTemplate.find(:all, :conditions => condition)
        MiqAeServiceModelBase.wrap_results(vms)
      end
    end

    def self.active_miq_proxies
      ar_method do
        proxies = MiqProxy.all.collect { |p| p.is_active? ? p : nil }.compact
        MiqAeServiceModelBase.wrap_results(proxies)
      end
    end

    def self.category_exists?(category)
      cat = Classification.find_by_name(category)
      cat.nil? ? false : true
    end

    def self.category_create(options={})
      ar_options = {}
      options.each { |k, v| ar_options[k.to_sym] = v if Classification.column_names.include?(k.to_s) || k.to_s == 'name' }
      cat = Classification.create_category!(ar_options)
      true
    end

    def self.tag_exists?(category, entry)
      cat = Classification.find_by_name(category)
      return false if cat.nil?
      ent = cat.find_entry_by_name(entry)
      ent.nil? ? false : true
    end

    def self.tag_create(category, options={})
      cat = Classification.find_by_name(category)
      raise "Category <#{category}> does not exist" if cat.nil?

      ar_options = {}
      options.each { |k, v| ar_options[k.to_sym] = v if Classification.column_names.include?(k.to_s) || k.to_s == 'name' }
      entry = cat.add_entry(ar_options)
      true
    end

    def self.netapp_create_datastore(netapp_address, netapp_userid, netapp_password, container, aggregate_or_volume_name, datastore_name, size, protocol = 'NFS', thin_provision = false, auto_grow = false)
      log_header = "MIQAE(MiqAeServiceMethods.netapp_create_datastore)"
      container_dictionary = {
        'MiqAeMethodService::MiqAeServiceHost'       => { :moref => 'HostSystem', :ems => 'ext_management_system' },
        'MiqAeMethodService::MiqAeServiceEmsCluster' => { :moref => 'ClusterComputeResource',    :ems => 'ext_management_system' },
        # 'MiqAeServiceEmsDatacenter' => 'Datacenter'
      }

      begin
        require 'RcuClientBase'

        raise "Container not provided" if container.nil?
        raise "Container class=<#{container.class.name}> should be one of: #{container_dictionary.keys.sort.join(',')}" unless container_dictionary.keys.include?(container.class.name)
        ems = container.send(container_dictionary[container.class.name][:ems])
        raise "Container <#{container.name}> not connected to vCenter" if ems.nil?

        # Get VC information from ems and create an RcuClientBase object
        vc_address  = ems.ipaddress
        vc_userid   = ems.authentication_userid
        vc_password = ems.authentication_password
        $log.info("#{log_header} Connecting to VC=<#{vc_address}> with username=<#{vc_userid}>")
        rcu = RcuClientBase.new(vc_address, vc_userid, vc_password)
        rcu.receiveTimeout = 600
        # Figure out the target's Managed Object Reference
        targetMor = rcu.getMoref(container.name, container_dictionary[container.class.name][:moref])

        # Convert the size (in bytes) to size_in_megabytes (round up to the nearest gigabyte)
        size_in_gigabytes, remainder = size.divmod(1.gigabyte)
        size_in_gigabytes           += 1         if remainder > 0
        size_in_megabytes            = size_in_gigabytes * 1.kilobyte

        # Create the parameters needed for the rcu.createDatastore methods
        datastoreSpec = RcuHash.new("DatastoreSpec") do |ds|
          # RCU
          #ds.aggrOrVolName  = aggregate_or_volume_name
          # VSC
          ds.containerName  = aggregate_or_volume_name
          ds.controller   = RcuHash.new("ControllerSpec") do |cs|
            cs.ipAddress = netapp_address
            cs.username  = netapp_userid
            cs.password  = MiqAePassword.decrypt_if_password(netapp_password)
            cs.ssl       = false
          end
          ds.datastoreNames = datastore_name
          ds.numDatastores  = 1
          ds.protocol       = protocol
          ds.sizeInMB       = size_in_megabytes
          ds.targetMor      = targetMor
          ds.thinProvision  = thin_provision
          ds.volAutoGrow    = auto_grow
        end

        $log.info("#{log_header} Creating #{protocol} containerName=<#{aggregate_or_volume_name}> with size=<#{size}> as datastore=<#{datastore_name}> on NetApp Filer=<#{netapp_address}> with username=<#{netapp_userid}>")
        $log.info("#{log_header} rcu.createDatastore parameters: ds.containerName=<#{datastoreSpec.containerName}>, ds.datastoreNames=<#{datastoreSpec.datastoreNames}>, ds.numDatastores=<#{datastoreSpec.numDatastores}>, ds.protocol=<#{datastoreSpec.protocol}>, ds.sizeInMB=<#{datastoreSpec.sizeInMB}>, ds.targetMor=<#{datastoreSpec.targetMor}>, ds.thinProvision=<#{datastoreSpec.thinProvision}>, ds.volAutoGrow=<#{datastoreSpec.volAutoGrow}>")
        rv = rcu.createDatastore(datastoreSpec)
        $log.info("#{log_header} Return Value=<#{rv}> of class=<#{rv.class.name}>")
        return rv
      rescue Handsoap::Fault => hserr
        $log.error "#{log_header} Handsoap::Fault { :code => '#{hserr.code}', :reason => '#{hserr.reason}', :details => '#{hserr.details.inspect}' }"
        $log.error hserr.backtrace.join("\n")
        raise
      rescue => err
        $log.error "#{log_header} #{err}"
        $log.error err.backtrace.join("\n")
        raise
      end

    end

    def self.netapp_destroy_datastore(netapp_address, netapp_userid, netapp_password, datastore)
      log_header = "MIQAE(MiqAeServiceMethods.netapp_destroy_datastore)"
      begin
        require 'RcuClientBase'

        raise "Datastore not provided" if datastore.nil?
        raise "Datastore <#{datastore.name}> not connected to vCenter" if datastore.ext_management_systems.empty?

        ems = datastore.ext_management_systems.first
        vc_address  = ems.ipaddress
        vc_userid   = ems.authentication_userid
        vc_password = ems.authentication_password
        $log.info("#{log_header} Connecting to VC=<#{vc_address}> with username=<#{vc_userid}>")
        rcu = RcuClientBase.new(vc_address, vc_userid, vc_password)

        dsMor = rcu.getMoref(datastore.name, "Datastore")

        datastoreSpec = RcuHash.new("DatastoreSpec") do |ds|
          ds.controller   = RcuHash.new("ControllerSpec") do |cs|
            cs.ipAddress = netapp_address
            cs.username  = netapp_userid
            cs.password  = MiqAePassword.decrypt_if_password(netapp_password)
            cs.ssl       = false
          end
          ds.mor        = dsMor
        end

        $log.info("#{log_header} Destroying datastore=<#{datastore.name}> with MOR=<#{dsMor}> on NetApp Filer=<#{netapp_address}> with username=<#{netapp_userid}>")
        rv = rcu.destroyDatastore(datastoreSpec)
        $log.info("#{log_header} Return Value=<#{rv}> of class=<#{rv.class.name}>")
        return rv
      rescue Handsoap::Fault => hserr
        $log.error "#{log_header} Handsoap::Fault { :code => '#{hserr.code}', :reason => '#{hserr.reason}', :details => '#{hserr.details.inspect}' }"
        $log.error hserr.backtrace.join("\n")
        raise
      rescue => err
        $log.error "#{log_header} #{err}"
        $log.error err.backtrace.join("\n")
        raise
      end

    end

    def self.service_now_eccq_insert(server, username, password, agent, queue, topic, name, source, *params)
      log_header = "MIQAE(MiqAeServiceMethods.service_now_eccq_insert)"
      begin
        require 'SnEccqClientBase'
        service_now_drb_undumped

        payload = params.empty? ? {} : Hash[*params]
        password = MiqAePassword.decrypt_if_password(password)

        $log.info("#{log_header} Connecting to host=<#{server}> with username=<#{username}>")
        sn = SnEccqClientBase.new(server, username, password)
        $log.info("#{log_header} Inserting agent=<#{agent}>, queue=<#{queue}>, topic=<#{topic}>, name=<#{name}>, source=<#{source}>, payload=<#{payload.inspect}>")
        rv = sn.insert(agent, queue, topic, name, source, payload)
        $log.info("#{log_header} Return Value=<#{sn.dumpObj(rv)}>")
        return rv
      rescue Handsoap::Fault => hserr
        $log.error "#{log_header} Handsoap::Fault { :code => '#{hserr.code}', :reason => '#{hserr.reason}', :details => '#{hserr.details.inspect}' }"
        $log.error hserr.backtrace.join("\n")
        raise
      rescue => err
        $log.error "#{log_header} #{err}"
        $log.error err.backtrace.join("\n")
        raise
      end
    end

    def self.service_now_task_get_records(server, username, password, *params)
      self.service_now_task_service('getRecords', server, username, password, *params)
    end

    def self.service_now_task_update(server, username, password, *params)
      self.service_now_task_service('update', server, username, password, *params)
    end

    def self.create_provision_request(*args)
      # Need to add the username into the array of params
      #TODO: This code should pass a real username, similar to how the web-service
      #      passes the name of the user that logged into the web-service.
      args.insert(1, "admin") if args.kind_of?(Array)
      MiqAeServiceModelBase.wrap_results(MiqProvisionVirtWorkflow.from_ws(*args))
    end

    private

    def self.service_now_drb_undumped
      log_header = "MIQAE(MiqAeServiceMethods.service_now_drb_undumped)"
      $log.info "#{log_header} Entered"
      [SnsHash, SnsArray].each { |klass| drb_undumped(klass) }
    end

    def self.drb_undumped(klass)
      log_header = "MIQAE(MiqAeServiceMethods.drb_undumped)"
      $log.info "#{log_header} Entered: klass=#{klass.name}"
      klass.send(:include, DRbUndumped) unless klass.ancestors.include?(DRbUndumped)
    end

    def self.ar_method
      begin
        yield
      rescue Exception => err
        $miq_ae_logger.error("MiqAeServiceMethods.ar_method raised: <#{err.class}>: <#{err.message}>")
        $miq_ae_logger.error(err.backtrace.join("\n"))
        raise
      ensure
        ActiveRecord::Base.connection_pool.release_connection rescue nil
      end
    end

    def self.service_now_task_service(service, server, username, password, *params)
      log_prefix = "MIQAE(MiqAeServiceMethods.service_now_task_#{service.underscore})"
      begin
        require 'SnSctaskClientBase'
        service_now_drb_undumped

        payload = params.empty? ? {} : Hash[*params]
        password = MiqAePassword.decrypt_if_password(password)

        $log.info("#{log_prefix} Connecting to host=<#{server}> with username=<#{username}>")
        sn = SnSctaskClientBase.new(server, username, password)
        $log.info("#{log_prefix} Updating with params=<#{payload.inspect}>")
        rv = sn.send(service, payload)
        $log.info("#{log_prefix} Return Value=<#{sn.dumpObj(rv)}>")
        return rv
      rescue Handsoap::Fault => hserr
        $log.error "#{log_prefix} Handsoap::Fault { :code => '#{hserr.code}', :reason => '#{hserr.reason}', :details => '#{hserr.details.inspect}' }"
        $log.error hserr.backtrace.join("\n")
        raise
      rescue => err
        $log.error "#{log_prefix} #{err}"
        $log.error err.backtrace.join("\n")
        raise
      end
    end

  end
end
