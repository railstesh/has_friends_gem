
FriendshipMessage.class_eval do
  # Setup accessible (or protected) attributes
  attr_accessible :body
  
end

Friendship.class_eval do
  # Setup accessible (or protected) attributes
  attr_accessible :friend_id, :status, :message , :requested_at 
  
  # constants
  STATUS_BLOCKED = 7
  FRIENDSHIP_BLOCKED = "blocked"

  # scopes
  scope :blocked, :conditions => {:status => FRIENDSHIP_BLOCKED}
  
  
  def blocked?
    self.status == FRIENDSHIP_BLOCKED
  end

  def blocked!
    unless blocked?
      self.transaction do
        self.update_attribute(:status, FRIENDSHIP_BLOCKED)
      end
    end
  end
end
