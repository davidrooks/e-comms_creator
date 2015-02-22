require 'sinatra'
require 'json'
require 'logger'
require './database'

configure do
  use Rack::Session::Cookie, :key => 'rack.session',
      :path => '/',
      :secret => 'your_secret'
  set :sessions, true
  set :protection, except: :session_hijacking
  session = nil

  log_file = File.open('e-comms.log', 'a+')
  # Don't buffer writes to this file. Recommended for development.
  log_file.sync = true
  @logger = Logger.new(log_file)
  # Log everything to the log file
  @logger.level = Logger::DEBUG
end

helpers do
  def username
    if session[:user].nil?
      'Hello Stranger'
    else
      session[:user].name
    end
  end

  include Rack::Utils
  alias_method :h, :escape_html
end

def logged_in
  if session[:user].nil?
    if session[:id].nil?
      session[:id] ||= random_string(20)
    end
  else
    return session[:id]
  end
end

def signed_in
  return !session[:user].nil?
end

before do
  logged_in # Check login status
end

# before '/secure/*' do
#   if !session[:identity] then
#     session[:previous_url] = request.path
#     @error = 'Sorry guacamole, you need to be logged in to visit ' + request.path
#     halt erb(:login_form)
#   end
# end

get '/user/signup' do
  erb :signup
end

post '/user/signup' do
  u = User.new
  u.email = params["email"]
  u.name = params["name"]
  u.password = params["password"]


  # if user created successfully, go to login page
  if u.save
    redirect "/user/signin"
  else
    @error = u.errors.map { |k, v| "#{k}: #{v}" }.join("<br/> ")
    halt erb :signup
  end
end

get '/user/signin' do
  erb :signin
end

post '/user/signin' do
  email = params["email"]
  pass = params["password"]

  if email == "" || pass == ""
    @error = "Fields cannot be blank"
    halt erb :login
  elsif session[:user] = User.authenticate(email, pass)
    session[:user] == User.authenticate(email, pass)
    redirect "/"
  else
    @error = "Username and Password do not match"
    halt erb :signin
  end
end

get '/user/logout' do
  session[:id] = nil
  session[:user] = nil
  erb "<div class='alert alert-message'>Logged out</div>"
end

get '/' do
  if session[:user].nil?
    redirect "/user/signin"
  else
    @ecomms = Ecomm.all("user_id" => session[:user].id)
    erb :index
  end
end

get '/show/:id' do
  @e = Ecomm.find(params[:id])
  erb :show_comm
end

get '/create' do
  # puts "logged in user: #{session[:user].to_json}"
  erb :create_comms
end

post '/create' do
  puts "logged in user: #{session[:user].to_json}"
  e = Ecomm.new(:user => session[:user], :width => params[:width].to_i, :name => params[:name])

  e = save(e, params)
  createHTML(e)
  redirect "/show/#{e[:_id]}"
end

get '/delete/:id' do
  Ecomm.destroy(params[:id])
  redirect '/'
end

get '/edit/:id' do
  @e = Ecomm.find(params[:id])
  erb :edit_comm
end

post '/edit/:id' do
  e = Ecomm.find(params[:id])
  e.rows.clear
  e = save(e, params)
  createHTML(e)
  redirect "/show/#{params[:id]}"
end

get '/index-new' do
  @groups = getGroups
  erb :index_new
end

get '/element/show' do
  puts "user = #{session[:user]}"
  puts "user id = #{session[:user].id}"
  # @ecomms = Ecomm.all("user_id" => session[:user].id)
  @e = Item.all("user_id" => session[:user].id)

  erb :show_element
end

get '/element/show/:group' do

  @e = Item.all({"user_id" => session[:user].id, :group => params[:group]})

  erb :show_element
end


get '/element/create' do

  @groups = getGroups
  puts "arr = #{@groups.to_s}"
  erb :create_element
end

post '/element/create' do
  puts params
  e = Item.new(:imageURL => params[:imageURL], :user => session[:user], :group => params[:group])
  e.save
  redirect '/index-new'
end

get '/element/edit/:id' do
  @e = Item.find(params[:id])

  @groups = getGroups

  puts "item = #{@e[:group]}"
  puts "group = #{@groups}"
  erb :edit_element
end

post '/element/edit/:id' do
  e = Item.find(params[:id])
  e[:group] = params[:group]
  if params[:new_group] != ''
    e[:group] = params[:new_group]
  elsif
    e[:group] = params[:group]
  end
  e[:imageURL] = params[:imageURL]

  e.save
  redirect '/element/show'
end

get '/element/delete/:id' do
  Item.destroy(params[:id])
  redirect '/element/show'
end

get '/ecomm/create' do
  erb :create_ecomm
end

def save(ecomm, params)
  row = Row.new()
  col = Column.new()
  # puts params
  # puts ""
  # puts ""
  # puts params[:itm]
  # puts ""
  # puts ""
  # puts params[:itm].to_a.to_s
  # puts ""
  # puts ""

  i = 0
  if params[:itm].nil?
    #no elements, nothing to save
    return ecomm
  end


  params[:itm].each do |index, item|
    # puts "current index = #{index.to_s}"
    # puts "current index = #{i}"
    # puts "current item = #{index.to_i+1}"
    # puts "current item = #{item}"
    # puts "param item = #{params[:itm].to_a[i]}"
    # puts "param item = #{params[:itm].to_a[index.to_i]}"
    # puts "total items = #{params[:itm].to_a.length}"
    # puts "row number = #{item[:row]}"
    # puts ""
    # puts ""

    elem = Element.new(:imageURL => item[:imageURL], :linkURL => item[:linkURL], :row => item[:row], :column => item[:column])
    col[:element] = elem
    row.columns << col
    if (i.to_i == params[:itm].to_a.length-1)
      #we are on last item
      puts "saving row"
      ecomm.rows << row
    elsif (params[:itm].to_a[i+1][1][:row].to_i != item[:row].to_i)
      #next item will we start of new row so we can write the current one
      puts "saving row and creating new row"
      ecomm.rows << row
      row = Row.new()
    else
      #     we have a row with multiple columns so do not write the row yet
      puts "multiple rows"
    end
    col = Column.new()
    i = i + 1
  end
  ecomm.save
  return ecomm
end

def createHTML(data)
  html = '<html><head><title></title></head><body><table border="0" cellspacing="0" cellpadding="0">'
  data.rows.each do |row|
    html = html + "<tr>"
    row.columns.each do |col|
      if row.columns.size > 1 && row.columns.first == col
        html = html + '<table border="0" cellspacing="0" cellpadding="0">'
        html = html + '<tr>'
      end
      html = html + "<td>"
      if col.element[:linkURL]
        html = html + "<a href='#{col.element[:linkURL]}'>"
      end
      html = html + "<img src='#{col.element[:imageURL]}'>"
      if col.element[:linkURL]
        html = html + "</a>"
      end
      html = html + "</td>"

      if row.columns.size > 1 && row.columns.last == col
        html = html + '</tr></table>'
      end
    end
    html = html + '</tr>'
  end
  html = html + '</table></body></html>'

  data[:html] = html
  data.save
end

def getGroups
  items = Item.all()
  arr = []
  items.each do |g|
    if !arr.include? g[:group]
      arr << g[:group]
    end
  end
  return arr
end

