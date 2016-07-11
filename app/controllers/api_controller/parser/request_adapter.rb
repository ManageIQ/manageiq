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

      def base
        url.partition(fullpath)[0] # http://target
      end

      def collection
        @collection ||= path.split("/")[version_override? ? 3 : 2]
      end

      def c_id
        @params[:c_id]
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
        URI.parse(url).path.sub(/\/*$/, '') # /api/...
      end

      def subcollection
        @subcollection ||= path.split("/")[version_override? ? 5 : 4]
      end

      def s_id
        @params[:s_id]
      end

      def version
        @version ||= if version_override?
                       @params[:version][1..-1] # Switching API Version
                     else
                       Api::Settings.base[:version] # Default API Version
                     end
      end

      private

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
