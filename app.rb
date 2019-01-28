require "sinatra"
require "sinatra/reloader" if development?
require "pry-byebug"
require "better_errors"
require 'open-uri'
require 'nokogiri'
configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path(__dir__)
end

require_relative 'cookbook'
require_relative 'recipe'
csv_file   = File.join(__dir__, 'recipes.csv')
cookbook   = Cookbook.new(csv_file)

# Start the app

get '/' do
  output = "<h1>Welcome to the Cookbook!</h1>"
  output << "<ul>"
  cookbook.recipes.each_with_index do |recipe, index|
    output << "<li>"
    output << "<a href='/rec/#{index}'>#{recipe.name}</a> "
    output << "> #{recipe.prep_time} min. "
    output << "> #{recipe.difficulty} "
    output << "> [#{recipe.marked ? 'X' : ' '}] "
    output << "/ <a href='/delete/#{index}'>(delete)</a> "
    output << "<a href='/mark/#{index}'>(mark)</a>"
    output << "</li>"
  end
  output << "</ul>"
  output << "<p><a href='/create/'>Add a new recipe!</a></p>"
  output << "<p><a href='/import/'>Import a new recipe from LetsCookFrench!</a></p>"
end

get '/create/' do
  output = "<h2>Add a new recipe!</h2>"
  output << "<form action='/create/' method='post'>"
  output << "<label for='name'>Recipe name:</label>"
  output << "<input type='text' name='name' id='name'></input><br><br>"
  output << "<label for='desc'>Description:</label>"
  output << "<textarea rows='4' cols = '40' name='desc' id='desc'></textarea><br><br>"
  output << "<label for='prep'>Preparation time (in minutes):</label>"
  output << "<input type='number' min='1' max='180' name='prep' id='prep' value='15'></input><br><br>"
  output << "<label for='diff'>Difficulty:</label>"
  output << "<input list='difficulties' name='diff' id='diff'></input><br><br>"
  output << "<datalist id='difficulties'>"
  output << "<option value='Very easy'>"
  output << "<option value='Easy'>"
  output << "<option value='Moderate'>"
  output << "<option value='Difficult'>"
  output << "</datalist>"
  output << "<input type='submit' value='Create recipe!'></input>"
  output << "</form>"
end

post '/create/' do
  @name = params[:name]
  @description = params[:desc]
  @prep_time = params[:prep]
  @difficulty = params[:diff]
  @new_recipe = Recipe.new(@name, @description, @prep_time, @difficulty)
  cookbook.add_recipe(@new_recipe)
  redirect to('/')
end

get '/rec/:id' do
  @index = params[:id].to_i
  output = "<h2>#{cookbook.recipes[@index].name}</h2>"
  output << "<h3>Preparation Time:</h3>"
  output << "<p>#{cookbook.recipes[@index].prep_time}</p>"
  output << "<h3>Difficulty:</h3>"
  output << "<p>#{cookbook.recipes[@index].difficulty}</p>"
  output << "<h3>Description:</h3>"
  output << "<p>#{cookbook.recipes[@index].description}</p>"
  output << "<p><a href='/'><<< See all recipes!</a></p>"
end

get '/delete/:id' do
  @index = params[:id].to_i
  cookbook.remove_recipe(@index) if cookbook.valid_index?(@index)
  redirect to('/')
end

get '/mark/:id' do
  @index = params[:id].to_i
  cookbook.mark_recipe(@index) if cookbook.valid_index?(@index)
  redirect to('/')
end

get '/import/' do
  # erb 'views/recipes/recipe_form'
  output = "<h2>Import a new recipe from LetsCookFrench!</h2>"
  output << "<form action='/import/seach/' method='get'>"
  output << "<label for='keyword'>Keyword:</label>"
  output << "<input type='text' name='keyword' id='keyword'></input><br><br>"
  output << "<label for='count'>Number of recipes:</label>"
  output << "<input type='number' min='1' max='50' name='count' id='count' value='5'></input><br><br>"
  output << "<label for='diff'>Difficulty filter:</label>"
  output << "<input list='difficulties_2' name='diff' id='diff'></input><br><br>"
  output << "<datalist id='difficulties_2'>"
  output << "<option value='All'>"
  output << "<option value='Very easy'>"
  output << "<option value='Easy'>"
  output << "<option value='Moderate'>"
  output << "<option value='Difficult'>"
  output << "</datalist>"
  output << "<input type='submit' value='Search recipe!'></input>"
  output << "</form>"
end

get '/import/seach/' do # rubocop: disable Metrics/BlockLength
  # Get user input
  @keyword = params[:keyword]
  @count = params[:count].to_i
  @difficulty = params[:diff]
  # Open HTML doc
  @url = "http://www.letscookfrench.com/recipes/find-recipe.aspx?aqt=#{@keyword}"
  @html_doc = Nokogiri::HTML(open(@url).read)
  # Select proper info
  @final_array = fetch_data(@html_doc, @keyword, @count, @difficulty)
  # Create html to put info
  if @final_array.length.zero?
    output = "<p>No recipes found with provided criteria!</p>"
    output << "<a href='/import/'><<< Try again!</a>"
  else
    output = "<h2>#{@keyword.capitalize} recipes from LetsCookFrench!</h2>"
    output << "<ol>"
    @final_array.each do |recipe|
      output << "<li>"
      output << "#{recipe[:name]} "
      output << "> #{recipe[:prep]} min. "
      output << "> #{recipe[:diff]} "
      output << "</li>"
    end
    output << "</ol>"
    # Create a form for selection of the recipe to create
    output << "<form action='/import/create/' method='post'>"
    output << "<label for='recipe_fetch'>Recipe to fetch:</label>"
    output << "<input type='number' min='1' max='#{@final_array.length}' name='recipe_fetch' id='recipe_fetch'></input>"
    output << "<br></br>"
    output << "<input type='submit' value='Create recipe!'></input>"
    output << "<input type='hidden' value='#{@final_array.to_json}' name='array' id='array'></input>"
    output << "</form>"
  end
end

post '/import/create/' do
  @final_array = JSON.parse(params[:array], symbolize_names: true)
  @recipe_to_fetch = @final_array[params[:recipe_fetch].to_i - 1]
  name = @recipe_to_fetch[:name]
  description = @recipe_to_fetch[:desc]
  prep_time = @recipe_to_fetch[:prep]
  difficulty = @recipe_to_fetch[:dif]
  new_recipe = Recipe.new(name, description, prep_time, difficulty)
  cookbook.add_recipe(new_recipe)
  redirect to('/')
end

def fetch_data(html_doc, keyword, count, difficulty)
  # Retrieve data from HTML
  recipe_mass_data = []
  html_doc.search('.m_contenu_resultat').each do |element|
    recipe_mass_data << element
  end
  # Create an hash with clean data
  recipe_clean_data = clean_data(recipe_mass_data)
  # Apply difficulty filter & select count
  recipe_with_difficulty = recipe_clean_data.select do |recipe|
    difficulty == "All" ? recipe : recipe[:diff] == difficulty.capitalize
  end
  recipe_with_difficulty.take(count)
end

def clean_data(recipe_mass_data)
  recipe_clean_data = []
  recipe_mass_data.each do |element|
    recipe_hash = {}
    recipe_hash[:name] = element.at('.m_titre_resultat a').text.strip
    recipe_hash[:desc] = element.at('.m_texte_resultat').text.strip
    recipe_hash[:prep] = element.at('.m_detail_time').text.strip.scan(/\d{2}/).first
    recipe_hash[:diff] = element.at('.m_detail_recette').text.split("-")[2].strip
    recipe_clean_data << recipe_hash
  end
  recipe_clean_data
end
