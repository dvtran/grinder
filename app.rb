# LifeGrinder
# Makes boring tasks easy be letting users assign them an amount of xp
# Inspired by the EpicWin app
#
# Dan Tran, dandeeman
#
# LINKS
# http://net.tutsplus.com/tutorials/ruby/singing-with-sinatra-the-recall-app-2/
# http://marconijr.com/content/rubys-datamapper-101
# http://datamapper.org/docs/find
# http://htmldog.com/guides/htmlbeginner/forms/
# http://cheat.errtheblog.com/s/datamapper/
# http://www.sinatrarb.com/intro
# http://sinatra-book.gittr.com/
# https://github.com/charliepark/omniauth-for-sinatra/tree/abec8d13f58e7b531ef00f531ace3e2d50a46f29
# 

require 'rubygems'
require 'sinatra'
require 'erb'
require 'dm-core'
require 'dm-migrations'


%w(rubygems oa-oauth dm-core dm-sqlite-adapter dm-migrations sinatra).each { |dependency| require dependency }

configure :production do
  DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
end


configure :development do
  DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/database.db")
end
class User
  include DataMapper::Resource
  property :id,         Serial
  property :uid,        String
  property :name,       String
  property :nickname,   String
  property :created_at, DateTime

  property :xp,         Integer,  :default => 0
  has n,   :quests
end

class Quest
  include DataMapper::Resource
  property :id,         Serial 
  property :todo,       Text,     :required => true  
  property :xp,         Integer,  :required => true 
  property :completed,  Boolean
  property :created_at, DateTime

  belongs_to :user
end


DataMapper.finalize.auto_upgrade! 

# You'll need to customize the following line. Replace the CONSUMER_KEY 
#   and CONSUMER_SECRET with the values you got from Twitter 
#   (https://dev.twitter.com/apps/new).
# message from dan: make sure to set the callback url in the app settings as http://127.0.0.1:4567/auth/twitter/callback .
use OmniAuth::Strategies::Twitter, '7MphpScIqaHTEUOaYjV2w', 'xIPjSVfoJh2YY5uzVW8TOGlRA42W8fOuw0FOFhSGCj8'

enable :sessions

helpers do
  def current_user
    @current_user ||= User.get(session[:user_id]) if session[:user_id] 
  end
  include Rack::Utils  
  alias_method :escape, :escape_html 
end

get '/' do
  if current_user
    redirect '/home'
    # current_user.id.to_s + " ... " + session[:user_id].to_s 
  else
    erb :landing
  end
end

get '/home' do
  if current_user
    @user = current_user.nickname
    @uid = current_user.id
    @user_xp = current_user.xp
    @quests = Quest.all(:user_id => @uid, :order => :created_at.desc, :completed => false)

    # note from dan: ':order => :created_at.desc' is essential, it won't work without it.
    
    erb :home
  else
    erb :landing
  end
end

post '/home' do
  if current_user
  
    q = Quest.new(:todo => params[:todo], :xp => params[:xp], :created_at => Time.now, :completed => false)
    # g.todo = params[:todo]
    # g.xp = params[:xp]
    # g.created_at = Time.now
    # g.completed = false
    q.save

    # note from dan: remember to apply the change to users as well
    # http://marconijr.com/content/rubys-datamapper-101
    current_user.quests << q
    current_user.save

    
    redirect '/home'    
  else
    erb :landing
  end
end

get '/done/:id' do
  if current_user
    q = Quest.get params[:id]
    if q.user_id == current_user.id
      q.completed = q.completed ? false : true
      current_user.xp += q.xp
      q.save
      current_user.save
      redirect '/home'
    else
      status 404  
      erb :fourohfour
    end
  else
    status 404  
    erb :fourohfour
  end
end
  
get '/completed' do
  if current_user
    @user = current_user.nickname
    @uid = current_user.id
    @completed_quests = Quest.all(:user_id => @uid, :order => :created_at.desc, :completed => true)
    erb :completed
  else
    status 404  
    erb :fourohfour
  end
end

get '/auth/:name/callback' do
  auth = request.env["omniauth.auth"]
  user = User.first_or_create({ :uid => auth["uid"]}, { 
    :uid => auth["uid"], 
    :nickname => auth["user_info"]["nickname"], 
    :name => auth["user_info"]["name"], 
    :created_at => Time.now })
  session[:user_id] = user.id
  redirect '/'
end

# any of the following routes should work to sign the user in: 
#   /sign_up, /signup, /sign_in, /signin, /log_in, /login
["/sign_in/?", "/signin/?", "/log_in/?", "/login/?", "/sign_up/?", "/signup/?"].each do |path|
  get path do
    redirect '/auth/twitter'
  end
end

# either /log_out, /logout, /sign_out, or /signout will end the session and log the user out
["/sign_out/?", "/signout/?", "/log_out/?", "/logout/?"].each do |path|
  get path do
    session[:user_id] = nil
    redirect '/'
  end
end

not_found do  
  status 404  
  erb :fourohfour  
end  


