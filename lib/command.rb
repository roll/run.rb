# Module API

class Command

  # Public

  def initialize(name, code, variable: nil)
    @name = name
    @code = code
    @variable = variable
  end

  def name()
    return @name
  end

  def code()
    return @code
  end

  def code(value=nil)
    if value != nil
      @code = value
    end
    return @code
  end

  def variable()
    return @variable
  end

end
