require 'sinatra'
require 'json'
require 'logger'
require 'htmlbeautifier'
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
  items = @e.items
  puts "items = #{@items}"
  @html = createTable(items)
  @html_code = @html
  @html_code = @html_code.gsub(/&/, '&amp')
  @html_code = @html_code.gsub(/</, '&lt')
  @html_code = @html_code.gsub(/>/, '&gt')
  @html_code = HtmlBeautifier.beautify(@html_code, tab_stops: 4)
  erb :show_comm
end

get '/create' do
	erb :create_ecomm_step1
end

post '/create' do
  #create ecomm and save elements
  puts "params = #{params}"
  if params[:step].to_i == 1
    e = Ecomm.new(:user => session[:user], :width => params[:width].to_i, :name => params[:name])
    params[:itm].each do |index, item|
      i = Item.new(:imageURL => item[:imageURL])
      i.save
      e.items << i
    end
    e.save
    @items = e.items
    @id = e[:_id]
    erb :create_ecomm_step2
  elsif params[:step].to_i == 2
    e = Ecomm.find(params[:elem_id])
    @html = createTable(e.items)
    erb :show_comm
  end
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
  if params[:step].to_i == 1
    e = Ecomm.find(params[:id])
    e.items.clear
    params[:itm].each do |index, item|
      i = Item.new(:imageURL => item[:imageURL])
      i.save
      e.items << i
    end
    e.save
    @items = e.items
    @id = e[:_id]
    erb :create_ecomm_step2
  elsif params[:step].to_i == 2
    @e = Ecomm.find(params[:elem_id])
    # @id = e[:_id]
    tmp = @e.items.sort_by{|x| [x[:yPos].to_i, x[:xPos].to_i]}
    @e.items.clear
    @e.items = tmp
    @e.save
    # @items = e.items
    @html = createTable(@e.items)
    erb :show_comm
  end
end

def createTable(items)
  columns = []
  rows = []
  i = 0
  prevX = 0
  prevY = 0
  while i <= items.size - 1
    item = items[i]
    if i == 0
      # first item so add to column
      columns << item
    else
      # not on first element
      if item[:yPos] != prevY
        # we are on a new row
        rows << columns
        columns = []
        columns << item
      else
        # we are on same row
        columns << item
      end
    end
    if i == items.size - 1
      rows << columns
    end
    prevX = item[:xPos]
    prevY = item[:yPos]
    i += 1
  end

  puts "rows = #{rows}"

  html = ''
  rows.each do |cols|
    cols.each do |col|
      if cols == rows.first && col == cols.first
        html = html + "<table  border='0' cellspacing='0' cellpadding='0'>"
      end
      if col == cols.first
        html = html + "<tr>"
      end
      html = html + "<td><img src='" + col[:imageURL] + "'/></td>"
      if col == cols.last
        html = html + "</tr>"
      end
      if cols == rows.last && col == cols.last
        html = html + "</table>"
      end
    end
  end
  puts "html = #{html}"
  return html
end


post '/ecomm/item/savePos' do
  puts "params = #{params}"
  puts "ecomm = #{params[:ecomm]}"
  puts "id = #{params[:id]}"
  puts "x pos = #{params[:x]}"
  puts "y pos = #{params[:y]}"
  e = Ecomm.find(params[:ecomm])
  i = e.items.find(params[:id])
  i[:xPos] = params[:x]
  i[:yPos] = params[:y]
  i.save
end