module Has
  module Friends
    module Custom
    
      def self.included(base)
        base.extend Has::Friends::Custom::ClassMethods
      end
      
      module ClassMethods
        def has_friends_custom
          include Has::Friends::Custom::InstanceMethods
          
          has_many :friendships_romantic ,:include=>:relations ,:conditions => "friendships.status = 'accepted' and relation_types.name='romantic'", :class_name => 'Friendship', :foreign_key => :user_id
          has_many :friendships_business ,:include=>:relations ,:conditions => "friendships.status = 'accepted' and relation_types.name='business'", :class_name => 'Friendship', :foreign_key => :user_id
          has_many :friendships_social   ,:include=>:relations ,:conditions => "friendships.status = 'accepted' and relation_types.name='social'"  , :class_name => 'Friendship', :foreign_key => :user_id
          
          has_many :profile_viewed, :class_name => 'Viewer', :foreign_key => :viewer_id
          has_many :viewers,:conditions => "status='viewed'", :class_name => 'Viewer', :foreign_key => :user_id

          has_many :profile_suggested, :class_name => 'Suggestion', :foreign_key => :suggest_id
          has_many :suggestions,:conditions => "status='suggested'", :class_name => 'Suggestion', :foreign_key => :user_id
          
        end
      end
      
      module InstanceMethods

        def request_connection_with(other_user,relations=nil)
          self.be_friends_with(other_user, "Hi #{other_user.profile.full_name}! #{self.profile.full_name} wants to be connected with you, as a #{relations.join(',')} connection.",relations) unless  other_user.blank? || self.friends?(other_user) || ( self.friendship_for(other_user) && self.friendship_for(other_user).blocked?)
          suggesion = other_user.profile_suggested.where(:user_id=>self.id,:status=>"suggested").first
          suggesion.update_attributes(:status=>"accepted") if suggesion
        end

        def accept_connection_with(other_user,relations=nil)
          self.accept_friendship_with(other_user) unless other_user.blank? || self.friends?(other_user) || self.friendship_for(other_user).blocked?          
          friend_suggestions = self.friends.collect{ |my_friend| my_friend.friends }.flatten.uniq - ([self] + self.friends)
          friend_suggestions.each do |suggest_user|
            self.suggested_profile_of(suggest_user) unless self.friendship_for(suggest_user)
          end unless friend_suggestions.blank? 
        end

        def request_romantic_connection_with(other_user)
          if self.friendship_for(other_user).blank?
            self.request_connection_with(other_user,[:romantic])
          else
            self.accept_connection_with(other_user,[:romantic])
          end
        end

        def request_business_connection_with(other_user)     
          self.request_connection_with(other_user,[:business])
        end

        def request_social_connection_with(other_user)     
          self.request_connection_with(other_user,[:social])
        end

        def accept_romantic_connection_with(other_user)     
          self.accept_connection_with(other_user,[:romantic])
        end

        def accept_business_connection_with(other_user)     
          self.accept_connection_with(other_user,[:business])
        end

        def accept_social_connection_with(other_user)     
          self.accept_connection_with(other_user,[:social])
        end

        def removed_connection_with(other_user)     
          self.remove_friendship_with(other_user)
        end

        def blocked_connection_with(other_user)     
          self.friendship_for(other_user).blocked!
        end


        def viewed_profile_of(user_obj)
          self.profile_viewed.create(:user_id=>user_obj.id,:status=>"viewed") unless self.viewed_profile_of?(user_obj)
        end
        
        def viewed_profile_of?(user_obj)
          self.profile_viewed.where(:user_id=>user_obj.id,:status=>"viewed").any?
        end

        def get_profile_viewer(viewer_obj)
          self.viewers.where(:viewer_id=>viewer_obj.id,:status=>"viewed").first
        end


        def suggested_profile_of(user_obj)
          self.profile_suggested.create(:user_id=>user_obj.id,:status=>"suggested") unless self.suggested_profile_of?(user_obj) || user_obj.suggested_profile_of?(self)
        end
        
        def suggested_profile_of?(user_obj)
          self.profile_suggested.where(:user_id=>user_obj.id,:status=>"suggested").any?
        end

        def get_profile_suggestion(suggest_obj)
          self.suggestions.where(:suggest_id=>suggest_obj.id,:status=>"suggested").first
        end

        def requested_friends
          self.friendships_awaiting_acceptance.collect{ |my_friend| my_friend.user }
        end

        def suggested_friends
          self.suggestions.collect{ |suggest| suggest.suggest }
        end
        
        def profile_viewers
          self.viewers.collect{ |viewer| viewer.viewer }
        end

        def process_friendship(commit_type,other_user)        
          case commit_type
            when "request" then
              self.request_romantic_connection_with(other_user)
            when "accepted" then
              self.accept_romantic_connection_with(other_user)
            when "blocked" then
              self.blocked_connection_with(other_user)
            when "removed" then
              self.removed_connection_with(other_user)  
          end
        end

        def process_friendship_slider(commit_type,other_user)        
          case commit_type
            when "request" then
              self.request_romantic_connection_with(other_user)
            when "accepted" then
              self.accept_romantic_connection_with(other_user)
            when "blocked" then
              self.blocked_connection_with(other_user)
            when "removed" then
              self.removed_connection_with(other_user)  
          end
        end

        def process_viewed_slider(commit_params)
          commit_type = commit_params.keys.first
          other_user = User.where("id = ? ",commit_params.values.first).first
          if other_user
            case commit_type
              when "connect" then
                self.get_profile_viewer(other_user).connect!
              when "ignore" then
                self.get_profile_viewer(other_user).ignored!
              when "disconnect" then
                self.get_profile_viewer(other_user).disconnect!
            end                      
          end
          return collection = self.profile_viewers,"connectionrequests"
        end

        def process_requested_slider(commit_params)
          commit_type = commit_params.keys.first
          other_user = User.where("id = ? ",commit_params.values.first).first
          if other_user
            case commit_type
              when "connect" then
                self.request_romantic_connection_with(other_user)   
              when "ignore" then
                self.blocked_connection_with(other_user)
              when "disconnect" then
                self.removed_connection_with(other_user)
            end                      
          end
          return self.requested_friends,"connectionrequests"
        end

        def process_suggested_slider(commit_params)
          commit_type = commit_params.keys.first
          other_user = User.where("id = ? ",commit_params.values.first).first
          if other_user
            case commit_type
              when "connect" then
                self.request_romantic_connection_with(other_user)
                suggesion = other_user.profile_suggested.where(:user_id=> self.id,:status=>"suggested").first
                suggesion.update_attributes(:status=>"accepted") if suggesion
                other_suggesion = self.profile_suggested.where(:user_id=> other_user.id,:status=>"suggested").first
                other_suggesion.update_attributes(:status=>"accepted") if other_suggesion   
              when "ignore" then
                self.blocked_connection_with(other_user)
              when "disconnect" then
            end                      
          end
          return self.suggested_friends,"connectionsuggestions"
        end

        def process_friendship_slider(collection_param)  
          case collection_param[:collection_type]      
            when "requested" then
              collection,slider_id = self.process_requested_slider(collection_param[:commit])
            when "viewed" then
              collection,slider_id = self.process_viewed_slider(collection_param[:commit])
            when "suggested" then
              collection,slider_id = self.process_suggested_slider(collection_param[:commit])
          end
          return collection , slider_id
        end

      end
    end
  end
end
ActiveRecord::Base.send(:include, Has::Friends::Custom)
