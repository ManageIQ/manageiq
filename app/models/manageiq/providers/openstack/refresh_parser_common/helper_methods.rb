module ManageIQ::Providers
  module Openstack
    module RefreshParserCommon
      module HelperMethods
        def uniques(collection)
          unique_objs = []
          # caling uniq on a fog collection makes it lose
          # properties from fog that it will attempt to use
          # during iteration, resulting in an exeption.
          # to avoid that, turn it into an array first.
          unique_objs.concat(collection)
          # uniquify via identity if these are fog objects
          unique_objs.uniq!(&:identity) if (unique_objs.size > 0 && unique_objs[0].respond_to?(:identity))
          unique_objs
        end

        def process_collection(collection, key, &block)
          @data[key] ||= []
          return if @options && @options[:inventory_ignore] && @options[:inventory_ignore].include?(key)
          # safe_call catches and ignores all Fog relation calls inside processing, causing allowed excon errors
          collection.each { |item| safe_call { process_collection_item(item, key, &block) } }
        end

        def process_collection_item(item, key)
          @data[key] ||= []

          uid, new_result = yield(item)

          @data[key] << new_result
          @data_index.store_path(key, uid, new_result)
          new_result
        end

        def safe_call
          # Safe call wrapper for any Fog call not going through handled_list
          yield
        rescue Excon::Errors::Forbidden => err
          # It can happen user doesn't have rights to read some tenant, in that case log warning but continue refresh
          _log.warn "Forbidden response code returned in provider: #{@os_handle.address}. Message=#{err.message}"
          _log.warn err.backtrace.join("\n")
          nil
        rescue Excon::Errors::Unauthorized => err
          # It can happen user doesn't have rights to read some tenant, in that case log warning but continue refresh
          _log.warn "Unauthorized response code returned in provider: #{@os_handle.address}. Message=#{err.message}"
          _log.warn err.backtrace.join("\n")
          nil
        rescue Excon::Errors::NotFound, Fog::Errors::NotFound => err
          # It can happen that some data do not exist anymore,, in that case log warning but continue refresh
          _log.warn "Not Found response code returned in provider: #{@os_handle.address}. Message=#{err.message}"
          _log.warn err.backtrace.join("\n")
          nil
        end

        alias safe_get safe_call

        def safe_list(&block)
          safe_call(&block) || []
        end
      end
    end
  end
end
