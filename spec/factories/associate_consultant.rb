FactoryGirl.define do
  factory :associate_consultant do
    notes "This is a note about something"
    coach
    user
    reviewing_group
  end
end
