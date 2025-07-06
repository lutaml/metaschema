# frozen_string_literal: true

require 'pathname'

module PathHelper
  def self.included(base)
    base.extend self
  end

  private

  def root_dir
    Pathname(__dir__).join('../..')
  end
end
