# temporary hack for when/if we can get patch accepted upscream
# et-orbi doesn't support comparisons of EoTime in the scheduler with user provided Time objects
# see https://github.com/ManageIQ/manageiq/pull/19153#issuecomment-521719495
module ConvertTimeToEoTime
  def ==(*args)
    o = EtOrbi.make_time(args.first) if args.first.kind_of?(Time) || args.first.kind_of?(DateTime)
    super(o)
  end
end

require 'et-orbi'
EtOrbi::EoTime.prepend(ConvertTimeToEoTime)
