module ManageIQ::Providers::Google::RefreshHelperMethods
  extend ActiveSupport::Concern

  def process_collection(collection, key, store_in_data = true)
    @data[key]       ||= [] if store_in_data
    @data_index[key] ||= {}

    collection.each do |item|
      # uid, new_result = yield(item)
      result = yield(item)
      next if result.nil?
      # It's possible we either got back an array like [uid, result] or an array
      # of such results (e.g. [[uid1, result1], [uid2, result2]])
      if result.first.kind_of?(Array)
        result.each { |x| process_item(key, x.first, x.second) }
      else
        process_item(key, result.first, result.second, store_in_data)
      end
    end
  end

  def process_item(key, uid, result, store_in_data = true)
    return if uid.nil?

    @data[key] << result if store_in_data
    @data_index.store_path(key, uid, result)
  end

  def parse_uid_from_url(url)
    # A lot of attributes in gce are full URLs with the
    # uid being the last component.  This helper method
    # returns the last component of the url
    uid = url.split('/')[-1]
    uid
  end

  module ClassMethods
    def ems_inv_to_hashes(ems, options = nil)
      new(ems, options).ems_inv_to_hashes
    end
  end
end
