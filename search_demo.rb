# create table tweet_demo1 (url varchar(255) not null,
#                           last_tweet_id varchar(255) not null,  
#                           count int default 1, 
#                           description varchar(255), 
#                           created_at datetime default current_timestamp
#                           updated_at datetime default current_timestamp);

require 'json'
require 'yaml'
require '/home/ubuntu/tweet_demo/micro_wrapper'
require '/home/ubuntu/tweet_demo/time_helpers'
require '/home/ubuntu/tweet_demo/services/search_api'
require '/home/ubuntu/tweet_demo/services/url'
require '/home/ubuntu/tweet_demo/services/micro_mysql'

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

queries = MicroMysql.new("SELECT * FROM query_list;").call['result']
if !queries.nil?
  queries.each do |query|
    db = query['db']
    term = query['term']
    results = MicroMysql.new("SELECT * FROM #{db} ORDER BY updated_at DESC LIMIT 1;").call
    tweet_id = results['result'].nil? ? '1' : results['result'][0]['last_tweet_id']
    SearchDemo.new(db, term, 200, tweet_id).run
  end
end
