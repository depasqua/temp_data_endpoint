require "fileutils"
require "pstore"
require "securerandom"
require "time"

class VolunteerSubmission
  def initialize(path)
    FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
    File.open(path, File::WRONLY | File::CREAT, 0o600) {}
    @store = PStore.new(path, true)
  end

  def create(data)
    id = SecureRandom.uuid
    @store.transaction do
      @store[id] = { "data" => data, "created_at" => Time.now.utc.iso8601 }
    end
    id
  end
end
