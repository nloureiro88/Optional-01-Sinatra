require 'csv'
require_relative 'recipe'

class Cookbook
  attr_reader :recipes
  def initialize(csv_file_path)
    @path = csv_file_path
    @recipes = []
    CSV.foreach(@path) do |row|
      old_recipe = Recipe.new(row[0], row[1], row[2], row[3], row[4] == "true")
      @recipes << old_recipe
    end
  end

  def all
    @recipes
  end

  def recipe_name(recipe_index)
    @recipes[recipe_index].name
  end

  def add_recipe(new_recipe)
    @recipes << new_recipe
    save
  end

  def valid_index?(recipe_index)
    recipe_index >= 0 && recipe_index < @recipes.length
  end

  def remove_recipe(recipe_index)
    @recipes.delete_at(recipe_index)
    save
  end

  def mark_recipe(recipe_index)
    @recipes[recipe_index].marked ? @recipes[recipe_index].marked = false : @recipes[recipe_index].marked = true
    save
  end

  def save
    CSV.open(@path, 'wb') do |csv|
      @recipes.each do |recipe|
        csv << [recipe.name, recipe.description, recipe.prep_time, recipe.difficulty, recipe.marked]
      end
    end
  end
end
