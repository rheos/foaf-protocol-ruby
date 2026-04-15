class Identity < ApplicationRecord
  validates :address, presence: true, uniqueness: true
  validates :public_key, presence: true
end
