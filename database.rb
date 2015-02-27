require 'digest/sha1'
require 'date'
require 'mongo_mapper'

configure do
  MongoMapper.database = 'ecomms'
end

class User
  include MongoMapper::Document

  key :name, String
  key :email, String
  key :hashPass, String
  key :salt, String
  many :ecomms
  timestamps!


  attr_accessor :name, :email
  validates_format_of :email, :with => /@/

  def password=(pass)
    @password = pass
    self.salt = random_string(10) #unless self.salt
    self.hashPass = User.encrypt( @password, self.salt )
  end

  def self.encrypt(pass, salt)
    Digest::SHA1.hexdigest(pass + salt)

  end

  def self.authenticate(login, pass)
    u = User.first(:email => login)
    return nil if u.nil?
    return u if User.encrypt(pass, u.salt) == u.hashPass
    nil
  end
end

class Ecomm
  include MongoMapper::Document

  key :name, String
  key :width,  Integer
  key :html, String
  many :items
  belongs_to :user
end

class Item
  include MongoMapper::EmbeddedDocument

  key :imageURL, String
  key :xPos, Integer
  key :yPos, Integer
end

def random_string(len)
  ranStr = ""
  1.upto(len) { ranStr << rand(36).to_s(36) }
  return ranStr
end