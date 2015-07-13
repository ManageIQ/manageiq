class MiqObjName < String
  attr_accessor :classname

  def initialize(str, classname)
    @classname = classname
    super(str)
  end

  def to_s
    "#{@classname}.#{super}"
  end
end

