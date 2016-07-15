class ApiController
  module Parser
    class RequestAdapter
      def initialize(req, params)
        @request = req
        @params = params
      end

      def action
        # for basic HTTP POST, default action is "create" with data being the POST body
        @action ||= method == :put ? 'edit' : (json_body['action'] || 'create')
      end

      def api_prefix
        @api_prefix ||= "#{base}#{prefix}"
      end

      def attributes
        @attributes ||= @params['attributes'].to_s.split(',')
      end

      def base
        url.partition(fullpath)[0] # http://target
      end

      #
      # c_path_parts returns: [collection, c_id, subcollection, s_id, ...]
      #
      def c_path_parts
        @c_path_parts ||= version_override? ? path.split('/')[3..-1] : path.split('/')[2..-1]
      end

      def collection
        @collection ||= c_path_parts[0]
      end

      def c_suffix
        @params[:c_suffix] || c_path_parts[1..-1].join('/')
      end

      def c_id
        @params[:c_id] || c_path_parts[1]
      end

      def subcollection
        @subcollection ||= c_path_parts[2]
      end

      def s_id
        @params[:s_id] || c_path_parts[3]
      end

      def expand?(what)
        expand_requested.include?(what.to_s)
      end

      def json_body
        @json_body ||= begin
                         body = @request.body.read if @request.body
                         body.blank? ? {} : JSON.parse(body)
                       end
      end

      def method
        @method ||= @request.request_method.downcase.to_sym # :get, :patch, ...
      end

      def path
        URI.parse(url).path.sub(%r{/*$}, '') # /api/...
      end

      def version
        @version ||= if version_override?
                       @params[:version][1..-1] # Switching API Version
                     else
                       Api::Settings.base[:version] # Default API Version
                     end
      end

      private

      def expand_requested
        @expand ||= @params['expand'].to_s.split(',')
      end

      def version_override?
        @params[:version] && @params[:version].match(Api::Settings.version[:regex]) # v#.# version signature
      end

      def fullpath
        @request.original_fullpath # /api/...&param=value...
      end

      def prefix
        prefix = "/#{path.split('/')[1]}" # /api
        version_override? ? "#{prefix}/#{@params[:version]}" : prefix
      end

      def url
        @request.original_url # http://target/api/...
      end
    end
  end
end
