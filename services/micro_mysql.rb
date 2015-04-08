require 'yaml'

class MicroMysql < MicroWrapper
  def initialize(query)
  	@client_address = "http://localhost:49999"

  	yml = YAML.load_file("./services/mysql_secret.yml")
    @image = "izackp/go-mysql-microservice"
    @tag = "0.2"
    @command = "/Go-MySQL-Microservice"
    uri = yml["uri"]
    pw = yml["password"]
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