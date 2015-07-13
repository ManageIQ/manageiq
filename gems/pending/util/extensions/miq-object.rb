class Object #:nodoc:
  def deep_send(*args)
    args = args.first.dup if args.length == 1 && args.first.kind_of?(Array)
    args = args.shift.to_s.strip.split('.') + args

    arg = args.shift
    raise ArgumentError if arg.nil?

    result = self.send(arg)
    return nil    if result.nil?
    return result if args.empty?
    result.deep_send(args)
  end
end
