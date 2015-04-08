class SearchApi < MicroWrapper
  def initialize(query, limit, since_id)
  	@client_address = "http://localhost:49999"

    @image = "cloudspace/go-twitter-query"
    @tag = "0.2.0"
    @command = "./go-twitter-query"
    secure_values = YAML.load_file("./services/twitter_query_secret.yml")
    @command_args = [
      "#{secure_values['consumer_key']}",
      "#{secure_values['consumer_secret']}",
      "#{secure_values['access_token']}",
      "#{secure_values['access_token_secret']}",
      "#{query}",
      "#{limit}",
      "#{since_id}"
    ]
  end

  def call
  	MicroWrapper.new(image, tag, client_address).call(command, command_args)
  end
end