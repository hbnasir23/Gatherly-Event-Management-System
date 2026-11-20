variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Name prefix for all resources"
  type        = string
  default     = "gatherly"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "image_tag" {
  description = "Docker image tag to run (set by the CI/CD pipeline)"
  type        = string
  default     = "latest"
}

variable "desired_count" {
  description = "Number of web tasks to run"
  type        = number
  default     = 2
}

variable "max_count" {
  description = "Maximum number of web tasks for autoscaling"
  type        = number
  default     = 4
}
