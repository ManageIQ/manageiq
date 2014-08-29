module MiqAeEngine
  class MiqAeUri
    def self.hash2query(hash)
      return nil if hash.blank?

      query = Array.new
      hash.keys.sort { |a,b| a.to_s <=> b.to_s }.each do |k|
        v = hash[k]
        next if v.nil?
        value = v.kind_of?(ActiveRecord::Base) ? v.id : v
        query.push([ERB::Util.url_encode(k), ERB::Util.url_encode(value.to_s)].join('='))
      end
      query.join('&')
    end

    def self.query2hash(query)
      hash = Hash.new
      unless query.nil?
        query.split('&').each {|a|
          k, v = a.split('=')
          hash[URI.unescape(k)] = URI.unescape(v.to_s)
        }
      end
      return hash
    end

    def self.split(uri, default_scheme = 'miqaews')
      scheme, userinfo, host, port, registry, path, opaque, query, fragment = URI.split(uri)
      scheme = default_scheme if scheme.nil?
      scheme = 'miqaews' if scheme.downcase == 'miqae'
      scheme.downcase!
      return scheme, userinfo, host, port, registry, path, opaque, query, fragment
    rescue URI::Error => err
      raise MiqAeException::InvalidPathFormat, err.message
    end

    def self.scheme_supported?(scheme)
      ['miqae', 'miqaedb', 'miqaews', 'miqaemethod', 'method', 'miqpeca'].include?(scheme.downcase)
    end

    def self.replace(uri, options={})
      original = {}
      original[:scheme], original[:userinfo], original[:host], original[:port], original[:registry], original[:path], original[:opaque], original[:query], original[:fragment] = URI.split(uri)
      original.merge!(options)
      URI::HTTP.new(original[:scheme], original[:userinfo], original[:host], original[:port], original[:registry], original[:path], original[:opaque], original[:query], original[:fragment]).to_s
    end

    def self.join(scheme, userinfo, host, port, registry, path, opaque, query, fragment)
      query = hash2query(query) if query.kind_of?(Hash)
      URI::HTTP.new(scheme, userinfo, host, port, registry, path, opaque, query, fragment).to_s
    end

    def self.path(uri, default_scheme = 'miqaews')
      _, _, _, _, _, path, _, _, _ = split(uri, default_scheme)
      path
    end
  end
end
