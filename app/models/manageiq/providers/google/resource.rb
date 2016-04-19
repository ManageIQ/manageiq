module ManageIQ::Providers::Google
  class Resource
    def initialize(uri)
      @type = parse_resource_type(uri)
    end

    def snapshot?
      @type == 'snapshots'
    end

    def image?
      @type == 'images'
    end

    def disk?
      @type == 'disks'
    end

    def unknown?
      @type == 'unknown'
    end

    private

    # Parses a Google resource url and returns the resource from the path.
    # This method understands both complete urls (starting with
    # https://www.googleapis.com) as well as partials.
    def parse_resource_type(uri)
      return 'unknown' if uri.blank?

      # We can cheat here a bit - most the google APIs (at least in compute.v1)
      # define resources directly under their type (i.e. snapshots/foo or
      # images/bar). However, 'images' allow the specification of 'family' which
      # is an alias to the latest image in a family, breaking the rule.
      parts = URI.parse(uri).path.split('/')

      # We assume that the resource url follows the pattern:
      # http://some-google-url.com/some/basepath/resource_type/resource_name
      _                    = parts[-1] # resource_name, unused here
      resource_type        = parts[-2]
      resource_type_prefix = parts[-3]

      return 'unknown' if resource_type.blank?

      # Check for the special case of 'family' as explained above
      return 'images' if resource_type == 'family' && resource_type_prefix == 'images'

      resource_type
    end
  end
end
