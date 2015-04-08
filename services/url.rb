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