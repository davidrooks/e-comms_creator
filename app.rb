require 'rubygems'
require 'sinatra'
require 'mongo_mapper'
require 'json'
require 'logger'

class Element
  include MongoMapper::EmbeddedDocument
  key :imageURL, String
  key :linkURL, String
end

class Column
  include MongoMapper::EmbeddedDocument

  key :element, Element
end

class Row
  include MongoMapper::EmbeddedDocument

  many :columns
end

class Ecomm
  include MongoMapper::Document

  key :name, String
  key :width,  Integer
  many :rows
end


configure do
  enable :sessions
  # Create the log file if it doesn't exist,
  # otherwise just start appending to it,
  # preserving the previous content
  log_file = File.open('e-comms.log', 'a+')
  # Don't buffer writes to this file. Recommended for development.
  log_file.sync = true

  logger = Logger.new(log_file)
  # Log everything to the log file
  logger.level = Logger::DEBUG

  set :logger, logger
end

# Convenience method
def logger; settings.logger; end

helpers do
  def username
    session[:identity] ? session[:identity] : 'Hello stranger'
  end
end

before '/secure/*' do
  if !session[:identity] then
    session[:previous_url] = request.path
    @error = 'Sorry guacamole, you need to be logged in to visit ' + request.path
    halt erb(:login_form)
  end
end

get '/' do
  erb :index
end

get '/show' do
  @ecomms = Ecomm.all()
  erb :show_comms
end
get '/create' do
  erb :create_comms
end

post '/create' do
  logger.debug "printing post params"
  logger.debug "params: #{params.inspect}"
  erb "<pre><code>#{JSON.pretty_generate(params)}</code></pre><pre><code>#{save(params)}</code></pre>"
end

def save(params)
  puts "#{params}"
  puts "#{params[:itm].to_a}"
  puts "#{params[:itm].to_a[1]}"
  puts "#{params[:itm].to_a[1][1]}"
  puts "#{params[:itm].to_a[1][1][:row]}"

  curRow = 1
  curCol = 1
  row = Row.new()
  col = Column.new()

  ecomm = Ecomm.new(:width => params[:width].to_i, :name => params[:name])

  params[:itm].each do |index, item|
    puts "processing item #{index.to_s} of #{params[:itm].length-1}"
    elem = Element.new(:imageURL => item[:imageURL], :linkURL => item[:linkURL])
    col[:element] = elem
    row.columns << col
    if (index.to_i == params[:itm].length-1)
      ecomm.rows  << row
    elsif (params[:itm].to_a[index.to_i+1][1][:row] != item[:row])
      #we are on last item or on next item will we start of new row so we can write the current one
    # if (item[:row] != curRow) || (index == params[:itm].length-1)
      puts "item #{index.to_s} finishing row"
      ecomm.rows  << row
      row = Row.new()
      curRow = item[:row]
      curCol = 1
    else
      #next item has same row
      puts "item #{index.to_s} adding column"
  #     we have a row with multiple columns
      ++curCol
    end
    col = Column.new()
  end
  ecomm.save
  return JSON.pretty_generate(JSON.parse(ecomm.to_json))
  ecomm.save
end

def convert(params)
  row = []
  curRow = 0

  params[:itm].each do |index, item|
    curRow = item[:row]
    if !row.include? item[:row]
      row.push([])
    end
  end
end

def printHTML(params)
  out = ''
  row = 0
  column = 1
  out = "<table border='0' cellspacing='0' cellpadding='0' style='border-collapse: collapse; border-spacing: 0;'>"
  params[:itm].each do |index, item|
    if item[:row] != row
     out = out + "<tr>"
      ++row
    end
    if item[:column] > 1
      out = out + "<table border='0' cellspacing='0' cellpadding='0'>"
    end

    out = out + '<td>' + item[:row] + ' ' + item[:column] + ' ' + item[:imageURL] + ' ' + item[:linkURL] + '</td>'
  end

  return out
end

get '/login/form' do
  erb :login_form
end

post '/login/attempt' do
  session[:identity] = params['username']
  where_user_came_from = session[:previous_url] || '/'
  redirect to where_user_came_from
end

get '/logout' do
  session.delete(:identity)
  erb "<div class='alert alert-message'>Logged out</div>"
end


get '/secure/place' do
  erb "This is a secret place that only <%=session[:identity]%> has access to!"
end
