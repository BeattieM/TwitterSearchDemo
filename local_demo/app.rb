require 'sinatra'
require 'json'
require 'yaml'
require 'httparty'
require 'dotenv'
Dotenv.load

class Demo < Sinatra::Base
  get '/tweets' do
    return 'no search query supplied' if params[:query].nil?
    @search_term = params[:query]
    dbname = params[:query].strip.gsub(/[^0-9A-Za-z.\-]/, '_')
    @error = MicroMysql.new("DESCRIBE #{dbname}").call['error']
    if @error.include? "doesn't exist"
      MicroMysql.new("create table #{dbname} (url varchar(255) not null,last_tweet_id varchar(255) not null, count int default 1, description varchar(255), created_at datetime default current_timestamp, updated_at datetime default current_timestamp);").call
      MicroMysql.new("INSERT INTO query_list (db,term) VALUES(\'#{dbname}\',\'#{params[:query]}\');").call
      SearchDemo.new(dbname, params[:query], 200, 1).run
    end
    @results = MicroMysql.new("SELECT * FROM #{dbname} WHERE created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY) ORDER BY count DESC;").call['result']
    @test = 'test'
    erb :index
  end
end

class MicroWrapper
  attr_accessor :image, :tag, :client_address, :command, :command_args

  def initialize(docker_image, docker_image_tag, client_address)
    @image = docker_image
    @tag = docker_image_tag
    @client_address = client_address
  end
  
  def call(command, command_args)
    command_param = command_args.unshift(command)
    response = HTTParty.post(client_address,
                            body: {
                              docker_image: image,
                              docker_image_tag: tag,
                              command: command_param.to_json,
                            }
    )
    JSON.parse response.body
  end
end

class MicroMysql < MicroWrapper
  def initialize(query)
    @client_address = "http://localhost:49999"

    @image = "izackp/go-mysql-microservice"
    @tag = "0.2"
    @command = "/Go-MySQL-Microservice"
    uri = ENV["mysql_uri"]
    pw = ENV["mysql_password"]
    @command_args = [
      "#{uri}",
      "#{pw}",
    ]
    @query = query
  end
  def call
    MicroWrapper.new(image, tag, client_address).call(command, command_args.push(@query))
  end
end

class SearchApi < MicroWrapper
  def initialize(query, limit, since_id)
    @client_address = "http://localhost:49999"

    @image = "cloudspace/go-twitter-query"
    @tag = "0.2.0"
    @command = "./go-twitter-query"
    @command_args = [
      "#{ENV['consumer_key']}",
      "#{ENV['consumer_secret']}",
      "#{ENV['access_token']}",
      "#{ENV['access_token_secret']}",
      "#{query}",
      "#{limit}",
      "#{since_id}"
    ]
  end

  def call
    MicroWrapper.new(image, tag, client_address).call(command, command_args)
  end
end

module Url
  class Lengthener < MicroWrapper
    def initialize(url)
      @client_address = "http://localhost:49999"

      @image = "cloudspace/go_url_lengthener"
      @tag = "0.4"
      @command = "./Go_URL_Lengthener"
      @command_args = ["#{url}"]
    end

    def call
      MicroWrapper.new(image, tag, client_address).call(command, command_args)
    end
  end

  class Stripper < MicroWrapper
    def initialize(url)
      @client_address = "http://localhost:49999"

      @image = "izackp/go-utm-stripper"
      @tag = "0.3"
      @command = "./Go-UTM-Stripper"
      @command_args = ["#{url}"]
    end

    def call
      MicroWrapper.new(image, tag, client_address).call(command, command_args)
    end
  end
end

class SearchDemo
  attr_accessor :search_query, :limit, :since_id, :stripped_urls, :database_table

  def initialize(database_table, search_query, limit, since_id)
    @database_table = database_table || "tweet_demo1"
    @search_query = search_query || "from:@cloudspace"
    @limit = limit || "200"
    @since_id = since_id || "1"
    @stripped_urls = []  
  end

  def run
    # make query against search api
    results = SearchApi.new(search_query, limit, since_id).call
    tweets = results["statuses"]
    metadata = results["search_metadata"]
    return if tweets.empty?
    # parse out urls
    tweets.sort_by { |hsh| hsh['id'] }.each do |tweet|
      tweet["entities"]["Urls"].each do |url_entity|
        url = url_entity["Url"]
        next if url.nil?
        description = tweet['text'].gsub(/\s|"|'/, '')
            
        # lengthen url
        results = Url::Lengthener.new(url).call
        next if results["result"].nil?
        long_url = results["result"]

        # strip url
        results = Url::Stripper.new(long_url).call
        next if results["result"].nil?
        stripped_url = results["result"]
        @stripped_urls << stripped_url
        
        # look for previous 
        query = "SELECT * FROM #{database_table} WHERE url=\"#{stripped_url}\" LIMIT 1;"
        results = MicroMysql.new(query).call

        # previous entry found
        unless results["result"].nil?
          result = results["result"][0]
          query = "UPDATE #{database_table} SET count=#{result['count'].to_i + 1}, last_tweet_id=\'#{tweet['id']}\', updated_at=\'#{Time.now}\', description=\'#{description}\' WHERE url=\'#{stripped_url}\';"
          MicroMysql.new(query).call
        else
          query = "INSERT INTO #{database_table} (url,last_tweet_id,description,created_at,updated_at) VALUES(\'#{stripped_url}\', \'#{tweet['id']}\', \'#{description}\', \'#{Time.now}\', \'#{Time.now}\');"
          MicroMysql.new(query).call
        end
      end
    end 
  end
end
