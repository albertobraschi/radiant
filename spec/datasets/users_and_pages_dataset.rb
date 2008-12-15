class UsersAndPagesDataset < Dataset::Base
  uses :pages, :users
  
  def load
    UserActionObserver.current_user = users(:admin)
    Page.update_all "created_by_id = #{user_id(:admin)}, updated_by_id = #{user_id(:admin)}"
    create_page "No User"
    
    create_page "Mother of dwarves" do
      create_page "Bashful", :published_at => DateTime.parse('2005-10-07 12:12:12'), :created_by_id => user_id(:pages_tester)
      create_page "Doc",     :published_at => DateTime.parse('2004-09-08 12:12:12'), :created_by_id => user_id(:pages_tester)
      create_page "Dopey",   :published_at => DateTime.parse('2003-08-09 12:12:12'), :created_by_id => user_id(:pages_tester)
      create_page "Grumpy",  :published_at => DateTime.parse('2002-07-10 12:12:12'), :created_by_id => user_id(:pages_tester)
      create_page "Happy",   :published_at => DateTime.parse('2001-06-11 12:12:12'), :created_by_id => user_id(:pages_tester)
      create_page "Sleepy",  :status_id => Status[:draft].id,                        :created_by_id => user_id(:pages_tester)
      create_page "Sneezy",  :published_at => DateTime.parse('2000-05-12 12:12:12'), :created_by_id => user_id(:pages_tester)
    end
  end
end