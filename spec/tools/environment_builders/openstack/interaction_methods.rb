module Openstack
  module InteractionMethods
    def find_all(collection, lookup_pairs)
      # TODO(lsmola) hm not comparing nested hashes, e.g. needed for
      # firewall rules. so rule = {:nested => {}} is considered the same
      # as rule = {:nested => {:ip_addr => something}}.
      # First step, write unit tests, second step, fix this :-)
      puts "Finding #{lookup_pairs} in #{collection.class.name}"
      collection.select do |i|
        lookup_pairs.all? do |k, v|
          if i.kind_of?(Hash)
            i[k.to_s] == v
          else
            if v.kind_of?(Hash)
              h = i.send(k)
              v.all? { |key, value| h[key] == value || h[key.to_s] == value }
            else
              i.send(k) == v
            end
          end
        end
      end
    end

    def find(collection, lookup_pairs)
      find_all(collection, lookup_pairs).first
    end

    def create(collection, attributes, method = :create)
      puts "Creating #{attributes} against #{collection.class.name}"
      case attributes
      when Hash   then collection.send(method, attributes)
      when Array  then collection.send(method, *attributes)
      end
    end

    def find_or_create(collection, attributes)
      lookup_pairs = attributes.slice(:name)
      lookup_pairs = attributes.slice(:stack_name) if lookup_pairs.blank?
      # By default look by name, if name is not available, look by whole Hash
      obj = lookup_pairs.blank? ? find(collection, attributes) : find(collection, lookup_pairs)
      obj || begin
        new_obj = create(collection, attributes)
        yield new_obj if block_given?
        new_obj
      end
    end

    def find_or_create_server(collection, attributes)
      find_or_create(collection, attributes) do |server|
        wait_for_server_to_start(server)
      end
    end
  end
end
