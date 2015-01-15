require 'aws-sdk'

class MiqEc2
  @@bucket_cache = {}
  @@bucket_cache_timeout = {}

  def self.retrieve_bucket(key_id, secret_key, name, options = {})
    # Invalidate the bucket cache
    ts = @@bucket_cache_timeout[name]
    if ts && ts < Time.now
      @@bucket_cache_timeout.delete(name)
      @@bucket_cache.delete(name)
    end

    return @@bucket_cache[name] if @@bucket_cache.has_key?(name)

    s3 = AWS::S3.new(:access_key_id => key_id, :secret_access_key => secret_key)
    bucket = s3.buckets[name]
    return nil if bucket.nil?

    @@bucket_cache[name]         = bucket
    @@bucket_cache_timeout[name] = Time.now + 900
    return bucket
  end

  def self.retrieve_scan_metadata(key_id, secret_key, ami_location, categories)
    categories = [categories] unless categories.is_a?(Array)

    # XXX: Hardcoded timestamp for demo purposes
    options = {:prefix => "TS:2012-08-22T03:24:32.691757"}

    bucket = self.retrieve_bucket(key_id, secret_key, 'miq-extract', options)
    return if bucket.nil?

    # Find the latest timestamp for this ami_location, and get the xml data there
    objs = bucket.objects.find_all { |o| o.key =~ /\/#{ami_location.gsub('/', '-')}\// }.sort_by(&:key)
    return if objs.empty?

    error_obj = objs.find { |o| o.key[-5..-1] == "ERROR" }
    raise error_obj.read unless error_obj.nil?

    objs_ts = objs.last.key.split('/')[0]
    objs = categories.collect do |c|
      obj = objs.detect { |o| o.key =~ /^#{objs_ts}.+#{c}\.xml$/ }
      obj ? obj.read : nil
    end

    return objs
  end
end
