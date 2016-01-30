module Openstack
  module RefreshSpecMatchers
    ##
    # Compares list of objects to list of hashes. Method internally builds list of hashes with the
    # same indexes and computes difference
    #
    # If the list of hashes have different indexes than the methods of the objects, specify the
    # the third parameter. E.g. {:index => method_name}, you can specify only indexes, that are different
    #
    # If the list of hashes have different values than in the input, e.g. for neutron ManageIQ renames
    # ingress/egress to inbound/outbound, we can list it in the dictionary. Translate from test data
    # to value in object. SO if test data has 'ingress' and object 'inboud', we send fourth parameter
    # {'ingress' => 'inboud'}. List all values from your test data you need. You can scope it by key too
    # {:direction => {'ingress' => 'inboud'}
    #
    # Another use of data is to use decorator on a key and value. {:key => -> (a) {a*a} }. Same decorator
    # that is used in Refresh parser code, should be used here.
    #
    # If some attributes are not modelled on ManagaIQ side, we can ommit them from comparing. Though
    # in ideal world this should not happen. ManageIQ should model all attributes.
    def comparable_objects_with_hashes(real_objects, expected_data, key_translate_table = {},
                                       value_translate_table = {}, key_blacklist = [])
      # Select all used keys in the data, without keys for internal references, starting with __
      all_keys = expected_data.map { |x| x.keys.select { |key| !(key =~ /^__.*/) && !key_blacklist.include?(key) } }
      all_keys = all_keys.compact.flatten.uniq

      [prepare_real_data(real_objects, all_keys, key_translate_table),
       prepare_expected_data(expected_data, all_keys, value_translate_table)]
    end

    def assert_objects_with_hashes(real_objects, expected_data, key_translate_table = {}, value_translate_table = {},
                                   key_blacklist = [])
      # Comparing to [] so we can actually see the diff in test fail
      comparable_hashes = comparable_objects_with_hashes(real_objects,
                                                         expected_data,
                                                         key_translate_table,
                                                         value_translate_table,
                                                         key_blacklist)
      expect(comparable_hashes[0]).to match_array(comparable_hashes[1])
    end

    private

    def prepare_real_data(real_objects, all_keys, key_translate_table = {})
      # This method prepares consistent data, so all hashes contains all keys
      real_objects.map do |real_object|
        # Fill all data with all keys, setting nil values to not specified keys in Builder's Data
        all_keys.each_with_object({}) do |key, object|
          method_name = key_translate_table.fetch_path(key) || key
          value = real_object.send(method_name)
          # Set all strings to downcase, for easier comparing
          value = value.downcase if value.respond_to?(:downcase)
          object[key] = value
        end
      end
    end

    def prepare_expected_data(expected_data, all_keys, value_translate_table = {})
      # This method prepares consistent data, so all hashes contains all keys
      expected_data.map do |expected|
        # Fill all data with all keys, setting nil values to not specified keys in Builder's Data
        all_keys.each_with_object({}) do |key, object|
          value = expected.fetch_path(key)
          # Set all strings to downcase, for easier comparing
          value = value.downcase if value.respond_to?(:downcase)
          # Translate value if available
          if (decorator = value_translate_table[key]).kind_of?(Proc)
            value = decorator.call(value)
          else
            value = value_translate_table.fetch_path(key, value) || value_translate_table.fetch_path(value) || value
          end
          object[key] = value
        end
      end
    end
  end
end
