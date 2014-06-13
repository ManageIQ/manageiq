module MiqAeMethodService
  class MiqAeServiceEmsFolder < MiqAeServiceModelBase
    expose :hosts, :association => true
    expose :vms,   :association => true

    def register_host(host)
      ar_method do
        MiqQueue.put(
          :class_name   => @object.class.name,
          :instance_id  => @object.id,
          :method_name  => "register_host",
          :zone         => @object.my_zone,
          :role         => "ems_operations",
          :args         => [host.id]
        )
        true
      end
    end

    # default options:
    #  :exclude_root_folder => false
    #  :exclude_non_display_folders => false
    def folder_path(*options)
      object_send(:folder_path, *options)
    end

  end
end
