    variable "token" {
      description = "Your Linode API Personal Access Token. (required)"
    }
    
        variable "label" {
      description = "Load Balancer Label. (required)"
      default = "default-lb"
    }
    
        variable "region" {
      description = "The region where your cluster will be located. (required)"
      default = "us-east"
    }
