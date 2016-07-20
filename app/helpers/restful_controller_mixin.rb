module RestfulControllerMixin
  def controller_restful?
    # want to be able to cache false, so no ||=
    return @_restful_cache unless @_restful_cache.nil?

    obj = @view_binding.receiver
    @_restful_cache = obj.respond_to?(:controller) ? obj.controller.try(:restful?) : obj.try(:restful?)
  end
end
