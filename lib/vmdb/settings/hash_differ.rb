# Inspired by http://stackoverflow.com/questions/1766741/comparing-ruby-hashes/7178108#7178108

module Vmdb
  class Settings
    class HashDiffer
      class MissingKey; end

      def self.changes(before, after)
        diff_to_deltas(diff_hashes(before, after))
      end

      def self.diff_hashes(before, after)
        (before.keys + after.keys).uniq.each_with_object({}) do |key, result|
          unless before.key?(key) && after.key?(key) && before[key] == after[key]
            if before[key].kind_of?(Hash) && after[key].kind_of?(Hash)
              result[key] = diff_hashes(before[key], after[key])
            else
              value_before = before.key?(key) ? before[key] : MissingKey
              value_after  = after.key?(key)  ? after[key]  : MissingKey
              result[key] = [value_before, value_after]
            end
          end
        end
      end

      private_class_method def self.diff_to_deltas(diff, key_path = "")
        diff.flat_map do |key, values|
          new_key_path = [key_path, key].join("/")
          case values
          when Hash
            diff_to_deltas(values, new_key_path)
          else
            value = values.last
            {:key => new_key_path, :value => value} unless value == MissingKey
          end
        end.compact
      end
    end
  end
end
