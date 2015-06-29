module AWS
  module S3
    class Bucket < Base
      MAX_KEYS = 1000

      class << self
        # Fetches the bucket named <tt>name</tt>.
        #
        #   Bucket.find('jukebox')
        #
        # If a default bucket is inferable from the current connection's subdomain, or if set explicitly with Base.set_current_bucket,
        # it will be used if no bucket is specified.
        #
        #   MusicBucket.current_bucket
        #   => 'jukebox'
        #   MusicBucket.find.name
        #   => 'jukebox'
        #
        # By default the first Bucket::MAX_KEYS objects contained in the bucket will be returned (sans their data) along with the bucket.
        # You can access your objects using the Bucket#objects method.
        #
        #   Bucket.find('jukebox').objects
        #
        # There are several options which allow you to limit which objects are retrieved. The list of object filtering options
        # are listed in the documentation for Bucket.objects.
        def find(name = nil, options = {})
          opts = options.dup
          max = opts[:max_keys]
          multi_get = !max.nil? && (max == :all || max > MAX_KEYS)

          opts[:max_keys] = 0 if multi_get
          bucket = new(get(path(name, opts)).bucket)

          if multi_get
            max = MAX_KEYS if max.nil?
            loop do
              opts[:max_keys] = (max == :all ? MAX_KEYS : max)

              objs = new(get(path(name, opts)).bucket).object_cache
              break if objs.empty?
              objs.each { |obj| bucket.send(:add, obj) }

              unless max == :all
                max -= objs.length
                break if max <= 0
              end

              opts[:marker] = objs[-1].key
            end
          end

          return bucket
        end

        # Return just the objects in the bucket named <tt>name</tt>.
        #
        # By default the first Bucket::MAX_KEYS objects of the named bucket will be returned. There are options, though, for filtering
        # which objects are returned.
        #
        # === Object filtering options
        #
        # * <tt>:max_keys</tt> - The maximum number of keys you'd like to see in the response body.
        #   The server may return fewer than this many keys, but will not return more.
        #   You can pass :all if you would like to return all objects.
        #
        #     Bucket.objects('jukebox').size
        #     # => 3
        #     Bucket.objects('jukebox', :max_keys => 1).size
        #     # => 1
        #     Bucket.objects('jukebox', :max_keys => :all).size
        #     # => 3
        #
        #     Bucket.objects('huge_jukebox').size
        #     # => 1000
        #     Bucket.objects('huge_jukebox', :max_keys => 2000).size
        #     # => 2000
        #     Bucket.objects('huge_jukebox', :max_keys => :all).size
        #     # => 10000
        #
        # * <tt>:prefix</tt> - Restricts the response to only contain results that begin with the specified prefix.
        #
        #     Bucket.objects('jukebox')
        #     # => [<AWS::S3::S3Object '/jazz/miles.mp3'>, <AWS::S3::S3Object '/jazz/dolphy.mp3'>, <AWS::S3::S3Object '/classical/malher.mp3'>]
        #     Bucket.objects('jukebox', :prefix => 'classical')
        #     # => [<AWS::S3::S3Object '/classical/malher.mp3'>]
        #
        # * <tt>:marker</tt> - Marker specifies where in the result set to resume listing. It restricts the response
        #   to only contain results that occur alphabetically _after_ the value of marker. To retrieve the next set of results,
        #   use the last key from the current page of results as the marker in your next request.
        #
        #     # Skip 'mahler'
        #     Bucket.objects('jukebox', :marker => 'mb')
        #     # => [<AWS::S3::S3Object '/jazz/miles.mp3'>]
        #
        # === Examples
        #
        #   # Return no more than 2 objects whose key's are listed alphabetically after the letter 'm'.
        #   Bucket.objects('jukebox', :marker => 'm', :max_keys => 2)
        #   # => [<AWS::S3::S3Object '/jazz/miles.mp3'>, <AWS::S3::S3Object '/classical/malher.mp3'>]
        #
        #   # Return no more than 2 objects whose key's are listed alphabetically after the letter 'm' and have the 'jazz' prefix.
        #   Bucket.objects('jukebox', :marker => 'm', :max_keys => 2, :prefix => 'jazz')
        #   # => [<AWS::S3::S3Object '/jazz/miles.mp3'>]
        def objects(name = nil, options = {})
          find(name, options).object_cache
        end

        # Deletes the bucket named <tt>name</tt>.
        #
        # All objects in the bucket must be deleted before the bucket can be deleted. If the bucket is not empty,
        # BucketNotEmpty will be raised.
        #
        # You can side step this issue by passing the :force => true option to delete which will take care of
        # emptying the bucket before deleting it.
        #
        #   Bucket.delete('photos', :force => true)
        #
        # Only the owner of a bucket can delete a bucket, regardless of the bucket's access control policy.
        def delete(name = nil, options = {})
          find(name, {:max_keys => :all}).delete_all if options[:force]

          name = path(name)
          Base.delete(name).success?
        end
      end
    end
  end
end