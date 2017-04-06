module Api
  class RequestEditor
    def self.edit(request, data)
      request_options = RequestParser.parse_options(data)
      user = RequestParser.parse_user(data) || User.current_user

      begin
        request.update_request(request_options, user)
      rescue => err
        raise BadRequestError, "Could not update the request - #{err}"
      end
    end
  end
end
