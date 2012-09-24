#encoding: UTF-8
$stdout.sync = true # gives foreman full stdout

if RUBY_VERSION <= "1.8.7" then $KCODE = 'u' end #needed for string conversion in ruby 1.8.7
require "rubygems"
require "bundler/setup"
require "sinatra"
require "sinatra/reloader" if development?
require "slim"
require "json"

# RDFmodeler loads all other classes in marc2rdf
require_relative './lib/rdfmodeler.rb'

# Global constants

# Sinatra configs
session = {}
set :server, 'thin'
set :username,'bob'
set :token,'schabogaijk13@[]5fukkksiur!&&%&%'
set :password,'secret'

# Very simple authentication
helpers do
  def admin? ; request.cookies[settings.username] == settings.token ; end
  def protected! ; halt [ 401, 'Not Authorized' ] unless admin? ; end
end

# Routing
get '/' do
  # Front page
  if admin?
    slim(:index)  
  else
    slim(:about)
  end
end

get '/mapping' do
  # Primary mapping
  session[:mapping] = Mapping.new('mapping.yml')
  skeleton = YAML::load( File.open( File.join(File.dirname(__FILE__), './db/templates/', 'mapping_skeleton.yml')))
  slim :mapping, :locals => {:mapping => session[:mapping], :skeleton => skeleton}
end

get '/converter' do
  # Main conversion tool
  slim(:converter)  
end

get '/harvester' do
  # Harvesting sources
  slim(:harvester)  
end

get '/settings' do
  # General settings
  session[:settings] = YAML::load( File.open( File.join(File.dirname(__FILE__), './config/', 'settings.yml')))
  slim :settings, :locals => {:settings => session[:settings]}
end

put '/settings' do
  # Save general settings
  settings = YAML::Store.new( File.join(File.dirname(__FILE__), 'config/settings.yml'), :Indent => 2 )
  puts params
  settings.transaction do
    settings['config'] = params['config'] if params['config']
  end
end

get '/repository' do
  # Misc. repository settings
  session[:repository] = Repo.new('repository.yml')
  slim :repository, :locals => {:repo => session[:repository]}
end

put '/repository' do
  # Save/update repository settings
  session[:repository].rdfstore = params['rdfstore'] if params['rdfstore']
  session[:repository].resource = params['resource'] if params['resource']
  session[:repository].oai      = params['oai']      if params['oai']
  session[:repository].save
end

get '/about' do
  # Front page
  slim(:about)  
end

get '/login' do
  # Login page
  slim(:login)
end

post '/login' do
  if params['username']==settings.username&&params['password']==settings.password
      response.set_cookie(settings.username,settings.token) 
      redirect '/'
    else
      "Username or Password incorrect"
    end
end

get('/logout'){ response.set_cookie(settings.username, false) ; redirect '/' }
