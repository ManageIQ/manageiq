# Inspired by http://stackoverflow.com/questions/1766741/comparing-ruby-hashes/7178108#7178108

module Vmdb
  class Settings
    class HashDiffer
      class MissingKey; end

      def self.changes(h1, h2)
        diff_to_deltas(diff(h1, h2))
      end

      def self.diff(h1, h2)
        keys = (h1.keys + h2.keys).uniq
        keys.each_with_object({}) do |k, result|
          v1 = h1.key?(k) ? h1[k] : MissingKey
          v2 = h2.key?(k) ? h2[k] : MissingKey
          next if v1 == v2

          child =
            if v1.kind_of?(Hash) && v2.kind_of?(Hash)
              diff(v1, v2)
            else
              v2
            end

          result[k] = child if child != MissingKey
        end
      end

      def self.diff_to_deltas(diff, key_path = "")
        diff.flat_map do |k, v|
          new_key_path = [key_path, k].join("/")
          case v
          when Hash
            diff_to_deltas(v, new_key_path)
          else
            {:key => new_key_path, :value => v}
          end
        end.compact
      end
    end
  end
end
