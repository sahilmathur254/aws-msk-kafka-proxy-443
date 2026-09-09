mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
        }]
      })
    }
  }
}
# Global dummy values to satisfy required module inputs across all guardrail tests
variables {
  vpc_id                           = "vpc-1234567890"
  public_subnet_ids                = ["subnet-pub1", "subnet-pub2"]
  private_subnet_ids               = ["subnet-priv1", "subnet-priv2"]
  msk_security_group_id            = "sg-1234567890"
  msk_bootstrap_brokers_sasl_scram = "b-1.mock.kafka.amazonaws.com:9096"
  kafka_domain                     = "mock.kafka.local"
  tls_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:mock-secret"
  client_cidrs                     = ["10.0.0.0/16"]
  route53_zone_id                  = "Z1234567890MOCK"
}

# Requirement 1: Reject unrestricted 0.0.0.0/0 client access by default
run "reject_unrestricted_client_cidrs_by_default" {
  command = plan

  variables {
    client_cidrs                    = ["0.0.0.0/0"]
    allow_unrestricted_client_cidrs = false
  }

  expect_failures = [
    aws_lb.kafka,
  ]
}


# Requirement 2: Verify explicit mutable-tag escape hatch
run "allow_mutable_image_tag_escape_hatch" {
  command = plan

  variables {
    kroxylicious_image      = "kroxylicious/proxy:latest"
    allow_mutable_image_tag = true
  }

  assert {
    condition     = var.kroxylicious_image == "kroxylicious/proxy:latest"
    error_message = "Mutable image tags should be permitted when allow_mutable_image_tag is true."
  }
}
run "reject_invalid_name_input" {
  command = plan

  variables {
    # Fails because it starts with a number and has uppercase letters
    name = "1-INVALID-NAME"
  }

  # Test passes if Terraform blocks the plan due to the var.name validation
  expect_failures = [
    var.name
  ]
}
# Requirement 3: Verify kafka domain
run "reject_invalid_kafka_domain" {
  command = plan

  variables {
    # Fails because it doesn't have a dot (not a fully qualified domain)
    kafka_domain = "invalid-domain-no-dots"
  }

  # Test passes if Terraform blocks the plan due to the var.kafka_domain validation
  expect_failures = [
    var.kafka_domain
  ]
}

run "reject_empty_domain_input" {
  command = plan

  variables {
    # Fails because it is empty (the regex requires characters)
    kafka_domain = ""
  }

  expect_failures = [
    var.kafka_domain
  ]
}