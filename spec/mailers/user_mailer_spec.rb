require 'spec_helper'

describe UserMailer do

  describe 'Registration confirmation' do
    let(:user) { FactoryGirl.create(:user) }
    let(:mail) { UserMailer.registration_confirmation(user) }

    it 'renders the subject' do
      mail.subject.should == '[ReviewSite] You were registered!'
    end

    it 'renders the receiver email' do
      mail.to.should == [user.email]
    end

    it 'renders the sender email' do
      mail.from.should == ['do-not-reply@thoughtworks.org']
    end

    it 'assigns @name' do
      mail.body.encoded.should match(user.name)
    end

    it 'assigns @email' do
      mail.body.encoded.should_not match(user.email)
    end
  end

  describe 'Review creation' do
    let(:ac) {FactoryGirl.create(:associate_consultant)}
    let(:review)  {FactoryGirl.create(:new_review_type, associate_consultant: ac)}
    let(:mail) {UserMailer.review_creation(review) }

    it 'renders the subject' do
      mail.subject.should ==  "[ReviewSite] Your #{review.review_type} review has been created"
    end

    it 'renders the receiver email' do
      mail.to.should == ["#{ac.user.email}"]
    end

    it 'renders the sender email' do
      mail.from.should == ['do-not-reply@thoughtworks.org']
    end

    it 'contains link to review' do
      mail.body.encoded.should match("You can invite peers to provide feedback and work on your self-assessment by clicking on the link:\r\n#{review_url(review)}")
    end

    it 'contains the feedback deadline and review date' do
      mail.body.encoded.should match("Your review is currently scheduled for #{review.review_date}")
      mail.body.encoded.should match("the deadline to submit feedback is #{review.feedback_deadline}")
    end
  end

  describe "Password reset" do
    let(:user) { FactoryGirl.create(:user, password_reset_token: 'test_token') }
    let(:mail) { UserMailer.password_reset(user) }
    subject { mail }

    its(:subject) { should == "[ReviewSite] Recover your account" }
    its(:to) { should == [user.email] }
    its(:from) { should == ['do-not-reply@thoughtworks.org'] }

    it "provides reset url" do
      mail.body.encoded.should =~ /test_token\/edit/
    end
  end

  describe "Feedback submitted notification" do
    let (:user) { FactoryGirl.create(:user) }
    let (:ac) { FactoryGirl.create(:associate_consultant) }
    let (:review) { FactoryGirl.create(:review, associate_consultant: ac) }
    let (:feedback) { FactoryGirl.create(:submitted_feedback, user: user, review: review) }
    let (:mail) { UserMailer.new_feedback_notification(feedback) }

    it 'renders the subject' do
      mail.subject.should == "[ReviewSite] You have new feedback from #{feedback.user}"
    end

    it 'renders the receiver email' do
      mail.to.should == [ac.user.email]
    end

    it 'renders the sender email' do
      mail.from.should == ['do-not-reply@thoughtworks.org']
    end

    it 'addresses the receiver' do
      mail.body.encoded.should match("Hi " + ac.user.name)
    end

    it 'contains the name of the reviewer' do
      mail.body.encoded.should match(user.name)
    end

    it 'includes feedback path' do
      mail.body.encoded.should match(review_feedback_url(review, feedback))
    end
  end

  describe "Feedback invitation" do
    let (:ac) { FactoryGirl.create(:associate_consultant) }
    let (:review) { FactoryGirl.create(:review, associate_consultant: ac, feedback_deadline: Date.today) }
    let (:email) { "recipient@example.com" }
    let (:message) { "Hello. Please leave feedback." }
    let (:mail) { UserMailer.review_invitation(review, email, message) }

    it 'renders the subject' do
      mail.subject.should == "[ReviewSite] You've been invited to give feedback for #{ac.user.name}"
    end

    it 'renders the receiver email' do
      mail.to.should == ["recipient@example.com"]
    end

    it 'renders the sender email' do
      mail.from.should == ['do-not-reply@thoughtworks.org']
    end

    it 'contains params[:message]' do
      mail.body.encoded.should match("Hello. Please leave feedback.")
    end
  end


  describe "Feedback reminder" do
    let (:ac) { FactoryGirl.create(:associate_consultant) }
    let (:review) { FactoryGirl.create(:review, associate_consultant: ac, feedback_deadline: Date.new(2020, 1, 1)) }
    let (:email) { "recipient@example.com" }
    let (:invitation) { review.invitations.create(email: email) }

    describe "feedback not started, deadline not passed" do
      let (:mail) { UserMailer.feedback_reminder(invitation) }
      subject { mail }

      its (:subject) { should == "[ReviewSite] Please leave feedback for #{ac.user.name}" }
      its (:to) { should == ["recipient@example.com"] }

      it "contains reminder message" do
        CGI.unescapeHTML(mail.body.encoded).should match(
           "This is a reminder to submit your feedback for #{review}."
        )
      end

      it "contains deadline message" do
        mail.body.encoded.should match(
          "The deadline for leaving feedback is 2020-01-01."
        )
      end

      it "does not say the deadline has passed" do
        mail.body.encoded.should_not match(
          "Even though the feedback deadline has passed, we would love to hear your thoughts."
        )
      end

      it "contains a new feedback link" do
        mail.body.encoded.should match(
          "To get started, please visit #{new_review_feedback_url(review)}."
        )
      end

      it "does not contain edit feedback message" do
        mail.body.encoded.should_not match (
          "You have saved feedback, but it has not yet been submitted. To continue working, please visit"
        )
      end
    end

    describe "feedback started, deadline not passed" do
      let (:reviewer) { FactoryGirl.create(:user, email: "recipient@example.com") }
      let!(:feedback) { FactoryGirl.create(:feedback, review: review, user: reviewer) }
      let (:mail) { UserMailer.feedback_reminder(invitation) }
      subject { mail }

      its (:subject) { should == "[ReviewSite] Please leave feedback for #{ac.user.name}" }
      its (:to) { should == ["recipient@example.com"] }

      it "contains reminder message" do
        CGI.unescapeHTML(mail.body.encoded).should match(
          "This is a reminder to submit your feedback for #{review}."
        )
      end

      it "contains deadline message" do
        mail.body.encoded.should match(
          "The deadline for leaving feedback is 2020-01-01."
        )
      end

      it "does not say the deadline has passed" do
        mail.body.encoded.should_not match(
          "Even though the feedback deadline has passed, we would love to hear your thoughts."
        )
      end

      it "contains an edit feedback link" do
        mail.body.encoded.should match(
          "You have saved feedback, but it has not yet been submitted. To continue working, please visit #{edit_review_feedback_url(review, feedback)}."
        )
      end

      it "does not contain a new feedback link" do
        mail.body.encoded.should_not match(
          "To get started, please visit #{new_review_feedback_url(review)}."
        )
      end
    end

    describe "feedback not started, deadline not passed" do
      let (:mail) { UserMailer.feedback_reminder(invitation) }
      subject { mail }
      before { review.update_attribute(:feedback_deadline, Date.new(2000, 1, 1)) }

      its (:subject) { should == "[ReviewSite] Please leave feedback for #{ac.user.name}" }
      its (:to) { should == ["recipient@example.com"] }

      it "contains reminder message" do
        CGI.unescapeHTML(mail.body.encoded).should match(
          "This is a reminder to submit your feedback for #{review}."
        )
      end

      it "says the deadline has passed" do
        mail.body.encoded.should match(
          "Even though the feedback deadline has passed, we would love to hear your thoughts."
        )
      end

      it "does not contain deadline message" do
        mail.body.encoded.should_not match(
          "The deadline for leaving feedback is 2020-01-01."
        )
      end

      it "contains a new feedback link" do
        mail.body.encoded.should match(
          "To get started, please visit #{new_review_feedback_url(review)}."
        )
      end

      it "does not contain edit feedback message" do
        mail.body.encoded.should_not match (
          "You have saved feedback, but it has not yet been submitted. To continue working, please visit"
        )
      end
    end

    describe "feedback started, deadline passed" do
      let (:reviewer) { FactoryGirl.create(:user, email: "recipient@example.com") }
      let!(:feedback) { FactoryGirl.create(:feedback, review: review, user: reviewer) }
      let (:mail) { UserMailer.feedback_reminder(invitation) }
      subject { mail }

      before { review.update_attribute(:feedback_deadline, Date.new(2000, 1, 1)) }

      its (:subject) { should == "[ReviewSite] Please leave feedback for #{ac.user.name}" }
      its (:to) { should == ["recipient@example.com"] }

      it "contains reminder message" do
        CGI.unescapeHTML(mail.body.encoded).should match(
          "This is a reminder to submit your feedback for #{review}."
        )
      end

      it "says the deadline has passed" do
        mail.body.encoded.should match(
          "Even though the feedback deadline has passed, we would love to hear your thoughts."
        )
      end

      it "does not contain deadline message" do
        mail.body.encoded.should_not match(
          "The deadline for leaving feedback is 2000-01-01."
        )
      end

      it "contains an edit feedback link" do
        mail.body.encoded.should match(
          "You have saved feedback, but it has not yet been submitted. To continue working, please visit #{edit_review_feedback_url(review, feedback)}."
        )
      end

      it "does not contain a new feedback link" do
        mail.body.encoded.should_not match(
          "To get started, please visit #{new_review_feedback_url(review)}."
        )
      end
    end
  end
end
