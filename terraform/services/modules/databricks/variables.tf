variable "name_suffix"          { type = string }
variable "resource_group_name"  { type = string }
variable "location"             { type = string }
variable "storage_account_id"   { type = string }
variable "sku"                  {
                                    type = string
                                    default = "premium"
                                    }
variable "tags"                 {
                                    type = map(string)
                                    default = {}
                                    }