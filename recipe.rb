class Recipe
  attr_reader :name, :description, :prep_time, :difficulty
  attr_accessor :marked
  def initialize(name, description, prep_time, difficulty = "Undefined", marked = false)
    @name = name
    @description = description
    @prep_time = prep_time
    @difficulty = difficulty
    @marked = marked
  end
end
