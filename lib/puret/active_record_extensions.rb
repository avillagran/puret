module Puret
  module ActiveRecordExtensions
    module ClassMethods

      # Configure translation model dependency.
      # Eg:
      #   class PostTranslation < ActiveRecord::Base
      #     puret_for :post
      #   end
      def puret_for(model)
        belongs_to model
        validates_presence_of model, :locale
        validates_uniqueness_of :locale, :scope => "#{model}_id"
      end

      # Configure translated attributes.
      # Eg:
      #   class Post < ActiveRecord::Base
      #     puret :title, :description
      #   end
      def puret(*attributes)
        make_it_puret! unless included_modules.include?(InstanceMethods)

        attributes.each do |attribute|
          # attribute setter

          define_method "#{attribute}=" do |value|
            self[attribute] = value
            puret_attributes[I18n.locale][attribute] = value
          end


          # attribute getter
          define_method attribute do
            return self[attribute]  if self.new_record?
            get_value attribute
          end

        end
      end

      private

      # configure model
      def make_it_puret!
        include InstanceMethods

        has_many :translations, :class_name => "#{self.to_s}Translation", :dependent => :destroy, :order => "created_at DESC"
        after_save :update_translations!
        #before_save :update_real_data!
      end
    end

    module InstanceMethods
=begin
      def puret_default_locale
        return default_locale.to_sym if respond_to?(:default_locale)
        return self.class.default_locale.to_sym if self.class.respond_to?(:default_locale)
        I18n.default_locale
      end
=end
      # attributes are stored in @puret_attributes instance variable via setter
      def puret_attributes
        @puret_attributes ||= Hash.new { |hash, key| hash[key] = {} }
      end

      def get_value attribute

        # return previously setted attributes if present
        #return puret_attributes[I18n.locale][attribute] if !puret_attributes[I18n.locale][attribute].blank?
        return if new_record?

        # Lookup chain:
        # if translation not present in current locale,
        # use default locale, if present.
        # Otherwise use first translation

        t_locale = translations.detect { |t| t.locale.to_sym == I18n.locale && t[attribute] }
        t_default= translations.detect { |t| t.locale.to_sym == I18n.default_locale && t[attribute] }
        t_not_blank= translations.detect { |t| !t[attribute].blank? }

        if t_locale.nil? && t_default.nil?
          return self[attribute]
        end

        if t_locale.nil? || t_locale[attribute].blank?
          if !t_default.nil? && !t_default[attribute].blank?
            return t_default[attribute]
          else
            if self[attribute].blank? && !t_not_blank.nil?
              return t_not_blank[attribute]
            else
              return self[attribute]
            end
          end
        else
          return t_locale[attribute]
        end
      end

      def update_real_data!
        return if puret_attributes.blank?

        tmp = puret_attributes[I18n.default_locale]
        tmp.delete(:locale)
        self.update_attributes(tmp)
        self.save!
      end
      # called after save
      def update_translations!
        return if puret_attributes.blank?

        puret_attributes.each do |locale, attributes|
          translation = translations.find_or_initialize_by_locale(locale.to_s)
          translation.attributes = translation.attributes.merge(attributes)
          translation.save!
        end
      end

    end
  end
end

ActiveRecord::Base.extend Puret::ActiveRecordExtensions::ClassMethods
