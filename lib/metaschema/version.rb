# frozen_string_literal: true

module Metaschema
  VERSION = "0.2.2"

  class << self
    # Git revision of this checkout, for stamping generated source so a
    # downstream repo can trace which generator produced a file. Nil when the
    # gem runs from an installed copy with no git metadata.
    #
    # Shells out rather than reading .git by hand: a worktree's .git is a file,
    # refs may be packed, and HEAD may be detached. git already knows all that.
    def generator_revision
      return @generator_revision if defined?(@generator_revision)

      @generator_revision = read_git_revision
    end

    private

    def read_git_revision
      root = File.expand_path("../..", __dir__)
      return nil unless File.exist?(File.join(root, ".git"))

      revision = IO.popen(
        ["git", "rev-parse", "--short=12", "HEAD"],
        chdir: root, err: File::NULL, &:read
      ).to_s.strip

      revision.empty? ? nil : revision
    rescue StandardError
      nil
    end
  end
end
