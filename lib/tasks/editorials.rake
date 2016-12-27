namespace :editorials do
  desc "Send weekly emails to editors"
  task :send_weekly_emails => :environment do
    review_issues = ReviewIssue.download_review_issues(ENV['REVIEW_REPO'])
    # Sort issues in place in order of date created

    # binding.pry
    pending_issues = review_issues.select { |i| i.editor == "Pending" }

    # Loop through editors and send them their weekly email :-)
    YAML.load(ENV['EDITORS']).each do |editor|
      editor_issues = ReviewIssue.review_issues_for_editor(review_issues, editor)
      Notifications.editor_weekly_email(editor, pending_issues, editor_issues).deliver_now!
    end
  end
end
