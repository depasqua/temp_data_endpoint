class VolunteerSubmission < ApplicationRecord
  validate :data_must_be_a_nonempty_object

  private

  def data_must_be_a_nonempty_object
    errors.add(:data, "must be a non-empty object") unless data.is_a?(Hash) && data.any?
  end
end
