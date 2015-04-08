require 'json'
require 'httparty'

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