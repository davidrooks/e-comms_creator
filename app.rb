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
    @id = e.id
    erb :create_ecomm_step2
  elsif params[:step].to_i == 2
    e = Ecomm.find(params[:elem_id])
    items = e.items
    rows = []
    cols = []

    items.each_with_index do |i, index|
      puts "item = #{i}"
      puts "index = #{index}"
      cols << i
      if i != @items.last
        #we are not on the last item so check the next items position
        next_i = @items[index+1]
        if next_i[:yPos] > i[:yPos]
          #next item is lower than current item so it sits in a new row
          rows << cols
          cols = []
        end
      else
        rows << cols
      end
    end
    puts "rows = #{rows.to_s}"
    @html = createTable(rows)
    erb :create_ecomm_step3
  end

end

post '/ecomm/item/savePos' do
  puts "params = #{params}"
  puts "ecomm = #{params[:ecomm]}"
  puts "id = #{params[:id]}"
  puts "x pos = #{params[:x]}"
  puts "y pos = #{params[:y]}"
  e = Ecomm.find(params[:ecomm])
  puts "ecomm = #{e}"
  i = e.items.find(params[:id])
  i[:xPos] = params[:x]
  i[:yPos] = params[:y]
  i.save
end

def createTable(rows)
  html = "<table  border='0' cellspacing='0' cellpadding='0'>"
  rows.each do |row|
    html = html + "<tr>"
    row.each do |col|
      if col.kind_of?(Array)
        puts "shouldnt reach here yet"
        html = html + createTable(col)
      elsif row.count == 1
        #only 1 item in this row
        html = html + "<td><img src='" + col[:imageURL] + "'/></td>"
      else
        if col == row.first
          html = html + "<table  border='0' cellspacing='0' cellpadding='0'>"
          html = html + "<tr>"
        end
        html = html + "<td><img src='" + col[:imageURL] + "'/></td>"
        if col == row.last
          html = html + "</tr>"
          html = html + "</table>"
        end
      end
    end
    html = html + "</tr>"
  end
  html = html + "</table>"
  return html
end

get '/seed' do
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_01.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_02.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_03.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_04.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_05.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_06.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_07.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_08.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_09.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_10.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_11.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_12.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_13.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_14.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_15.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_16.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_17.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_18.jpg', :group => 'february', :user => session[:user])
  i.save
  i = Item.new(:imageURL => 'http://samsaramindandbody.com/sites/default/files/pictures/nl3_19.jpg', :group => 'february', :user => session[:user])
  i.save
end

