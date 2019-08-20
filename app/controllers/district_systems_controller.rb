class DistrictSystemsController < ApplicationController
  @district_system_config ={}

  def index
    puts 'GET request...'
    # TODO:Get simulation results from session
    @simulation_results =  {}
    puts @simulation_results
  end

  def new

  end

  def create

  end

  def simulate
    puts 'POST request'
    @simulation_results = {
        a: '123',
        b: '345',
    }
    @simulation_results = params[:district_system]
      # render plain: params[:district_system].inspect
  end

end
