# frozen_string_literal: true

class LocalnetsController < ApplicationController
  before_action :set_localnet

  def show
    @status = @localnet.status
  end

  def start
    result = @localnet.start!
    redirect_to root_path, flash: flash_for(result)
  end

  def stop
    result = @localnet.stop!
    redirect_to root_path, flash: flash_for(result)
  end

  def reset
    result = @localnet.reset!
    redirect_to root_path, flash: flash_for(result)
  end

  private

  def set_localnet
    @localnet = Localnet.new
  end

  def flash_for(result)
    key = result.ok? ? :notice : :alert
    { key => result.message }
  end
end
