module ManageIQ::Providers::Openstack
  module RefreshParserCommon
    module Flavors
      def get_flavors
        flavors = if @ems.kind_of?(ManageIQ::Providers::Openstack::CloudManager) && ::Settings.ems.ems_openstack.refresh.is_admin
                    @connection.handled_list(:flavors, {'is_public' => 'None'}, true)
                  else
                    @connection.handled_list(:flavors)
                  end
        flavors = uniques(flavors)
        process_collection(flavors, :flavors) { |flavor| parse_flavor(flavor) }
      end

      def get_private_flavor(id)
        private_flavor = safe_get { @connection.flavors.get(id) }
        process_collection([private_flavor], :flavors) { |flavor| parse_flavor(flavor) } if private_flavor
      end

      def parse_flavor(flavor)
        uid = flavor.id

        new_result = {
          :type                 => "ManageIQ::Providers::Openstack::CloudManager::Flavor",
          :ems_ref              => uid,
          :name                 => flavor.name,
          :enabled              => !flavor.disabled,
          :cpus                 => flavor.vcpus,
          :memory               => flavor.ram.megabytes,
          :root_disk_size       => flavor.disk.to_i.gigabytes,
          :swap_disk_size       => flavor.swap.to_i.megabytes,
          :publicly_available   => flavor.is_public,
          :ephemeral_disk_size  => flavor.ephemeral.nil? ? nil : flavor.ephemeral.to_i.gigabytes,
          :ephemeral_disk_count => if flavor.ephemeral.nil?
                                     nil
                                   elsif flavor.ephemeral.to_i > 0
                                     1
                                   else
                                     0
                                   end,
          :cloud_tenants        => flavor_tenants(flavor)
        }
        return uid, new_result
      end

      def flavor_tenants(flavor)
        if flavor.is_public
          # For public flavor, we will fill a relation to all tenants.
          # Calling access list api for public flavor throws 403
          @data.fetch_path(:cloud_tenants)
        else
          tenants = []
          # Add tenants with access to the private flavor
          unparsed_tenants = safe_list { @connection.list_tenants_with_flavor_access(flavor.id) }
          flavor_access = unparsed_tenants.try(:data).try(:[], :body).try(:[], "flavor_access") || []
          unless flavor_access.blank?
            tenants += flavor_access.map { |x| @data_index.fetch_path(:cloud_tenants, x['tenant_id']) }
          end
          tenants
        end
      end
    end
  end
end
