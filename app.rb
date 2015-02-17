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
    if	session[:id].nil?
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
    @error = u.errors.map{|k,v| "#{k}: #{v}"}.join("<br/> ")
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
    @ecomms = Ecomm.all("user._id" => session[:user].id)
    erb :index
  end
end

get '/show/:id' do
  @e = Ecomm.find(params[:id])
  erb :show_comm
end

get '/create' do
  puts "logged in user: #{session[:user].to_json}"
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

# get '/login/form' do
#   erb :login_form
# end
#
# post '/login/attempt' do
#   session[:identity] = params['username']
#   where_user_came_from = session[:previous_url] || '/'
#   redirect to where_user_came_from
# end



# get '/secure/place' do
#   erb "This is a secret place that only <%=session[:identity]%> has access to!"
# end

def save(ecomm, params)
  row = Row.new()
  col = Column.new()
  puts params
  params[:itm].each do |index, item|
    puts "current item = #{index.to_i+1}"
    puts "total items = #{params[:itm].length}"
    puts "item = #{item}"

    elem = Element.new(:imageURL => item[:imageURL], :linkURL => item[:linkURL], :row => item[:row], :column => item[:column])
    col[:element] = elem
    row.columns << col
    if (index.to_i == params[:itm].length-1)
      #we are on last item
      puts "saving row"
      ecomm.rows  << row
    elsif (params[:itm].to_a[index.to_i+1][1][:row] != item[:row])
      #next item will we start of new row so we can write the current one
      puts "saving row and creating new row"
      ecomm.rows  << row
      row = Row.new()
    else
  #     we have a row with multiple columns so do not write the row yet
    end
    col = Column.new()
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

