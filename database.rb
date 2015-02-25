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
  many :items
  timestamps!

  timestamps!

  attr_accessor :name, :email # R/W access
  # Make sure email contains an @
  validates_format_of :email, :with => /@/

  # validate :protected_names
  #
  # # def protected_names
  # #   protected = ["signup", "signin", "login", "list", "logout"]
  # #   if protected.include?(login)
  # #     errors.add( :login, "That login name is protected, please choose another")
  # #   else
  # #
  # #   end
  # # end

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

class Element
  include MongoMapper::EmbeddedDocument
  key :imageURL, String
  key :linkURL, String
  key :row, Integer
  key :column, Integer
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
  key :html, String
  many :rows
  belongs_to :user
end

class Item
  include MongoMapper::Document

  key :imageURL, String
  key :group, String
  key :xPos, Integer
  key :yPos, Integer
  belongs_to :user

end

def random_string(len)
  ranStr = ""
  1.upto(len) { ranStr << rand(36).to_s(36) }
  return ranStr
end